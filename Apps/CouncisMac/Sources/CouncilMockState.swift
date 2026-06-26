import Foundation

enum CouncilMockState {
    static var chatRun: CouncilRunViewState {
        CouncilRunViewState(
            mode: .chat,
            title: "Chat",
            prompt: "Explain the tradeoff between strict consensus and judge-led synthesis.",
            finalAnswer: "Use candidate diversity to surface disagreement, then let the judge choose a base answer and patch gaps. Treat consensus as evidence, not the decision rule.",
            candidates: candidates,
            judge: judge,
            auditEvents: [
                "run started",
                "candidate GPT-5.5-Pro finished",
                "candidate Gemini 3.1 Pro failed",
                "judge synthesis finished"
            ]
        )
    }

    static func workRun(workspacePath: String) -> CouncilRunViewState {
        CouncilRunViewState(
            mode: .work,
            title: "Work",
            prompt: "Read the current project context and propose the smallest UI shell change.",
            finalAnswer: "Keep Work centered on read-only context for candidates. Apply file changes once after synthesis, with files and audit events visible beside the answer.",
            candidates: candidates,
            judge: judge,
            auditEvents: [
                "run started",
                "workspace context loaded",
                "candidate GPT-5.5-Pro finished",
                "candidate Gemini 3.1 Pro failed",
                "judge synthesis finished"
            ],
            files: [
                "README.md",
                "Package.swift",
                "Apps/intatis-cli/Sources/Council.swift"
            ],
            workspacePath: workspacePath
        )
    }

    static func updatedRun(from run: CouncilRunViewState, prompt: String) -> CouncilRunViewState {
        var copy = run
        copy.prompt = prompt
        copy.finalAnswer = "Mock synthesis for: \(prompt)"
        copy.auditEvents = run.mode == .work
            ? ["run started", "workspace context loaded", "candidates finished", "judge synthesis finished"]
            : ["run started", "candidates finished", "judge synthesis finished"]
        copy.isMock = true
        return copy
    }

    private static var candidates: [CouncilCandidateViewState] {
        [
            CouncilCandidateViewState(name: "GPT-5.5-Pro", model: "gpt-5.5-pro", status: .done, latencyText: "42.1s"),
            CouncilCandidateViewState(name: "Opus 4.8", model: "opus-4.8", status: .done, latencyText: "51.7s"),
            CouncilCandidateViewState(name: "Gemini 3.1 Pro", model: "gemini-3.1-pro", status: .failed, latencyText: "timeout"),
            CouncilCandidateViewState(name: "Fable 5", model: "fable-5", status: .done, latencyText: "38.4s"),
            CouncilCandidateViewState(name: "GPT-5.5", model: "gpt-5.5", status: .done, latencyText: "35.2s")
        ]
    }

    private static var judge: CouncilJudgeViewState {
        CouncilJudgeViewState(
            name: "DeepSeek",
            model: "DeepSeek-v4-Pro",
            status: "ready",
            base: "Opus 4.8",
            patched: ["GPT-5.5-Pro", "Fable 5"]
        )
    }
}
