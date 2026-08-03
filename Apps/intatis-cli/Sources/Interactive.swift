import Foundation
import IntatisCore
import IntatisProtocol
import IntatisProviders
import IntatisConversation
import IntatisPermission
import IntatisAgentKernel
import IntatisCowork

enum REPLExit {
    case quit
    case switchTo(Mode)
}

private enum S {
    static let reset = "\u{001B}[0m"
    static let bold = "\u{001B}[1m"
    static let dim = "\u{001B}[2m"
    static let green = "\u{001B}[32m"
    static let yellow = "\u{001B}[33m"
    static let cyan = "\u{001B}[36m"
}

private func banner(mode: Mode, preset: TeamPreset, host: String) {
    out("\n\(S.bold)Councis\(S.reset) \(S.dim)·\(S.reset) \(S.cyan)\(mode.rawValue)\(S.reset) \(S.dim)· \(preset.name) · \(host)\(S.reset)\n")
    out("\(S.dim)@main \(preset.main.identity) · @judge \(preset.judge.identity)\(S.reset)\n")
    out("\(S.dim)/help for commands · /mode to switch · /exit to quit\(S.reset)\n")
}

private func prompt(_ mode: Mode) -> String {
    "\n\(S.green)\(mode.rawValue) ❯\(S.reset) "
}

private func nextMode(_ mode: Mode) -> Mode {
    mode == .chat ? .work : .chat
}

private func sessionLog(mode: Mode) throws -> EventLog {
    let support = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true)
    let directory = support
        .appendingPathComponent("Councis", isDirectory: true)
        .appendingPathComponent("cli", isDirectory: true)
        .appendingPathComponent("sessions", isDirectory: true)
        .appendingPathComponent("\(mode.rawValue)_\(UUID().uuidString)", isDirectory: true)
    return try EventLog(
        session: SessionID.new(),
        fileURL: directory.appendingPathComponent("events.jsonl"))
}

/// Chat intentionally receives a real but empty confined workspace. It still
/// runs the exact Cowork scheduler/message bus/Judge path, while file tools can
/// never reach the directory from which Councis was launched.
private func chatWorkspace() throws -> URL {
    let support = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true)
    let workspace = support
        .appendingPathComponent("Councis", isDirectory: true)
        .appendingPathComponent("cli", isDirectory: true)
        .appendingPathComponent("chat-workspace", isDirectory: true)
    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    return workspace.standardizedFileURL
}

/// Both product modes use the Cowork runtime. Switching mode tears down the
/// current runtime cleanly and creates another with the matching preset and
/// workspace envelope.
func runMode(_ config: CLIConfig,
             mode startMode: Mode,
             workspace: URL,
             preset initialPreset: TeamPreset,
             oneShotPrompt: String? = nil) async throws {
    var mode = startMode
    var preset = initialPreset
    while true {
        let effectiveWorkspace = mode == .chat ? try chatWorkspace() : workspace
        let result = try await teamREPL(
            config,
            mode: mode,
            workspace: effectiveWorkspace,
            preset: preset,
            oneShotPrompt: oneShotPrompt)
        switch result {
        case .quit:
            return
        case .switchTo(let next):
            mode = next
            preset = try loadTeamPreset(
                named: next.defaultPresetName,
                mode: next,
                config: config)
        }
    }
}

private let teamHelp = """
  Just talk to @main. Councis runs every root task through the reserved @judge.
  /team                              show the preset and unused worker models
  /agents                            list attached agents and bindings
  /agent add <name> [path] [binding] attach a worker; binding defaults to the
                                     next unused provider/model in the pool
  /agent remove <name>               detach a worker
  /verbose [on|off]                  expand tool calls and terminal output
  /attach <path>                     queue an image/text file for the next task
  @name <message>                    send to an attached worker (not @judge)
  <message>                          submit a reviewed root task to @main
  /mode <chat|work>                  switch product mode
  /clear                             start a new event-log session
  /help   /exit

  Keys: ←/→ cursor · Home/End jump · ↑/↓ history · Ctrl-U/K/W edit
        Ctrl-A mode · Ctrl-L team · Ctrl-S settings · Ctrl-C quit

"""

