import Foundation
import IntatisCore

/// Stable identifier for one bounded review attempt. A root task may create
/// several review attempts before it is allowed to become terminal.
public struct TaskReviewID: TypedID {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static func new() -> TaskReviewID {
        TaskReviewID(rawValue: IDGen.random(prefix: "review"))
    }
}

public enum TaskReviewDecision: String, Codable, Sendable, Hashable {
    case approve
    case revise
    case insufficientEvidence = "insufficient_evidence"
}

/// The only model-authored shape accepted by the task-review gate. Hosts should
/// decode it from a bare JSON object and reject prose, code fences, missing
/// fields, and unknown fields before persisting a settled review.
public struct TaskReviewVerdict: Codable, Equatable, Sendable, Hashable {
    public var decision: TaskReviewDecision
    public var summary: String
    public var findings: [String]
    public var requiredRevisions: [String]

    public init(decision: TaskReviewDecision,
                summary: String,
                findings: [String],
                requiredRevisions: [String]) {
        self.decision = decision
        self.summary = summary
        self.findings = findings
        self.requiredRevisions = requiredRevisions
    }
}

/// Durable-before-execution audit record for one ordinary scheduler-backed
/// review task. `reviewInput` is already bounded and mediated.
public struct TaskReviewRequestedPayload: Codable, Equatable, Sendable {
    public var reviewID: TaskReviewID
    public var rootTaskID: TaskID
    public var reviewTaskID: TaskID
    public var reviewer: AgentID
    public var round: Int
    public var rootAttempt: Int?
    /// Admission time for the end-to-end review deadline. Optional so older
    /// event logs remain decodable.
    public var createdAt: Date?
    /// Absolute deadline covering queue wait plus provider execution. Optional
    /// so older event logs remain decodable.
    public var deadline: Date?
    public var reviewInput: String
    public var metadata: CoworkEventMetadata?

    public init(reviewID: TaskReviewID = TaskReviewID.new(),
                rootTaskID: TaskID,
                reviewTaskID: TaskID,
                reviewer: AgentID,
                round: Int,
                rootAttempt: Int? = nil,
                createdAt: Date? = nil,
                deadline: Date? = nil,
                reviewInput: String,
                metadata: CoworkEventMetadata? = nil) {
        self.reviewID = reviewID
        self.rootTaskID = rootTaskID
        self.reviewTaskID = reviewTaskID
        self.reviewer = reviewer
        self.round = round
        self.rootAttempt = rootAttempt
        self.createdAt = createdAt
        self.deadline = deadline
        self.reviewInput = reviewInput
        self.metadata = metadata
    }
}

/// A review is settled only after a normal scheduler task reaches a terminal
/// state and its output is strictly decoded. Invalid output and execution
/// failures are represented by `error`; they never imply approval.
public struct TaskReviewSettledPayload: Codable, Equatable, Sendable {
    public var reviewID: TaskReviewID
    public var rootTaskID: TaskID
    public var reviewTaskID: TaskID
    public var reviewer: AgentID
    public var round: Int
    public var rootAttempt: Int?
    public var verdict: TaskReviewVerdict?
    public var error: String?
    public var metadata: CoworkEventMetadata?

    public init(reviewID: TaskReviewID,
                rootTaskID: TaskID,
                reviewTaskID: TaskID,
                reviewer: AgentID,
                round: Int,
                rootAttempt: Int? = nil,
                verdict: TaskReviewVerdict? = nil,
                error: String? = nil,
                metadata: CoworkEventMetadata? = nil) {
        self.reviewID = reviewID
        self.rootTaskID = rootTaskID
        self.reviewTaskID = reviewTaskID
        self.reviewer = reviewer
        self.round = round
        self.rootAttempt = rootAttempt
        self.verdict = verdict
        self.error = error
        self.metadata = metadata
    }
}

public struct TaskReviewExhaustedPayload: Codable, Equatable, Sendable {
    public var rootTaskID: TaskID
    public var reviewer: AgentID
    public var rounds: Int
    public var rootAttempt: Int?
    public var lastVerdict: TaskReviewVerdict?
    public var reason: String
    public var disposition: String
    public var metadata: CoworkEventMetadata?

    public init(rootTaskID: TaskID,
                reviewer: AgentID,
                rounds: Int,
                rootAttempt: Int? = nil,
                lastVerdict: TaskReviewVerdict? = nil,
                reason: String,
                disposition: String,
                metadata: CoworkEventMetadata? = nil) {
        self.rootTaskID = rootTaskID
        self.reviewer = reviewer
        self.rounds = rounds
        self.rootAttempt = rootAttempt
        self.lastVerdict = lastVerdict
        self.reason = reason
        self.disposition = disposition
        self.metadata = metadata
    }
}
