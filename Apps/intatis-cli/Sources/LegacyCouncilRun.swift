import Foundation
import IntatisCore

/// Read-only compatibility view for v0.1 fixed-fan-out Council run logs. It is
/// intentionally not an executor and never rewrites the source JSON.
struct LegacyCouncilRun: Decodable, Sendable {
    struct Preset: Decodable, Sendable {
        var name: String?
        var mode: String?
        var engine: String?
    }

    struct Participant: Decodable, Sendable {
        var name: String?
        var provider: String?
        var model: String?
        var status: String?
        var ok: Bool?
        var elapsedMillis: Int?
        var error: String?
    }

    var prompt: String?
    var finalAnswer: String?
    var startedAt: String?
    var completedAt: String?
    var surface: String?
    var mock: Bool?
    var preset: Preset?
    var candidateResults: [Participant]?
    var judgeResult: Participant?
}

struct LegacyCouncilRunFile: Sendable {
    var url: URL
    var run: LegacyCouncilRun
}

enum LegacyCouncilRunReader {
    static func read(_ url: URL) throws -> LegacyCouncilRunFile {
        let resolved = url.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            throw IntatisError.config("legacy run log is not a file: \(resolved.path)")
        }
        do {
            return LegacyCouncilRunFile(
                url: resolved,
                run: try JSONDecoder().decode(
                    LegacyCouncilRun.self,
                    from: Data(contentsOf: resolved)))
        } catch {
            throw IntatisError.decoding(
                "legacy Council run '\(resolved.lastPathComponent)': \(error.localizedDescription)")
        }
    }

    static func discover() -> [URL] {
        let fileManager = FileManager.default
        let roots = [
            URL(fileURLWithPath: fileManager.currentDirectoryPath)
                .appendingPathComponent(".councis/runs", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent(".councis/runs", isDirectory: true),
        ]
        var seen = Set<String>()
        return roots.flatMap { root -> [URL] in
            guard let files = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]) else { return [] }
            return files.filter { $0.pathExtension.lowercased() == "json" }
        }
        .filter { seen.insert($0.standardizedFileURL.path).inserted }
        .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }
}

func printLegacyCouncilRuns(_ arguments: [String]) throws {
    var path: String?
    var showAnswer = false
    for argument in arguments {
        if argument == "--show-answer" {
            showAnswer = true
        } else if argument.hasPrefix("-") {
            throw IntatisError.config("unknown runs option: \(argument)")
        } else if path == nil {
            path = argument
        } else {
            throw IntatisError.config("runs accepts at most one file path")
        }
    }

    let files: [LegacyCouncilRunFile]
    if let path {
        let expanded = (path as NSString).expandingTildeInPath
        files = [try LegacyCouncilRunReader.read(URL(fileURLWithPath: expanded))]
    } else {
        files = LegacyCouncilRunReader.discover().compactMap {
            try? LegacyCouncilRunReader.read($0)
        }
    }

    guard !files.isEmpty else {
        out("No legacy Council run logs found in .councis/runs.\n")
        return
    }
    for file in files {
        printLegacyCouncilRun(file, showAnswer: showAnswer)
    }
}

private func printLegacyCouncilRun(_ file: LegacyCouncilRunFile,
                                   showAnswer: Bool) {
    let run = file.run
    let candidates = run.candidateResults ?? []
    let succeeded = candidates.filter { $0.ok == true || $0.status == "succeeded" }.count
    let failed = candidates.count - succeeded
    let preset = run.preset?.name ?? "(unknown preset)"
    let surface = run.surface ?? run.preset?.mode ?? "(unknown surface)"
    let judge = [run.judgeResult?.provider, run.judgeResult?.model]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: "/")
    let prompt = bounded(run.prompt ?? "(prompt unavailable)", limit: 180)

    out("\(file.url.lastPathComponent)\n")
    out("  preset  : \(preset) · \(surface)\n")
    out("  time    : \(run.startedAt ?? "(unknown)") → \(run.completedAt ?? "(unknown)")\n")
    out("  agents  : \(succeeded) succeeded · \(failed) failed · judge \(judge.isEmpty ? "(unknown)" : judge)\n")
    out("  prompt  : \(prompt)\n")
    out("  answer  : \((run.finalAnswer ?? "").count) characters\(run.mock == true ? " · mock" : "")\n")
    if showAnswer, let answer = run.finalAnswer {
        out("\n\(answer)\n")
    }
    out("\n")
}

private func bounded(_ value: String, limit: Int) -> String {
    let normalized = value
        .replacingOccurrences(of: "\n", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard normalized.count > limit else { return normalized }
    return String(normalized.prefix(limit)) + "…"
}
