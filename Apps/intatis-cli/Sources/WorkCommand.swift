import Foundation
import IntatisCore

struct WorkWritePlan: Sendable {
    let path: String
    let content: String
    let readBack: Bool
}

struct WorkContextPlan: Sendable {
    let candidatePrompt: String
    let contextEvents: [String]
    let writes: [WorkWritePlan]
}

func runWorkCommand(_ args: [String]) async throws {
    if args.isEmpty {
        printWorkHelp()
        return
    }

    var presetName = "elite-work"
    var mock = false
    var promptParts: [String] = []
    var i = 0

    while i < args.count {
        let arg = args[i]
        switch arg {
        case "--mock", "--dry-run":
            mock = true
        case "--preset":
            i += 1
            guard i < args.count else { throw IntatisError.config("--preset requires a name") }
            presetName = args[i]
        case "--help", "-h":
            printWorkHelp()
            return
        default:
            promptParts.append(arg)
        }
        i += 1
    }

    let prompt = promptParts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !prompt.isEmpty else {
        printWorkHelp()
        throw IntatisError.config("work requires a prompt")
    }

    let config = try CLIConfig.load(requireAPIKey: !mock)
    let preset = try loadCouncilPreset(named: presetName)
    let workspace = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).standardizedFileURL
    let run = try await runWorkCouncil(prompt: prompt, config: config, preset: preset, mock: mock, workspace: workspace)
    let logURL = try saveCouncilRun(run)
    printCouncilRun(run, logURL: logURL)
}

private func printWorkHelp() {
    out("""
    USAGE
      councis work [--preset elite-work] [--mock] "prompt"

    Work is council-powered by default. It gathers limited workspace context,
    lets candidate models reason read-only over that same context, then lets the
    judge synthesize one answer. File writes, when needed, are executed once by
    the Work executor after approval.

    """)
}

func runWorkCouncil(prompt: String,
                    config: CLIConfig,
                    preset: CouncilPreset,
                    mock: Bool,
                    workspace: URL) async throws -> CouncilRunLog {
    guard preset.tools?.filesystem == true else {
        throw IntatisError.config("work preset must enable filesystem tools")
    }

    let plan = try buildWorkContext(prompt: prompt, workspace: workspace)
    let runner = CouncilRunner(config: config, preset: preset, mock: mock)
    let run = try await runner.run(
        prompt: plan.candidatePrompt,
        logPrompt: prompt,
        surface: "work",
        workspace: workspace.path,
        contextEvents: plan.contextEvents
    )
    let executorEvents = try executeWorkWrites(plan.writes, preset: preset, workspace: workspace, mock: mock)
    return copy(run, executorEvents: executorEvents)
}

func buildWorkContext(prompt: String, workspace: URL) throws -> WorkContextPlan {
    var events: [String] = [
        "candidate tools: none; candidates receive read-only context only",
        "executor: single controlled file writer after judge synthesis"
    ]
    var contextBlocks: [String] = [
        "Workspace: \(workspace.path)",
        "Candidate instructions: reason over this context only. Do not write files. If a file change is needed, describe the intended single executor action."
    ]
    var writes: [WorkWritePlan] = []
    let lower = prompt.lowercased()

    if lower.contains("readme") {
        let readme = try readWorkspaceFile("README.md", workspace: workspace)
        events.append("read README.md")
        contextBlocks.append("[file: README.md]\n\(readme)")
    }
    
    if lower.contains("list files") || lower.contains("list_files") || lower.contains("列出文件") {
        let listing = try listWorkspaceFiles(".", workspace: workspace)
        events.append("list_files .")
        contextBlocks.append("[list_files: .]\n\(listing)")
    }
    
    if let term = searchTerm(in: prompt) {
        let matches = try searchWorkspaceFiles(term, path: ".", workspace: workspace)
        events.append("search_files .")
        contextBlocks.append("[search_files: \(term)]\n\(matches)")
    }

    if lower.contains("create note.txt") || lower.contains("write note.txt") {
        let content = "Councis work mock note\n"
        let readBack = lower.contains("read it back") || lower.contains("read back")
        writes.append(WorkWritePlan(path: "note.txt", content: content, readBack: readBack))
        events.append("planned executor write: note.txt")
    }

    let candidatePrompt = """
    User request:
    \(prompt)

    Work context:
    \(contextBlocks.joined(separator: "\n\n"))
    """
    return WorkContextPlan(candidatePrompt: candidatePrompt, contextEvents: events, writes: writes)
}

