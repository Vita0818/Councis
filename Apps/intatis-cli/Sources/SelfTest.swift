import Foundation
import IntatisCore

private let green = "\u{001B}[32m", red = "\u{001B}[31m", bold = "\u{001B}[1m", reset = "\u{001B}[0m"

private func tempWorkspace(_ tag: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("councis-\(tag)-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func report(_ name: String, _ ok: Bool, _ detail: String) -> Bool {
    out(ok ? "\(green)PASS\(reset) \(name) — \(detail)\n"
           : "\(red)FAIL\(reset) \(name) — \(detail)\n")
    return ok
}

func runSelfTest() async throws {
    out("\(bold)Councis self-test\(reset) — offline, no API key, no network.\n")

    let config = try CLIConfig.load(requireAPIKey: false)
    var allOK = true

    out("\n\(bold)[chat-council]\(reset)\n› council-powered mock chat\n")
    let chatPreset = try loadCouncilPreset(named: "elite-chat")
    let chatRun = try await CouncilRunner(config: config, preset: chatPreset, mock: true)
        .run(prompt: "Explain Hamiltonian paths and Hamiltonian cycles", surface: "chat")
    let chatLogURL = try saveCouncilRun(chatRun)
    let chatSuccesses = chatRun.candidateResults.filter(\.ok).count
    allOK = report("chat default engine", chatRun.preset.engine == "council" && chatRun.surface == "chat", "chat uses council engine") && allOK
    allOK = report("chat candidates", chatRun.candidateResults.count >= 5 && chatSuccesses >= 2, "\(chatSuccesses)/\(chatRun.candidateResults.count) candidates succeeded") && allOK
    allOK = report("chat judge", chatRun.judgeResult?.ok == true && chatRun.finalAnswer.contains("Mock synthesis"), "judge synthesis produced final answer") && allOK
    allOK = report("chat fail-soft", chatRun.candidateResults.contains { !$0.ok }, "one mock candidate failed without failing the run") && allOK
    allOK = report("chat run log", FileManager.default.fileExists(atPath: chatLogURL.path), chatLogURL.path) && allOK

    out("\n\(bold)[work-council]\(reset)\n› council-powered mock work with file read/write\n")
    let workspace = try tempWorkspace("work")
    try "Temporary README for Councis work selftest.\n".write(
        to: workspace.appendingPathComponent("README.md"),
        atomically: true,
        encoding: .utf8
    )
    let workPreset = try loadCouncilPreset(named: "elite-work")
    let workRun = try await runWorkCouncil(
        prompt: "read README and create note.txt and read it back",
        config: config,
        preset: workPreset,
        mock: true,
        workspace: workspace
    )
    let workLogURL = try saveCouncilRun(workRun)
    let note = (try? readWorkspaceFile("note.txt", workspace: workspace)) ?? ""
    allOK = report("work default engine", workRun.preset.engine == "council" && workRun.surface == "work", "work uses council engine") && allOK
    allOK = report("work context", workRun.contextEvents.contains("read README.md"), "workspace context was gathered once") && allOK
    allOK = report("work candidate read-only", workRun.contextEvents.contains { $0.contains("candidate tools: none") }, "candidates did not receive write tools") && allOK
    allOK = report("work executor write", note == "Councis work mock note\n", "executor wrote note.txt once") && allOK
    allOK = report("work executor readback", workRun.executorEvents.contains("read_file note.txt"), "executor read note.txt after writing") && allOK
    allOK = report("work escape rejection", !PathConfinement.isWithin("../outside.txt", root: workspace), "workspace escape rejected") && allOK
    allOK = report("work run log", FileManager.default.fileExists(atPath: workLogURL.path), workLogURL.path) && allOK

    let logged = try JSONDecoder().decode(CouncilRunLog.self, from: Data(contentsOf: workLogURL))
    allOK = report("run log content", !logged.candidateResults.isEmpty && logged.judgeResult != nil && !logged.finalAnswer.isEmpty, "candidates, judge, and final answer recorded") && allOK

    out("\n" + (allOK
        ? "\(green)\(bold)All good.\(reset) Chat and Work are council-powered.\n"
        : "\(red)\(bold)Self-test failed.\(reset)\n"))

    if !allOK {
        throw IntatisError.config("selftest failed")
    }
}
