import XCTest
import IntatisCore
import IntatisProtocol
@testable import IntatisConversation

final class ReviewedTaskPresentationTests: XCTestCase {
    private let session = SessionID(rawValue: "reviewed-presentation")
    private let rootTaskID = TaskID(rawValue: "task_root")
    private let reviewTaskID = TaskID(rawValue: "task_review")
    private let main = AgentID(rawValue: "main")
    private let judge = AgentID(rawValue: "judge")

    private func envelope(_ seq: Int, _ event: Event) -> Envelope {
        Envelope(seq: seq, ts: Date(timeIntervalSince1970: Double(seq)), session: session, event: event)
    }

    private func verdict(
        _ decision: TaskReviewDecision,
        revisions: [String] = []
    ) -> TaskReviewVerdict {
        TaskReviewVerdict(
            decision: decision,
            summary: "review \(decision.rawValue)",
            findings: decision == .approve ? [] : ["draft needs work"],
            requiredRevisions: revisions)
    }

    private func settled(
        seq: Int,
        round: Int,
        verdict: TaskReviewVerdict? = nil,
        error: String? = nil
    ) -> Envelope {
        envelope(seq, .taskReviewSettled(TaskReviewSettledPayload(
            reviewID: TaskReviewID(rawValue: "review_\(round)"),
            rootTaskID: rootTaskID,
            reviewTaskID: reviewTaskID,
            reviewer: judge,
            round: round,
            rootAttempt: 1,
            verdict: verdict,
            error: error)))
    }

