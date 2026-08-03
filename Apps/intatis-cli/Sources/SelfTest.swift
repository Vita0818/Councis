import Foundation
import IntatisCore
import IntatisProtocol
import IntatisProviders
import IntatisConversation
import IntatisTools
import IntatisPermission
import IntatisAgentKernel
import IntatisCowork

// Built-in fake models — let `councis selftest` prove the shared kernel paths work
// offline, with no API key and no network. They drive the exact same ChatLoop /
// AgentLoop / renderer / approval code the real commands use.

private struct FakeChat: ChatProvider {
    let parts: [String]
    func stream(_ request: ChatRequest) -> AsyncThrowingStream<ChatChunk, Error> {
        AsyncThrowingStream { c in
            for p in parts { c.yield(.delta(p)) }
            c.yield(.done); c.finish()
        }
    }
}

private final class FakeAgent: ToolCallingProvider, @unchecked Sendable {
    private var turns: [[AgentChunk]]
    private var i = 0
    private let lock = NSLock()
    init(_ turns: [[AgentChunk]]) { self.turns = turns }
    func stream(_ request: AgentRequest) -> AsyncThrowingStream<AgentChunk, Error> {
        lock.lock()
        let turn = turns.isEmpty ? [.done(finishReason: "stop")] : turns[min(i, turns.count - 1)]
        i += 1
        lock.unlock()
        return AsyncThrowingStream { c in
            for x in turn { c.yield(x) }
            c.finish()
        }
    }
}

private func tempLog(_ tag: String) throws -> EventLog {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("councis-\(tag)-\(UUID().uuidString)", isDirectory: true)
    return try EventLog(session: SessionID.new(), fileURL: dir.appendingPathComponent("events.jsonl"))
}

private let green = "\u{001B}[32m", red = "\u{001B}[31m", bold = "\u{001B}[1m", reset = "\u{001B}[0m"

