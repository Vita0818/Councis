import Foundation
import IntatisCore
import IntatisProviders

private struct CouncilAgentConfig: Codable, Sendable {
    let name: String
    let model: String
    let provider: String
    let required: Bool?
}

private struct CouncilPreset: Codable, Sendable {
    let name: String
    let candidates: [CouncilAgentConfig]
    let judge: CouncilAgentConfig?
    let mode: String?
    let minSuccessfulCandidates: Int?
    let failSoft: Bool?
    let anonymizeCandidates: Bool?
    let shuffleCandidates: Bool?
}

private struct CouncilAgentResult: Codable, Sendable {
    let name: String
    let model: String
    let provider: String
    let ok: Bool
    let answer: String
    let error: String?
    let elapsedMillis: Int
}

private struct CouncilRunLog: Codable, Sendable {
    let preset: CouncilPreset
    let prompt: String
    let mock: Bool
    let startedAt: String
    let completedAt: String
    let baseURL: String
    let candidateResults: [CouncilAgentResult]
    let judgeResult: CouncilAgentResult?
    let finalAnswer: String
}

func runCouncilCommand(_ args: [String]) async throws {
    var presetName = "elite"
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
            printCouncilHelp()
            return
        default:
            promptParts.append(arg)
        }
        i += 1
    }

    let prompt = promptParts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !prompt.isEmpty else {
        printCouncilHelp()
        throw IntatisError.config("council requires a prompt")
    }

    let config = try CLIConfig.load(requireAPIKey: !mock)
    let preset = try loadCouncilPreset(named: presetName)
    let runner = CouncilRunner(config: config, preset: preset, mock: mock)
    let run = try await runner.run(prompt: prompt)
    let logURL = try saveCouncilRun(run)

    let successCount = run.candidateResults.filter(\.ok).count
    out("Councis council · preset \(preset.name) · \(successCount)/\(run.candidateResults.count) candidates succeeded")
    if mock { out(" · mock") }
    out("\n\n")

    for result in run.candidateResults {
        if result.ok {
            out("[ok] \(result.name) · \(result.model) · \(result.elapsedMillis)ms\n")
        } else {
            out("[failed] \(result.name) · \(result.model) · \(result.error ?? "unknown error")\n")
        }
    }
    if let judge = run.judgeResult {
        out(judge.ok
            ? "[judge] \(judge.name) · \(judge.model) · \(judge.elapsedMillis)ms\n"
            : "[judge failed] \(judge.name) · \(judge.error ?? "unknown error")\n")
    }

    out("\nFinal answer\n")
    out(run.finalAnswer.trimmingCharacters(in: .whitespacesAndNewlines))
    out("\n\nrun log: \(logURL.path)\n")
}

private func printCouncilHelp() {
    out("""
    USAGE
      councis council [--preset elite] [--mock] "prompt"

    Reads .councis/presets/<name>.json, runs candidate agents in parallel, then
    asks the configured judge to synthesize when available.

    """)
}

private func loadCouncilPreset(named name: String) throws -> CouncilPreset {
    let fm = FileManager.default
    let local = URL(fileURLWithPath: fm.currentDirectoryPath)
        .appendingPathComponent(".councis/presets/\(name).json")
    let home = fm.homeDirectoryForCurrentUser
        .appendingPathComponent(".councis/presets/\(name).json")
    let url: URL
    if fm.fileExists(atPath: local.path) {
        url = local
    } else if fm.fileExists(atPath: home.path) {
        url = home
    } else {
        throw IntatisError.config("missing council preset: \(local.path)")
    }
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(CouncilPreset.self, from: data)
}

private struct CouncilRunner {
    let config: CLIConfig
    let preset: CouncilPreset
    let mock: Bool