private func teamREPL(_ config: CLIConfig,
                      mode: Mode,
                      workspace: URL,
                      preset: TeamPreset,
                      oneShotPrompt: String?) async throws -> REPLExit {
    let mainBinding = try preset.resolvedBinding(for: preset.main, config: config)
    let judgeBinding = try preset.resolvedBinding(for: preset.judge, config: config)
    let providerConfig = try config.providerConfig(
        defaultProviderID: mainBinding.providerID,
        model: mainBinding.modelID.rawValue)
    let registry = ProviderRegistry(config: providerConfig, resolver: config.secretResolver())
    var pending = PendingAttachments()
    var log = try sessionLog(mode: mode)
    let spinner = TurnSpinner()
    let editor = LineEditor()
    let options = RenderOptions()
    let renderProgress = oneShotPrompt == nil ? nil : EventRenderProgress()
    var render = Task {
        await renderLoop(
            log,
            showAgentLabels: true,
            spinner: spinner,
            options: options,
            progress: renderProgress,
            mandatoryTaskReview: true)
    }
    defer { render.cancel(); spinner.stop() }

    var orchestrator = try makeOrchestrator(
        config: config,
        mode: mode,
        log: log,
        registry: registry,
        preset: preset)

    func attachFixedAgents() async -> Bool {
        let mainAttached = await orchestrator.attach(Agent(
            name: Orchestrator.mainAgentID,
            workspaceRoot: workspace,
            modelBinding: mainBinding,
            profile: .reviewed,
            coordinationDepth: Agent.defaultCoordinationDepth))
        guard mainAttached else { return false }
        return await orchestrator.attachTaskReviewer(Agent(
            name: Orchestrator.taskReviewerID,
            workspaceRoot: workspace,
            modelBinding: judgeBinding,
            profile: .readOnly,
            coordinationDepth: 0))
    }

    guard await attachFixedAgents(),
          await orchestrator.taskReviewerHealth() == .healthy else {
        await orchestrator.cancelAll(reason: "Councis fixed team admission failed")
        throw IntatisError.config(
            "could not establish a healthy fixed @main/@judge team")
    }
    await orchestrator.resumePendingTasks()

    let mainProviderID = mainBinding.providerID
    let host = config.baseURL(for: mainProviderID)?.host ?? mainProviderID
    banner(mode: mode, preset: preset, host: host)
    out("\(S.dim)workspace: \(mode == .chat ? "confined chat session" : workspace.path)\(S.reset)\n")
    out("\(S.dim)worker pool: \(preset.workerPoolSummary.isEmpty ? "(empty)" : preset.workerPoolSummary)\(S.reset)\n")
    out("\(S.dim)permissions remain user-reviewed; @judge is separate from permission review.\(S.reset)\n")

    func finish(_ result: REPLExit) async -> REPLExit {
        await orchestrator.cancelAll(reason: "Councis session ended")
        return result
    }

    if let oneShotPrompt {
        let result: OrchestratorRootResult
        do {
            spinner.start()
            result = try await submitRootTask(
                oneShotPrompt,
                to: Orchestrator.mainAgentID,
                orchestrator: orchestrator)
            spinner.stop()
        } catch {
            spinner.stop()
            _ = await finish(.quit)
            throw error
        }

        // `submit` returns only after the root task and mandatory Judge stage
        // are terminal. Wait until stdout has consumed every event persisted up
        // to that point before cancelling the stream and exiting. The answer is
        // emitted only by the event renderer; `result.result` is deliberately
        // not printed a second time.
        if let terminalSequence = await log.replay().last?.seq {
            await renderProgress?.wait(until: terminalSequence)
        }
        if result.error == nil, let verdict = result.reviewVerdict {
            out("\(S.dim)@judge \(verdict.decision.rawValue): \(verdict.summary)\(S.reset)\n")
        }
        _ = await finish(.quit)

        if let error = result.error {
            throw CouncisCLIError.execution(error)
        }
        guard result.taskID != nil, result.status == .completed else {
            throw CouncisCLIError.execution(
                "one-shot root task did not produce a durable completed TaskContract")
        }
        return .quit
    }

    while true {
        if !pending.isEmpty {
            out("\(S.dim)  \(pending.count) attachment(s) queued for your next task\(S.reset)\n")
        }
        let line: String
        switch editor.readLine(prompt: prompt(mode)) {
        case .eof:
            return await finish(.quit)
        case .shortcut(.exit):
            return await finish(.quit)
        case .shortcut(.cycleMode):
            return await finish(.switchTo(nextMode(mode)))
        case .shortcut(.switchModel):
            printTeam(
                preset,
                agents: await orchestrator.agentList(),
                judgeHealth: await orchestrator.taskReviewerHealth())
            continue
        case .shortcut(.settings):
            try runSettings()
            out("(settings saved — restart to apply provider changes)\n")
            continue
        case .text(let value):
            line = value
        }

        let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { continue }
        if text.hasPrefix("/") {
            let parts = text.dropFirst().split(separator: " ").map(String.init)
            let command = parts.first ?? ""
            switch command {
            case "help":
                out(teamHelp)
            case "exit", "quit":
                return await finish(.quit)
            case "mode":
                guard parts.count > 1, let next = Mode.parse(parts[1]) else {
                    out("usage: /mode chat|work\n")
                    continue
                }
                if next == mode { out("already in \(mode.rawValue)\n") }
                else { return await finish(.switchTo(next)) }
            case "team":
                printTeam(
                    preset,
                    agents: await orchestrator.agentList(),
                    judgeHealth: await orchestrator.taskReviewerHealth())
            case "agents":
                printAgents(await orchestrator.agentList())
            case "verbose":
                if parts.count > 1, parts[1].lowercased() == "off" { options.verbose = false }
                else if parts.count > 1, parts[1].lowercased() == "on" { options.verbose = true }
                else { options.verbose.toggle() }
                out("verbose → \(options.verbose ? "on" : "off")\n")
            case "attach":
                handleAttachment(parts: parts, pending: &pending)
            case "agent":
                await handleAgentCommand(
                    parts: parts,
                    mode: mode,
                    defaultWorkspace: workspace,
                    preset: preset,
                    config: config,
                    orchestrator: orchestrator)
            case "clear":
                await orchestrator.cancelAll(reason: "Councis session cleared")
                render.cancel()
                log = try sessionLog(mode: mode)
                orchestrator = try makeOrchestrator(
                    config: config,
                    mode: mode,
                    log: log,
                    registry: registry,
                    preset: preset)
                guard await attachFixedAgents(),
                      await orchestrator.taskReviewerHealth() == .healthy else {
                    throw IntatisError.config(
                        "could not establish a healthy fixed @main/@judge team after /clear")
                }
                render = Task {
                    await renderLoop(
                        log,
                        showAgentLabels: true,
                        spinner: spinner,
                        options: options,
                        mandatoryTaskReview: true)
                }
                out("(new reviewed team session)\n")
            default:
                out("unknown command /\(command) — /help\n")
            }
            continue
        }

        var target: AgentID? = Orchestrator.mainAgentID
        var message = text
        if text.hasPrefix("@") {
            let components = String(text.dropFirst()).split(separator: " ", maxSplits: 1).map(String.init)
            target = AgentID(rawValue: components.first ?? "")
            message = components.count > 1 ? components[1] : ""
            if target == Orchestrator.taskReviewerID {
                out("@judge is reserved for the automatic task review stage; send the task to @main.\n")
                continue
            }
        }
        let images = pending.images
        let textFiles = pending.textFiles
        let result: OrchestratorRootResult
        do {
            spinner.start()
            result = try await submitRootTask(
                message,
                to: target,
                images: images,
                textFiles: textFiles,
                orchestrator: orchestrator)
            spinner.stop()
            pending.clear()
        } catch {
            spinner.stop()
            errOut("\(error.localizedDescription)\n")
            continue
        }
        if let error = result.error {
            errOut("error: \(error)\n")
        } else if let verdict = result.reviewVerdict {
            out("\(S.dim)@judge \(verdict.decision.rawValue): \(verdict.summary)\(S.reset)\n")
        }
    }
}