    func testMandatoryReviewReplayHidesEveryDraftAndDeliversOnlyApprovedRevisionOnce() {
        let initialMessageID = MessageID(rawValue: "msg_initial")
        let judgeMessageID = MessageID(rawValue: "msg_judge")
        let revisedMessageID = MessageID(rawValue: "msg_revised")
        let internalToolCallID = "tool_internal_message"
        let visibleToolCallID = "tool_visible_read"
        let rawJudgeApprove = #"{"decision":"approve","summary":"raw","findings":[],"requiredRevisions":[]}"#
        let internalToolText = "private task input and draft through tool arguments"

        let beforeApproval = [
            envelope(0, .userMessage(UserMessagePayload(
                text: "public request",
                to: main,
                presentation: .userVisible))),
            envelope(1, .messageDelta(MessageDeltaPayload(
                messageId: initialMessageID,
                role: .agent,
                agent: main,
                textDelta: "initial draft"))),
            envelope(2, .messageCompleted(MessageCompletedPayload(
                messageId: initialMessageID,
                role: .agent,
                agent: main,
                text: "initial draft"))),
            envelope(3, .userMessage(UserMessagePayload(
                text: "internal evidence contains initial draft",
                to: judge,
                presentation: .internalContext))),
            envelope(4, .toolCall(ToolCallPayload(
                toolCallId: internalToolCallID,
                agent: main,
                name: "send_message",
                args: "{\"content\":\"\(internalToolText)\"}"))),
            envelope(5, .toolResult(ToolResultPayload(
                toolCallId: internalToolCallID,
                observation: internalToolText))),
            envelope(6, .toolCall(ToolCallPayload(
                toolCallId: visibleToolCallID,
                agent: main,
                name: "read_file",
                args: #"{"path":"README.md"}"#))),
            envelope(7, .toolResult(ToolResultPayload(
                toolCallId: visibleToolCallID,
                observation: "ordinary operational audit remains visible"))),
            envelope(8, .messageDelta(MessageDeltaPayload(
                messageId: judgeMessageID,
                role: .agent,
                agent: judge,
                textDelta: rawJudgeApprove))),
            envelope(9, .messageCompleted(MessageCompletedPayload(
                messageId: judgeMessageID,
                role: .agent,
                agent: judge,
                text: rawJudgeApprove))),
            settled(
                seq: 10,
                round: 1,
                verdict: verdict(.revise, revisions: ["replace the draft"])),
            envelope(11, .messageDelta(MessageDeltaPayload(
                messageId: revisedMessageID,
                role: .agent,
                agent: main,
                textDelta: "final revised answer"))),
            envelope(12, .messageCompleted(MessageCompletedPayload(
                messageId: revisedMessageID,
                role: .agent,
                agent: main,
                text: "final revised answer"))),
        ]

        let pending = CodeProjection.build(
            from: beforeApproval,
            presentationPolicy: .mandatoryTaskReview)
        XCTAssertEqual(pending.items.filter { $0.kind == .user }.map(\.body), ["public request"])
        XCTAssertTrue(pending.items.filter { $0.kind == .agent }.isEmpty)
        XCTAssertFalse(pending.items.contains { $0.body.contains("initial draft") })
        XCTAssertFalse(pending.items.contains { $0.body.contains(rawJudgeApprove) })
        XCTAssertFalse(pending.items.contains { $0.body.contains(internalToolText) })
        XCTAssertTrue(pending.items.contains { $0.body.contains("ordinary operational audit remains visible") })

        let approve = settled(seq: 13, round: 2, verdict: verdict(.approve))
        let approvedButNotCompleted = CodeProjection.build(
            from: beforeApproval + [approve],
            presentationPolicy: .mandatoryTaskReview)
        XCTAssertTrue(approvedButNotCompleted.items.filter { $0.kind == .agent }.isEmpty)

        let completion = envelope(14, .taskCompleted(TaskCompletedPayload(
            taskID: rootTaskID,
            agent: main,
            result: "final revised answer",
            attempt: 1)))
        let replayed = CodeProjection.build(
            from: beforeApproval + [approve, completion, completion],
            presentationPolicy: .mandatoryTaskReview)
        let delivered = replayed.items.filter { $0.kind == .agent }
        XCTAssertEqual(delivered.count, 1)
        XCTAssertEqual(delivered.first?.id, rootTaskID.rawValue + ":completed")
        XCTAssertEqual(delivered.first?.body, "final revised answer")
    }

    func testMandatoryReviewReplayNeverDeliversInvalidExhaustedOrFailedDraft() {
        let messageID = MessageID(rawValue: "msg_failed_draft")
        let events = [
            envelope(0, .userMessage(UserMessagePayload(
                text: "public request",
                to: main,
                presentation: .userVisible))),
            envelope(1, .userMessage(UserMessagePayload(
                text: "internal review input contains unapproved draft",
                to: judge,
                presentation: .internalContext))),
            envelope(2, .messageDelta(MessageDeltaPayload(
                messageId: messageID,
                role: .agent,
                agent: main,
                textDelta: "unapproved draft"))),
            envelope(3, .messageCompleted(MessageCompletedPayload(
                messageId: messageID,
                role: .agent,
                agent: main,
                text: "unapproved draft"))),
            settled(seq: 4, round: 1, error: "invalid judge JSON"),
            envelope(5, .taskReviewExhausted(TaskReviewExhaustedPayload(
                rootTaskID: rootTaskID,
                reviewer: judge,
                rounds: 1,
                rootAttempt: 1,
                reason: "invalid judge JSON",
                disposition: "fail"))),
            envelope(6, .taskFailed(TaskFailedPayload(
                taskID: rootTaskID,
                agent: main,
                error: "review failed closed",
                attempt: 1))),
            // Even a corrupt/stale completion after exhaustion must not publish.
            envelope(7, .taskCompleted(TaskCompletedPayload(
                taskID: rootTaskID,
                agent: main,
                result: "unapproved draft",
                attempt: 1))),
        ]

        let projection = CodeProjection.build(
            from: events,
            presentationPolicy: .mandatoryTaskReview)
        XCTAssertTrue(projection.items.filter { $0.kind == .agent }.isEmpty)
        XCTAssertFalse(projection.items.contains { $0.body.contains("unapproved draft") })
        XCTAssertEqual(projection.items.filter { $0.kind == .user }.map(\.body), ["public request"])
    }

    func testStandardProjectionRetainsLegacyChatAndCodeMessageBehavior() {
        let messageID = MessageID(rawValue: "msg_legacy")
        let projection = CodeProjection.build(from: [
            envelope(0, .userMessage(UserMessagePayload(text: "legacy input"))),
            envelope(1, .messageDelta(MessageDeltaPayload(
                messageId: messageID,
                role: .agent,
                agent: main,
                textDelta: "legacy "))),
            envelope(2, .messageCompleted(MessageCompletedPayload(
                messageId: messageID,
                role: .agent,
                agent: main,
                text: "legacy answer"))),
        ])

        XCTAssertEqual(projection.items.filter { $0.kind == .user }.map(\.body), ["legacy input"])
        XCTAssertEqual(projection.items.filter { $0.kind == .agent }.map(\.body), ["legacy answer"])
    }

    func testMandatoryReviewFailsClosedForOrphanToolResult() {
        var gate = MandatoryReviewPresentationGate()
        let decision = gate.apply(envelope(0, .toolResult(ToolResultPayload(
            toolCallId: "missing-call",
            observation: "unclassified content must not surface"))))
        XCTAssertEqual(decision, .hide)
    }

    func testMandatoryReviewFailsClosedForUnknownToolAndDuplicateCallID() {
        var gate = MandatoryReviewPresentationGate()

        XCTAssertEqual(gate.apply(envelope(0, .toolCall(ToolCallPayload(
            toolCallId: "unknown",
            agent: main,
            name: "invented_tool",
            args: #"{"content":"draft"}"#)))), .hide)
        XCTAssertEqual(gate.apply(envelope(1, .toolResult(ToolResultPayload(
            toolCallId: "unknown",
            observation: "draft")))), .hide)

        XCTAssertEqual(gate.apply(envelope(2, .toolCall(ToolCallPayload(
            toolCallId: "collision",
            agent: main,
            name: "send_message",
            args: #"{"content":"private"}"#)))), .hide)
        XCTAssertEqual(gate.apply(envelope(3, .toolCall(ToolCallPayload(
            toolCallId: "collision",
            agent: main,
            name: "read_file",
            args: #"{"path":"README.md"}"#)))), .hide)
        XCTAssertEqual(gate.apply(envelope(4, .toolResult(ToolResultPayload(
            toolCallId: "collision",
            observation: "private")))), .hide)
    }
}