func executeWorkWrites(_ writes: [WorkWritePlan],
                       preset: CouncilPreset,
                       workspace: URL,
                       mock: Bool) throws -> [String] {
    guard !writes.isEmpty else { return [] }
    let allowed = Set(preset.tools?.allowed ?? [])
    guard allowed.contains("write_file") else {
        throw IntatisError.permissionDenied("work preset does not allow write_file")
    }

    var events: [String] = []
    for write in writes {
        let approved = mock || approveWrite(write)
        guard approved else {
            events.append("write_file \(write.path) denied")
            continue
        }

        try writeWorkspaceFile(write.path, content: write.content, workspace: workspace)
        events.append("write_file \(write.path) approved")

        if write.readBack {
            _ = try readWorkspaceFile(write.path, workspace: workspace)
            events.append("read_file \(write.path)")
        }
    }
    return events
}

private func approveWrite(_ write: WorkWritePlan) -> Bool {
    out("approve write_file \(write.path)? [y/N] ")
    let answer = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return answer == "y" || answer == "yes"
}

func readWorkspaceFile(_ path: String, workspace: URL) throws -> String {
    let url = try PathConfinement.resolve(path, within: workspace)
    return try String(contentsOf: url, encoding: .utf8)
}

func listWorkspaceFiles(_ path: String, workspace: URL) throws -> String {
    let url = try PathConfinement.resolve(path, within: workspace)
    let items = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey])
    return items
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
        .prefix(100)
        .map { item in
            let values = try? item.resourceValues(forKeys: [.isDirectoryKey])
            return (values?.isDirectory == true ? "\(item.lastPathComponent)/" : item.lastPathComponent)
        }
        .joined(separator: "\n")
}

func searchWorkspaceFiles(_ term: String, path: String, workspace: URL) throws -> String {
    let base = try PathConfinement.resolve(path, within: workspace)
    guard let enumerator = FileManager.default.enumerator(at: base, includingPropertiesForKeys: [.isRegularFileKey]) else {
        return ""
    }
    
    var matches: [String] = []
    for case let url as URL in enumerator {
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
        guard values?.isRegularFile == true else { continue }
        guard let text = try? String(contentsOf: url, encoding: .utf8), text.contains(term) else { continue }
        matches.append(PathConfinement.relativePath(of: url, root: workspace))
        if matches.count >= 50 { break }
    }
    return matches.isEmpty ? "(no matches)" : matches.joined(separator: "\n")
}

func writeWorkspaceFile(_ path: String, content: String, workspace: URL) throws {
    let url = try PathConfinement.resolve(path, within: workspace)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try content.write(to: url, atomically: true, encoding: .utf8)
}

private func searchTerm(in prompt: String) -> String? {
    let lower = prompt.lowercased()
    guard let range = lower.range(of: "search ") ?? lower.range(of: "search_files ") else {
        return nil
    }
    let rest = prompt[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
    let first = rest.split(separator: " ", maxSplits: 1).first.map(String.init) ?? ""
    return first.isEmpty ? nil : first
}

private func copy(_ run: CouncilRunLog, executorEvents: [String]) -> CouncilRunLog {
    CouncilRunLog(
        surface: run.surface,
        preset: run.preset,
        prompt: run.prompt,
        mock: run.mock,
        startedAt: run.startedAt,
        completedAt: run.completedAt,
        baseURL: run.baseURL,
        streaming: run.streaming,
        workspace: run.workspace,
        contextEvents: run.contextEvents,
        candidateResults: run.candidateResults,
        judgeResult: run.judgeResult,
        finalAnswer: run.finalAnswer,
        executorEvents: executorEvents
    )
}