/// The shared REPL/one-shot admission path. `Orchestrator.submit` creates the
/// durable root TaskContract before scheduler execution; CLI runtimes always
/// install `.always` task review, so every successful return has crossed the
/// reserved @judge stage. Text attachments are appended after `/goal` parsing
/// to keep attachment bodies out of goal metadata.
func submitRootTask(
    _ rawInput: String,
    to target: AgentID?,
    images: [ImageAttachment] = [],
    textFiles: [(name: String, content: String)] = [],
    orchestrator: Orchestrator
) async throws -> OrchestratorRootResult {
    let parsedInput: ParsedUserInput
    switch GoalInputParser.parse(rawInput) {
    case .success(let parsed):
        parsedInput = parsed
    case .failure(let error):
        throw CouncisCLIError.argument(error.message)
    }

    var message = parsedInput.text
    for file in textFiles {
        message += "\n\n[attached file: \(file.name)]\n\(file.content)"
    }
    return await orchestrator.submit(
        message,
        to: target,
        images: images,
        userMessage: UserMessagePayload(
            text: message,
            to: target,
            tags: parsedInput.tags.isEmpty ? nil : parsedInput.tags,
            goal: parsedInput.goal))
}

private func makeOrchestrator(config: CLIConfig,
                              mode: Mode,
                              log: EventLog,
                              registry: ProviderRegistry,
                              preset: TeamPreset) throws -> Orchestrator {
    try Orchestrator.runtime(
        log: log,
        allowsShell: mode == .work,
        responder: TerminalResponder(),
        reasoningEffort: config.reasoningEffort,
        includeUsage: config.includeUsage,
        maxSteps: config.maxSteps,
        taskReviewPolicy: .always,
        modelAssignmentPolicy: try preset.runtimeModelAssignmentPolicy(config: config),
        surfaceProfile: mode == .chat ? .chat : .work,
        legacyProviderID: config.defaultProviderID,
        imageGeneratorFor: { _ in ProviderImageGenerationToolService(registry: registry) },
        providerFor: { agent in
            try await registry.agentProvider(for: agent.modelBinding)
        })
}

