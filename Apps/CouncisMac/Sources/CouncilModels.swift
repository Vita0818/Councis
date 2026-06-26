import Foundation

enum CouncisMode: String, Equatable, Sendable {
    case chat
    case work

    var title: String {
        switch self {
        case .chat: return "Chat"
        case .work: return "Work"
        }
    }

    var presetTitle: String {
        switch self {
        case .chat: return "Elite"
        case .work: return "Elite Work"
        }
    }
}

enum CouncisSection: String, CaseIterable, Identifiable, Sendable {
    case chat
    case work
    case runs
    case presets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chat: return "Chat"
        case .work: return "Work"
        case .runs: return "Runs"
        case .presets: return "Presets"
        }
    }

    var symbolName: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .work: return "doc.text.magnifyingglass"
        case .runs: return "clock.arrow.circlepath"
        case .presets: return "slider.horizontal.3"
        }
    }
}

enum CouncilCandidateStatus: String, Equatable, Sendable {
    case waiting
    case running
    case done
    case failed
}

struct CouncilCandidateViewState: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var model: String
    var status: CouncilCandidateStatus
    var latencyText: String?

    init(id: UUID = UUID(),
         name: String,
         model: String,
         status: CouncilCandidateStatus,
         latencyText: String? = nil) {
        self.id = id
        self.name = name
        self.model = model
        self.status = status
        self.latencyText = latencyText
    }
}

struct CouncilJudgeViewState: Equatable, Sendable {
    var name: String
    var model: String
    var status: String
    var base: String?
    var patched: [String]
}

struct CouncilRunViewState: Identifiable, Equatable, Sendable {
    let id: UUID
    var mode: CouncisMode
    var title: String
    var prompt: String
    var finalAnswer: String
    var candidates: [CouncilCandidateViewState]
    var judge: CouncilJudgeViewState
    var auditEvents: [String]
    var files: [String]
    var workspacePath: String?
    var isMock: Bool

    init(id: UUID = UUID(),
         mode: CouncisMode,
         title: String,
         prompt: String,
         finalAnswer: String,
         candidates: [CouncilCandidateViewState],
         judge: CouncilJudgeViewState,
         auditEvents: [String],
         files: [String] = [],
         workspacePath: String? = nil,
         isMock: Bool = true) {
        self.id = id
        self.mode = mode
        self.title = title
        self.prompt = prompt
        self.finalAnswer = finalAnswer
        self.candidates = candidates
        self.judge = judge
        self.auditEvents = auditEvents
        self.files = files
        self.workspacePath = workspacePath
        self.isMock = isMock
    }

    var succeededCandidateCount: Int {
        candidates.filter { $0.status == .done }.count
    }

    var candidateSummary: String {
        "\(succeededCandidateCount)/\(candidates.count) candidates"
    }
}