    func run(prompt: String) async throws -> CouncilRunLog {
        let started = timestamp()
        var candidates = preset.candidates
        if preset.shuffleCandidates == true {
            candidates.shuffle()
        }

        var results: [CouncilAgentResult] = []
        await withTaskGroup(of: CouncilAgentResult.self) { group in
            for candidate in candidates {
                group.addTask {
                    await runCandidate(candidate, prompt: prompt, config: config, mock: mock)
                }
            }
            for await result in group {
                results.append(result)
            }
        }

        let orderedResults = results.sorted { lhs, rhs in
            let li = candidates.firstIndex { $0.name == lhs.name } ?? Int.max
            let ri = candidates.firstIndex { $0.name == rhs.name } ?? Int.max
            return li < ri
        }
        let successes = orderedResults.filter(\.ok)
        let minSuccess = preset.minSuccessfulCandidates ?? 1
        let canJudge = successes.count >= minSuccess

        var judgeResult: CouncilAgentResult?
        let finalAnswer: String
        if canJudge, let judge = preset.judge {
            judgeResult = await runJudge(judge, prompt: prompt, candidateResults: successes,
                                         config: config, preset: preset, mock: mock)
            if let judgeResult, judgeResult.ok {
                finalAnswer = judgeResult.answer
            } else if preset.failSoft == true {
                finalAnswer = fallbackAnswer(successes: successes, minSuccess: minSuccess)
            } else {
                finalAnswer = "Judge failed: \(judgeResult?.error ?? "unknown error")"
            }
        } else {
            finalAnswer = fallbackAnswer(successes: successes, minSuccess: minSuccess)
        }

        return CouncilRunLog(
            preset: preset,
            prompt: prompt,
            mock: mock,
            startedAt: started,
            completedAt: timestamp(),
            baseURL: config.baseURL.absoluteString,
            candidateResults: orderedResults,
            judgeResult: judgeResult,
            finalAnswer: finalAnswer
        )
    }
}

private func runCandidate(_ agent: CouncilAgentConfig, prompt: String,
                          config: CLIConfig, mock: Bool) async -> CouncilAgentResult {
    let started = Date()
    if mock {
        return await mockAgent(agent, prompt: prompt, started: started, role: "candidate")
    }
    return await callChat(agent, prompt: prompt, system: candidateSystemPrompt,
                          config: config, started: started)
}

private func runJudge(_ agent: CouncilAgentConfig, prompt: String,
                      candidateResults: [CouncilAgentResult], config: CLIConfig,
                      preset: CouncilPreset, mock: Bool) async -> CouncilAgentResult {
    let started = Date()
    if mock {
        return await mockJudge(agent, prompt: prompt, candidates: candidateResults, started: started)
    }
    let answers = candidateBlocks(candidateResults, anonymize: preset.anonymizeCandidates == true)
    let judgePrompt = """
    User prompt:
    \(prompt)

    Candidate answers:
    \(answers)

    Synthesize the strongest final answer. Prefer correctness over consensus.
    """
    return await callChat(agent, prompt: judgePrompt, system: judgeSystemPrompt,
                          config: config, started: started)
}

private let candidateSystemPrompt = """
You are a candidate expert in a multi-agent council. Answer the user's prompt directly.
Be concise, technically accurate, and note uncertainty.
"""

private let judgeSystemPrompt = """
You are the judge in a multi-agent council. Compare candidate answers, correct mistakes,
and produce one final answer. Do not mention hidden candidate names unless necessary.
"""