private func printTeam(_ preset: TeamPreset,
                       agents: [Agent],
                       judgeHealth: TaskReviewerLifecycleHealth) {
    let occupied = Set(agents.map(\.modelBinding))
    out("preset \(preset.name) · assignment \(preset.modelAssignment.strategy.rawValue)\n")
    out("  @main   \(preset.main.identity)\n")
    out("  @judge  \(preset.judge.identity) · \(taskReviewerHealthLabel(judgeHealth))\n")
    for worker in preset.workerModelPool {
        let state = occupied.contains(AgentModelBinding(
            providerID: worker.providerID,
            modelID: ModelID(rawValue: worker.model))) ? "in use" : "available"
        out("  pool    \(worker.identity) · \(state)\n")
    }
}

private func taskReviewerHealthLabel(_ health: TaskReviewerLifecycleHealth) -> String {
    switch health {
    case .disabled:
        return "disabled"
    case .healthy:
        return "healthy"
    case .degraded(let reason):
        return "degraded · \(reason)"
    case .quarantined(let reason):
        return "quarantined · \(reason)"
    case .shuttingDown:
        return "shutting down"
    }
}

private func printAgents(_ agents: [Agent]) {
    if agents.isEmpty {
        out("(no agents attached)\n")
        return
    }
    for agent in agents.sorted(by: { $0.name.rawValue < $1.name.rawValue }) {
        out("  @\(agent.name.rawValue)  \(S.dim)\(agent.modelBinding.providerID)/\(agent.model.rawValue) · \(agent.workspaceRoot.path)\(S.reset)\n")
    }
}

private func handleAttachment(parts: [String], pending: inout PendingAttachments) {
    if parts.count < 2 || parts[1] == "list" {
        out(pending.isEmpty ? "no attachments queued. usage: /attach <path>\n" : "\(pending.count) queued\n")
    } else if parts[1] == "clear" {
        pending.clear()
        out("attachments cleared\n")
    } else {
        switch AttachmentLoader.load(parts[1]) {
        case .image(let image):
            pending.images.append(image)
            out("attached image · \(pending.count) queued\n")
        case .text(let name, let content):
            pending.textFiles.append((name, content))
            out("attached \(name) · \(pending.count) queued\n")
        case .failure(let message):
            errOut(message + "\n")
        }
    }
}

private func handleAgentCommand(parts: [String],
                                mode: Mode,
                                defaultWorkspace: URL,
                                preset: TeamPreset,
                                config: CLIConfig,
                                orchestrator: Orchestrator) async {
    guard parts.count >= 3 else {
        out("usage: /agent add <name> [path] [provider/model] | /agent remove <name>\n")
        return
    }
    if parts[1] == "remove" {
        let removed = await orchestrator.detach(AgentID(rawValue: parts[2]))
        out(removed ? "removed @\(parts[2])\n" : "not removed @\(parts[2]) (reserved, missing, or busy)\n")
        return
    }
    guard parts[1] == "add" else {
        out("usage: /agent add <name> [path] [provider/model] | /agent remove <name>\n")
        return
    }

    let name = parts[2]
    let pathToken = parts.count >= 4 ? parts[3] : defaultWorkspace.path
    let bindingToken = parts.count >= 5 ? parts[4] : nil
    let workspace: URL
    if mode == .chat {
        workspace = defaultWorkspace
    } else {
        workspace = URL(fileURLWithPath: (pathToken as NSString).expandingTildeInPath).standardizedFileURL
    }
    do {
        let occupied = Set(await orchestrator.agentList().map(\.modelBinding))
        let binding = try preset.workerBinding(for: bindingToken, occupied: occupied, config: config)
        let attached = await orchestrator.attach(Agent(
            name: AgentID(rawValue: name),
            workspaceRoot: workspace,
            modelBinding: binding,
            profile: .reviewed,
            coordinationDepth: 0))
        out(attached
            ? "attached @\(name) · \(binding.providerID)/\(binding.modelID.rawValue) · \(workspace.path)\n"
            : "not attached @\(name) · \(workspace.path)\n")
    } catch {
        errOut("error: \(error.localizedDescription)\n")
    }
}