func runSelfTest() async throws {
    out("\(bold)Councis self-test\(reset) — offline, no API key, no network.\n")

    // 1) CHAT: a full streamed turn.
    out("\n\(bold)[chat]\(reset)\n› hi")
    let chatLog = try tempLog("chat")
    let chatLoop = ChatLoop(log: chatLog,
                            provider: FakeChat(parts: ["Hello! ", "I am Councis."]),
                            model: ModelID(rawValue: "fake"))
    let r1 = Task { await renderLoop(chatLog) }
    try await chatLoop.send("hi")
    try? await Task.sleep(nanoseconds: 60_000_000)
    r1.cancel()
    let chatMsgs = ConversationProjection.build(from: await chatLog.replay()).messages
    let okChat = chatMsgs.contains { $0.role == .assistant && $0.text == "Hello! I am Councis." }
    out(okChat ? "\(green)PASS\(reset) streamed a complete reply\n"
               : "\(red)FAIL\(reset) chat reply not assembled\n")

    // 2) CODE: write a file, then read it back.
    out("\n\(bold)[work kernel]\(reset)\n› create note.txt and read it back")
    let workspace = FileManager.default.temporaryDirectory
        .appendingPathComponent("councis-ws-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    let codeLog = try tempLog("code")
    let writeArgs = String(decoding: try JSONSerialization.data(
        withJSONObject: ["path": "note.txt", "content": "hello from councis"]), as: UTF8.self)
    let agent = Agent(name: AgentID(rawValue: "selftest"), workspaceRoot: workspace,
                      model: ModelID(rawValue: "fake"), profile: .reviewed)
    let codeLoop = AgentLoop(
        log: codeLog,
        provider: FakeAgent([
            [.toolCalls([ToolCall(id: "c1", name: "write_file", arguments: writeArgs)]),
             .done(finishReason: "tool_calls")],
            [.toolCalls([ToolCall(id: "c2", name: "read_file", arguments: #"{"path":"note.txt"}"#)]),
             .done(finishReason: "tool_calls")],
            [.textDelta("Wrote and read note.txt."), .done(finishReason: "stop")],
        ]),
        registry: .standard(),
        engine: PermissionEngine(),
        responder: FixedResponder(.allow),   // auto-approve writes for the self-test
        agent: agent,
        allowsShell: true
    )
    let r2 = Task { await renderLoop(codeLog) }
    _ = try await codeLoop.send("create note.txt and read it back")
    try? await Task.sleep(nanoseconds: 60_000_000)
    r2.cancel()
    let onDisk = (try? String(contentsOf: workspace.appendingPathComponent("note.txt"), encoding: .utf8)) ?? ""
    let okCode = onDisk == "hello from councis"
    out(okCode ? "\(green)PASS\(reset) wrote + read note.txt in the workspace\n"
               : "\(red)FAIL\(reset) file not written (got: \(onDisk.isEmpty ? "<empty>" : onDisk))\n")

    // 3) TEAM PRESET: both the v2 schema and the old candidates/judge schema
    // decode without any endpoint URL or secret in the preset.
    out("\n\(bold)[team preset]\(reset)\n")
    let modern = #"{"schemaVersion":2,"name":"modern","mode":"chat","main":{"providerID":"p","model":"main"},"judge":{"providerID":"p","model":"judge"},"workerModelPool":[{"providerID":"p","model":"worker"}],"modelAssignment":{"strategy":"unique","onPoolExhaustion":"fail","excludeControlPlaneAgents":true},"providers":[{"id":"p"}]}"#
    let legacy = #"{"name":"legacy","mode":"chat","candidates":[{"provider":"p","model":"main"},{"provider":"p","model":"worker"}],"judge":{"provider":"p","model":"judge"}}"#
    let modernPreset = try? JSONDecoder().decode(TeamPreset.self, from: Data(modern.utf8))
    let legacyPreset = try? JSONDecoder().decode(TeamPreset.self, from: Data(legacy.utf8))
    let okPreset = modernPreset?.source == .team
        && modernPreset?.workerModelPool.count == 1
        && legacyPreset?.source == .legacyCouncil
        && legacyPreset?.main.model == "main"
        && legacyPreset?.workerModelPool.first?.model == "worker"
    out(okPreset ? "\(green)PASS\(reset) decoded v2 and legacy team presets\n"
                 : "\(red)FAIL\(reset) team preset compatibility decode failed\n")

    // 4) LEGACY RUN LOG: decode old Council output without reviving its engine.
    out("\n\(bold)[legacy run log]\(reset)\n")
    let legacyRunJSON = #"{"prompt":"compare answers","finalAnswer":"approved","startedAt":"2026-06-22T00:00:00Z","completedAt":"2026-06-22T00:00:01Z","surface":"chat","mock":true,"preset":{"name":"smoke","mode":"chat","engine":"council"},"candidateResults":[{"name":"A","provider":"p","model":"a","status":"succeeded","ok":true}],"judgeResult":{"name":"Judge","provider":"p","model":"j","status":"succeeded","ok":true}}"#
    let legacyRun = try? JSONDecoder().decode(
        LegacyCouncilRun.self,
        from: Data(legacyRunJSON.utf8))
    let okLegacyRun = legacyRun?.preset?.engine == "council"
        && legacyRun?.candidateResults?.first?.model == "a"
        && legacyRun?.judgeResult?.model == "j"
        && legacyRun?.finalAnswer == "approved"
    out(okLegacyRun ? "\(green)PASS\(reset) decoded legacy Council run read-only\n"
                    : "\(red)FAIL\(reset) legacy Council run decode failed\n")

    // 5) LAUNCH PARSER: one-shot prompt forms, explicit Work workspace,
    // narrowly-scoped `work DIR`, `--`, and the retired --mock rejection.
    out("\n\(bold)[one-shot launch parser]\(reset)\n")
    let parserRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("councis-parser-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: parserRoot, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: parserRoot) }
    let parserConfig = CLIConfig(
        providers: [CLIProviderRuntime(
            id: "fake",
            baseURL: URL(string: "https://example.invalid/v1")!,
            wire: .openai,
            apiKey: "offline")],
        defaultProviderID: "fake",
        model: "fake-model",
        reasoningEffort: nil,
        mode: .chat,
        preset: nil,
        includeUsage: false,
        maxSteps: 4)
    let chatLaunch = try parseLaunchArguments(
        ["--preset", "smoke", "explain", "this"],
        mode: .chat,
        config: parserConfig,
        currentDirectory: parserRoot)
    let chatREPL = try parseLaunchArguments(
        [],
        mode: .chat,
        config: parserConfig,
        currentDirectory: parserRoot)
    let chatDirectoryToken = try parseLaunchArguments(
        [parserRoot.path],
        mode: .chat,
        config: parserConfig,
        currentDirectory: parserRoot)
    let legacyWorkDirectory = try parseLaunchArguments(
        [parserRoot.path],
        mode: .work,
        config: parserConfig,
        currentDirectory: FileManager.default.temporaryDirectory)
    let explicitWork = try parseLaunchArguments(
        ["--workspace", parserRoot.path, "create", "a note"],
        mode: .work,
        config: parserConfig,
        currentDirectory: FileManager.default.temporaryDirectory)
    let separatorPrompt = try parseLaunchArguments(
        ["--dir=\(parserRoot.path)", "--", "--literal", "words"],
        mode: .work,
        config: parserConfig,
        currentDirectory: FileManager.default.temporaryDirectory)
    let forcedDirectoryPrompt = try parseLaunchArguments(
        ["--", parserRoot.path],
        mode: .work,
        config: parserConfig,
        currentDirectory: FileManager.default.temporaryDirectory)
    let mockRejected: Bool
    do {
        _ = try parseLaunchArguments(
            ["--mock", "hello"],
            mode: .chat,
            config: parserConfig,
            currentDirectory: parserRoot)
        mockRejected = false
    } catch {
        mockRejected = error.localizedDescription.contains("legacy Council engine was removed")
    }
    let okLaunchParser = chatLaunch.presetName == "smoke"
        && chatLaunch.prompt == "explain this"
        && chatREPL.prompt == nil
        && chatDirectoryToken.prompt == parserRoot.path
        && legacyWorkDirectory.workspace == parserRoot.standardizedFileURL
        && legacyWorkDirectory.prompt == nil
        && explicitWork.workspace == parserRoot.standardizedFileURL
        && explicitWork.prompt == "create a note"
        && separatorPrompt.prompt == "--literal words"
        && forcedDirectoryPrompt.prompt == parserRoot.path
        && mockRejected
    out(okLaunchParser
        ? "\(green)PASS\(reset) parsed Chat/Work one-shot, workspace, separator, and --mock cases\n"
        : "\(red)FAIL\(reset) one-shot launch argument semantics regressed\n")

    // 6) ONE-SHOT ROOT: exercise the exact CLI submission helper with offline
    // providers and prove the @main root is durable and Judge settles before it.
    out("\n\(bold)[one-shot durable root + Judge]\(reset)\n")
    let rootLog = try tempLog("one-shot-root")
    let mainProvider = FakeAgent([
        [.textDelta("reviewed one-shot answer"), .done(finishReason: "stop")],
    ])
    let judgeProvider = FakeAgent([
        [.textDelta(#"{"decision":"approve","summary":"The answer satisfies the task.","findings":[],"requiredRevisions":[]}"#),
         .done(finishReason: "stop")],
    ])
    let rootOrchestrator = try Orchestrator.runtime(
        log: rootLog,
        allowsShell: false,
        responder: FixedResponder(.allow),
        executionPolicy: CoworkExecutionPolicy(maxConcurrentTasks: 2),
        taskReviewPolicy: .always,
        surfaceProfile: .chat,
        providerFor: { agent in
            agent.name == Orchestrator.taskReviewerID ? judgeProvider : mainProvider
        })
    let mainAttached = await rootOrchestrator.attach(Agent(
        name: Orchestrator.mainAgentID,
        workspaceRoot: parserRoot,
        modelBinding: AgentModelBinding(
            providerID: "fake-main",
            modelID: ModelID(rawValue: "main")),
        profile: .reviewed,
        coordinationDepth: Agent.defaultCoordinationDepth))
    let judgeAttached = await rootOrchestrator.attachTaskReviewer(Agent(
        name: Orchestrator.taskReviewerID,
        workspaceRoot: parserRoot,
        modelBinding: AgentModelBinding(
            providerID: "fake-judge",
            modelID: ModelID(rawValue: "judge")),
        profile: .readOnly,
        coordinationDepth: 0))
    let rootResult = try await submitRootTask(
        "produce one reviewed answer",
        to: Orchestrator.mainAgentID,
        orchestrator: rootOrchestrator)
    let rootEvents = await rootLog.replay()
    let durableRoot = rootEvents.compactMap { envelope -> TaskContract? in
        guard case .taskCreated(let payload) = envelope.event,
              payload.contract.id == rootResult.taskID else { return nil }
        return payload.contract
    }.first
    let settledSequence = rootEvents.first { envelope in
        guard case .taskReviewSettled(let payload) = envelope.event else { return false }
        return payload.rootTaskID == rootResult.taskID
            && payload.verdict?.decision == .approve
    }?.seq
    let completionSequence = rootEvents.first { envelope in
        guard case .taskCompleted(let payload) = envelope.event else { return false }
        return payload.taskID == rootResult.taskID
    }?.seq
    let okOneShotRoot = mainAttached
        && judgeAttached
        && rootResult.succeeded
        && rootResult.reviewVerdict?.decision == .approve
        && durableRoot?.kind == .root
        && durableRoot?.assignee == Orchestrator.mainAgentID
        && settledSequence != nil
        && completionSequence != nil
        && settledSequence! < completionSequence!
    await rootOrchestrator.cancelAll(reason: "one-shot self-test complete")
    out(okOneShotRoot
        ? "\(green)PASS\(reset) @main root persisted and @judge settled before completion\n"
        : "\(red)FAIL\(reset) one-shot did not cross the durable Judge-gated root path\n")

    let allOK = okChat && okCode && okPreset && okLegacyRun
        && okLaunchParser && okOneShotRoot
    out("\n" + (allOK
        ? "\(green)\(bold)All good.\(reset) Point it at a real endpoint:\n  COUNCIS_API_KEY='your-key' swift run councis chat\n"
        : "\(red)\(bold)Self-test failed.\(reset)\n"))
    if !allOK {
        throw IntatisError.config("selftest failed")
    }
}
