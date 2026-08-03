import XCTest
import IntatisCore
@testable import IntatisProtocol

final class TaskReviewProtocolTests: XCTestCase {
    func testReviewEventsRoundTripThroughEnvelope() throws {
        let verdict = TaskReviewVerdict(
            decision: .revise,
            summary: "One issue remains.",
            findings: ["Missing validation."],
            requiredRevisions: ["Add validation evidence."])
        let payload = TaskReviewSettledPayload(
            reviewID: TaskReviewID(rawValue: "review_1"),
            rootTaskID: TaskID(rawValue: "task_root"),
            reviewTaskID: TaskID(rawValue: "task_review"),
            reviewer: AgentID(rawValue: "judge"),
            round: 1,
            rootAttempt: 2,
            verdict: verdict)
        let envelope = Envelope(
            seq: 9,
            ts: Date(timeIntervalSince1970: 9),
            session: SessionID(rawValue: "sess_review"),
            event: .taskReviewSettled(payload))

        let data = try Envelope.makeEncoder().encode(envelope)
        let decoded = try Envelope.makeDecoder().decode(Envelope.self, from: data)

        XCTAssertEqual(decoded, envelope)
        XCTAssertEqual(decoded.event.type, .taskReviewSettled)
    }

    func testTaskReviewerLeaseHasNoWriteNetworkCommunicationOrDelegation() {
        let lease = CapabilityLease.taskReviewer(taskID: TaskID(rawValue: "task_review"))

        XCTAssertEqual(lease.taskID, TaskID(rawValue: "task_review"))
        XCTAssertEqual(lease.tools, [.readWorkspace, .listWorkspace, .searchWorkspace, .readPDF])
        XCTAssertEqual(lease.communication, .none)
        XCTAssertEqual(lease.delegation, .none)
        XCTAssertTrue(lease.expiresAtTaskCompletion)
    }
}