private func callChat(_ agent: CouncilAgentConfig, prompt: String, system: String,
                      config: CLIConfig, started: Date) async -> CouncilAgentResult {
    guard agent.provider == "openai-compatible" else {
        return CouncilAgentResult(name: agent.name, model: agent.model, provider: agent.provider,
                                  ok: false, answer: "", error: "unsupported provider: \(agent.provider)",
                                  elapsedMillis: elapsedMillis(since: started))
    }

    do {
        let endpoint = ProviderEndpoint(
            id: "council",
            baseURL: config.baseURL,
            apiKeyRef: KeychainRef(service: "councis-cli", account: "council"),
            wire: .openai
        )
        let provider = OpenAIWireProvider(endpoint: endpoint, apiKey: config.apiKey,
                                          http: URLSessionStreamingClient())
        let request = ChatRequest(
            model: ModelID(rawValue: agent.model),
            messages: [
                ChatMessage(role: .system, content: system),
                ChatMessage(role: .user, content: prompt),
            ],
            reasoningEffort: config.reasoningEffort,
            includeUsage: config.includeUsage
        )
        var text = ""
        for try await chunk in provider.stream(request) {
            if case .delta(let delta) = chunk {
                text += delta
            }
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return CouncilAgentResult(name: agent.name, model: agent.model, provider: agent.provider,
                                  ok: !trimmed.isEmpty, answer: trimmed,
                                  error: trimmed.isEmpty ? "empty response" : nil,
                                  elapsedMillis: elapsedMillis(since: started))
    } catch {
        return CouncilAgentResult(name: agent.name, model: agent.model, provider: agent.provider,
                                  ok: false, answer: "", error: error.localizedDescription,
                                  elapsedMillis: elapsedMillis(since: started))
    }
}

private func mockAgent(_ agent: CouncilAgentConfig, prompt: String, started: Date,
                       role: String) async -> CouncilAgentResult {
    let delay = UInt64(60 + stableSmallNumber(agent.name, modulo: 120)) * 1_000_000
    try? await Task.sleep(nanoseconds: delay)
    if role == "candidate", agent.name.lowercased().contains("gemini") {
        return CouncilAgentResult(name: agent.name, model: agent.model, provider: agent.provider,
                                  ok: false, answer: "", error: "mock failure for fail-soft coverage",
                                  elapsedMillis: elapsedMillis(since: started))
    }
    let answer = "\(agent.name) mock answer for: \(prompt)"
    return CouncilAgentResult(name: agent.name, model: agent.model, provider: agent.provider,
                              ok: true, answer: answer, error: nil,
                              elapsedMillis: elapsedMillis(since: started))
}

private func mockJudge(_ agent: CouncilAgentConfig, prompt: String,
                       candidates: [CouncilAgentResult], started: Date) async -> CouncilAgentResult {
    try? await Task.sleep(nanoseconds: 80_000_000)
    let answer = """
    Mock synthesis for "\(prompt)" using \(candidates.count) successful candidate answers.
    This verifies the council workflow, parallel candidate collection, fail-soft handling, and judge handoff without using an API key.
    """
    return CouncilAgentResult(name: agent.name, model: agent.model, provider: agent.provider,
                              ok: true, answer: answer, error: nil,
                              elapsedMillis: elapsedMillis(since: started))
}

private func fallbackAnswer(successes: [CouncilAgentResult], minSuccess: Int) -> String {
    guard !successes.isEmpty else {
        return "No candidate succeeded; minimum required successful candidates: \(minSuccess)."
    }
    return successes.map { result in
        "## \(result.name)\n\(result.answer)"
    }.joined(separator: "\n\n")
}

private func candidateBlocks(_ results: [CouncilAgentResult], anonymize: Bool) -> String {
    results.enumerated().map { index, result in
        let label = anonymize ? "Candidate \(index + 1)" : result.name
        return "\(label):\n\(result.answer)"
    }.joined(separator: "\n\n")
}

private func saveCouncilRun(_ run: CouncilRunLog) throws -> URL {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(".councis/runs", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let safeStamp = run.startedAt
        .replacingOccurrences(of: ":", with: "-")
        .replacingOccurrences(of: ".", with: "-")
    let url = root.appendingPathComponent("run-\(safeStamp).json")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(run).write(to: url, options: .atomic)
    return url
}

private func timestamp() -> String {
    ISO8601DateFormatter().string(from: Date())
}

private func elapsedMillis(since start: Date) -> Int {
    Int(Date().timeIntervalSince(start) * 1000)
}

private func stableSmallNumber(_ text: String, modulo: Int) -> Int {
    let value = text.utf8.reduce(0) { partial, byte in
        (partial * 31 + Int(byte)) % modulo
    }
    return value
}
