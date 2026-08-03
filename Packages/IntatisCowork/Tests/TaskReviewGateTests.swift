import XCTest
import Foundation
import IntatisCore
import IntatisProtocol
import IntatisProviders
import IntatisPermission
import IntatisConversation
import IntatisAgentKernel
@testable import IntatisCowork

private final class TaskReviewScriptedProvider: ToolCallingProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [String]
    private var capturedRequests: [AgentRequest] = []

    init(_ responses: [String]) {
        self.responses = responses
    }

    var requests: [AgentRequest] {
        lock.lock()
        defer { lock.unlock() }
        return capturedRequests
    }

    func stream(_ request: AgentRequest) -> AsyncThrowingStream<AgentChunk, Error> {
        lock.lock()
        capturedRequests.append(request)
        let response = responses.isEmpty ? "" : responses.removeFirst()
        lock.unlock()
        return AsyncThrowingStream { continuation in
            if !response.isEmpty { continuation.yield(.textDelta(response)) }
            continuation.yield(.done(finishReason: "stop"))
            continuation.finish()
        }
    }
}

private final class TaskReviewChunkProvider: ToolCallingProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [[AgentChunk]]
    private var capturedRequests: [AgentRequest] = []

    init(_ responses: [[AgentChunk]]) {
        self.responses = responses
    }

    var requests: [AgentRequest] {
        lock.lock()
        defer { lock.unlock() }
        return capturedRequests
    }

    func stream(_ request: AgentRequest) -> AsyncThrowingStream<AgentChunk, Error> {
        lock.lock()
        capturedRequests.append(request)
        let response = responses.isEmpty
            ? [.done(finishReason: "stop")]
            : responses.removeFirst()
        lock.unlock()
        return AsyncThrowingStream { continuation in
            for chunk in response { continuation.yield(chunk) }
            continuation.finish()
        }
    }
}

private struct TaskReviewVerdictRewriter: ForwardingReviewer {
    let replacement: String

    func review(from: AgentID, to: AgentID, content: String) async -> ForwardingDecision {
        if from == Orchestrator.taskReviewerID, to == Orchestrator.mainAgentID {
            return .forward(replacement)
        }
        return .forward(content)
    }
}

private func taskReviewDelegateArguments(to: String, objective: String) -> String {
    String(decoding: try! JSONSerialization.data(withJSONObject: [
        "to": to,
        "objective": objective,
        "expectedDeliverable": "Report changed files and validation results.",
    ]), as: UTF8.self)
}

private enum TaskReviewTestError: Error {
    case persistenceFailure
}

final class TaskReviewGateTests: XCTestCase {
    private func makeLog() throws -> EventLog {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("councis-task-review-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("events.jsonl")
        return try EventLog(session: SessionID.new(), fileURL: url)
    }

    private func makeWorkspace() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("councis-task-review-ws-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeOrchestrator(log: EventLog,
                                  mainProvider: TaskReviewScriptedProvider,
                                  judgeProvider: TaskReviewScriptedProvider,
                                  policy: CoworkTaskReviewPolicy = .always,
                                  mediator: Mediator = Mediator()) -> Orchestrator {
        Orchestrator(
            log: log,
            mediator: mediator,
            allowsShell: true,
            responder: FixedResponder(.allow),
            executionPolicy: CoworkExecutionPolicy(maxConcurrentTasks: 2),
            taskReviewPolicy: policy
        ) { agent in
            agent.name == Orchestrator.taskReviewerID ? judgeProvider : mainProvider
        }
    }

    private func attachMainAndJudge(_ orchestrator: Orchestrator,
                                    workspace: URL) async -> (Bool, Bool) {
        let main = await orchestrator.attach(Agent(
            name: Orchestrator.mainAgentID,
            workspaceRoot: workspace,
            modelBinding: AgentModelBinding(providerID: "main-provider", modelID: ModelID(rawValue: "main-model")),
            profile: .reviewed,
            coordinationDepth: Agent.defaultCoordinationDepth))
        let judge = await orchestrator.attachTaskReviewer(Agent(
            name: Orchestrator.taskReviewerID,
            workspaceRoot: workspace,
            modelBinding: AgentModelBinding(providerID: "judge-provider", modelID: ModelID(rawValue: "judge-model")),
            profile: .reviewed,
            coordinationDepth: Agent.defaultCoordinationDepth))
        return (main, judge)
    }

    func testApproveIsSettledBeforeRootCompletionAndReturnedBySubmit() async throws {
        let log = try makeLog()
        let workspace = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let mainProvider = TaskReviewScriptedProvider(["draft answer"])
        let judgeProvider = TaskReviewScriptedProvider([
            #"{"decision":"approve","summary":"Meets the objective.","findings":[],"requiredRevisions":[]}"#,
        ])
        let orchestrator = makeOrchestrator(
            log: log,
            mainProvider: mainProvider,
            judgeProvider: judgeProvider)
        let attached = await attachMainAndJudge(orchestrator, workspace: workspace)
        XCTAssertTrue(attached.0)
        XCTAssertTrue(attached.1)

        let result = await orchestrator.submit("Produce a reviewed answer.")

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.result, "draft answer")
        XCTAssertEqual(result.reviewVerdict?.decision, .approve)
        let rootTaskID = try XCTUnwrap(result.taskID)
        let events = await log.replay()
        let settledSequence = try XCTUnwrap(events.first {
            if case .taskReviewSettled(let payload) = $0.event {
                return payload.rootTaskID == rootTaskID && payload.verdict?.decision == .approve
            }
            return false
        }?.seq)
        let completionSequence = try XCTUnwrap(events.first {
            if case .taskCompleted(let payload) = $0.event { return payload.taskID == rootTaskID }
            return false
        }?.seq)
        XCTAssertLessThan(settledSequence, completionSequence)

        let reviewTask = try XCTUnwrap(events.compactMap { envelope -> TaskContract? in
            guard case .taskCreated(let payload) = envelope.event,
                  payload.contract.kind == .review else { return nil }
            return payload.contract
        }.first)
        XCTAssertEqual(reviewTask.parentTaskID, rootTaskID)
        XCTAssertEqual(reviewTask.assignee, Orchestrator.taskReviewerID)
        XCTAssertEqual(reviewTask.replyMode, .answer)

        let reviewLease = try XCTUnwrap(events.compactMap { envelope -> CapabilityLease? in
            guard case .capabilityLeaseCreated(let payload) = envelope.event,
                  payload.agent == Orchestrator.taskReviewerID,
                  payload.lease.taskID == reviewTask.id else { return nil }
            return payload.lease
        }.first)
        if case .none = reviewLease.communication {
            // Contract-directed reply does not grant arbitrary communication.
        } else {
            XCTFail("Judge review lease must retain communication:none")
        }
    }

    func testVerdictIsDecodedFromMediatedScheduledReplyNotSchedulerRecord() async throws {
        let log = try makeLog()
        let workspace = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let rawApprove = #"{"decision":"approve","summary":"Raw executor output.","findings":[],"requiredRevisions":[]}"#
        let mediatedRevise = #"{"decision":"revise","summary":"Mediated review requires proof.","findings":["Missing proof."],"requiredRevisions":["Add proof."]}"#
        let mainProvider = TaskReviewScriptedProvider(["draft"])
        let judgeProvider = TaskReviewScriptedProvider([rawApprove])
        let orchestrator = makeOrchestrator(
            log: log,
            mainProvider: mainProvider,
            judgeProvider: judgeProvider,
            policy: CoworkTaskReviewPolicy(maxRounds: 1),
            mediator: Mediator(reviewer: TaskReviewVerdictRewriter(replacement: mediatedRevise)))
        let attached = await attachMainAndJudge(orchestrator, workspace: workspace)
        XCTAssertTrue(attached.0 && attached.1)

        let result = await orchestrator.submit("Use only the mediated verdict.")

        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.reviewVerdict?.decision, .revise)
        let events = await log.replay()
        XCTAssertTrue(events.contains {
            guard case .agentToAgentMessage(let payload) = $0.event else { return false }
            return payload.from == Orchestrator.taskReviewerID
                && payload.to == Orchestrator.mainAgentID
                && payload.content == mediatedRevise
                && payload.mediated
        })
        XCTAssertTrue(events.contains {
            guard case .taskReviewSettled(let payload) = $0.event else { return false }
            return payload.verdict?.decision == .revise
        })
    }

    func testReviseRunsMainAgainAndReviewRoundsRemainBounded() async throws {
        let log = try makeLog()
        let workspace = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let mainProvider = TaskReviewScriptedProvider(["draft one", "draft two"])
        let judgeProvider = TaskReviewScriptedProvider([
            #"{"decision":"revise","summary":"Evidence is missing.","findings":["No validation result."],"requiredRevisions":["Add validation result."]}"#,
            #"{"decision":"approve","summary":"Revision is adequate.","findings":[],"requiredRevisions":[]}"#,
        ])
        let orchestrator = makeOrchestrator(
            log: log,
            mainProvider: mainProvider,
            judgeProvider: judgeProvider,
            policy: CoworkTaskReviewPolicy(maxRounds: 2))
        let attached = await attachMainAndJudge(orchestrator, workspace: workspace)
        XCTAssertTrue(attached.0 && attached.1)

        let result = await orchestrator.submit("Revise when required.")

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.result, "draft two")
        XCTAssertEqual(result.reviewVerdict?.decision, .approve)
        XCTAssertEqual(mainProvider.requests.count, 2)
        XCTAssertEqual(judgeProvider.requests.count, 2)
        let settled = await log.replay().filter {
            if case .taskReviewSettled = $0.event { return true }
            return false
        }
        XCTAssertEqual(settled.count, 2)
    }

    func testMandatoryPresentationPublishesOnlyFinalRevisionAfterMediatedApproval() async throws {
        let log = try makeLog()
        let workspace = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let mainProvider = TaskReviewScriptedProvider(["private first draft", "approved final revision"])
        let rawRevise = #"{"decision":"revise","summary":"Needs revision.","findings":["Incomplete."],"requiredRevisions":["Replace it."]}"#
        let rawApprove = #"{"decision":"approve","summary":"Approved final revision.","findings":[],"requiredRevisions":[]}"#
        let judgeProvider = TaskReviewScriptedProvider([rawRevise, rawApprove])
        let orchestrator = makeOrchestrator(
            log: log,
            mainProvider: mainProvider,
            judgeProvider: judgeProvider,
            policy: CoworkTaskReviewPolicy(maxRounds: 2))
        let attached = await attachMainAndJudge(orchestrator, workspace: workspace)
        XCTAssertTrue(attached.0 && attached.1)

        let result = await orchestrator.submit("public root request")

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.result, "approved final revision")
        let events = await log.replay()

        // Raw execution evidence remains durable for context/audit. The strict
        // presentation projection, not the storage layer, is the release gate.
        let rawCompletedTexts = events.compactMap { envelope -> String? in
            guard case .messageCompleted(let payload) = envelope.event else { return nil }
            return payload.text
        }
        XCTAssertTrue(rawCompletedTexts.contains("private first draft"))
        XCTAssertTrue(rawCompletedTexts.contains("approved final revision"))
        XCTAssertTrue(rawCompletedTexts.contains(rawRevise))
        XCTAssertTrue(rawCompletedTexts.contains(rawApprove))

        // Only the original root input is persisted as public input. Worker,
        // revision, and Judge inputs do not become replayable user messages.
        let userMessages = events.compactMap { envelope -> UserMessagePayload? in
            guard case .userMessage(let payload) = envelope.event else { return nil }
            return payload
        }
        XCTAssertEqual(userMessages.count, 1)
        XCTAssertEqual(userMessages.first?.text, "public root request")
        XCTAssertEqual(userMessages.first?.presentation, .userVisible)

        let projection = CodeProjection.build(
            from: events,
            presentationPolicy: .mandatoryTaskReview)
        let visibleAgentItems = projection.items.filter { $0.kind == .agent }
        XCTAssertEqual(visibleAgentItems.count, 1)
        XCTAssertEqual(visibleAgentItems.first?.body, "approved final revision")
        XCTAssertFalse(projection.items.contains { $0.body.contains("private first draft") })
        XCTAssertFalse(projection.items.contains { $0.body.contains(rawRevise) })
        XCTAssertFalse(projection.items.contains { $0.body.contains(rawApprove) })
    }

    func testInvalidVerdictsExhaustWithoutImplicitApproval() async throws {
        let log = try makeLog()
        let workspace = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let mainProvider = TaskReviewScriptedProvider(["unapproved draft"])
        let judgeProvider = TaskReviewScriptedProvider(["not json", "still not json"])
        let orchestrator = makeOrchestrator(
            log: log,
            mainProvider: mainProvider,
            judgeProvider: judgeProvider,
            policy: CoworkTaskReviewPolicy(maxRounds: 2, exhaustionDisposition: .deliverWithWarnings))
        let attached = await attachMainAndJudge(orchestrator, workspace: workspace)
        XCTAssertTrue(attached.0 && attached.1)

        let result = await orchestrator.submit("Do not infer approval.")

        XCTAssertTrue(result.succeeded)
        XCTAssertNil(result.reviewVerdict)
        XCTAssertTrue(result.result?.contains("Review warning: no approving verdict after 2 round(s).") == true)
        XCTAssertEqual(mainProvider.requests.count, 1)
        XCTAssertEqual(judgeProvider.requests.count, 2)
        let events = await log.replay()
        let settled = events.compactMap { envelope -> TaskReviewSettledPayload? in
            if case .taskReviewSettled(let payload) = envelope.event { return payload }
            return nil
        }
        XCTAssertEqual(settled.count, 2)
        XCTAssertTrue(settled.allSatisfy { $0.verdict == nil && $0.error != nil })
        XCTAssertTrue(events.contains { if case .taskReviewExhausted = $0.event { return true }; return false })
    }

    func testJudgeIsReservedAndReceivesTrustedReadOnlyNonCoordinatorContext() async throws {
        let log = try makeLog()
        let workspace = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let mainProvider = TaskReviewScriptedProvider(["draft"])
        let judgeProvider = TaskReviewScriptedProvider([
            #"{"decision":"approve","summary":"Approved.","findings":[],"requiredRevisions":[]}"#,
        ])
        let orchestrator = makeOrchestrator(
            log: log,
            mainProvider: mainProvider,
            judgeProvider: judgeProvider)

        let ordinaryAttach = await orchestrator.attach(Agent(
            name: Orchestrator.taskReviewerID,
            workspaceRoot: workspace,
            modelBinding: AgentModelBinding(providerID: "wrong-provider", modelID: ModelID(rawValue: "wrong"))))
        XCTAssertFalse(ordinaryAttach)
        let attached = await attachMainAndJudge(orchestrator, workspace: workspace)
        XCTAssertTrue(attached.0 && attached.1)
        let directSend = await orchestrator.send("bypass", to: Orchestrator.taskReviewerID)
        if case .failed(let message) = directSend {
            XCTAssertTrue(message.contains("reserved"))
        } else {
            XCTFail("direct Judge send must fail")
        }

        let result = await orchestrator.submit("Inspect the reviewer context.")
        XCTAssertTrue(result.succeeded)
        let request = try XCTUnwrap(judgeProvider.requests.first)
        XCTAssertTrue(request.messages.first?.content?.contains("independent task quality reviewer") == true)
        let names = Set(request.tools.map(\.name))
        XCTAssertEqual(names, ["read_file", "list_files", "search_text", "read_pdf"])
        XCTAssertFalse(names.contains("write_file"))
        XCTAssertFalse(names.contains("delegate_task"))
        XCTAssertFalse(names.contains("spawn_agent"))
        XCTAssertFalse(names.contains("web_fetch"))
    }

    func testReviewInputContainsScopedStructuredWorkerDiffAndTestEvidence() async throws {
        let log = try makeLog()
        let workspace = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let workerID = AgentID(rawValue: "worker")
        let mainProvider = TaskReviewChunkProvider([
            [
                .toolCalls([ToolCall(
                    id: "delegate",
                    name: "delegate_task",
                    arguments: taskReviewDelegateArguments(
                        to: workerID.rawValue,
                        objective: "Inspect the implementation diff and run tests."))]),
                .done(finishReason: "tool_calls"),
            ],
            [.textDelta("Final draft cites the worker validation."), .done(finishReason: "stop")],
        ])
        let workerProvider = TaskReviewChunkProvider([
            [
                .textDelta("Changed file Packages/Feature.swift via patch.\nSwift test passed (12 tests)."),
                .done(finishReason: "stop"),
            ],
        ])
        let judgeProvider = TaskReviewChunkProvider([
            [
                .textDelta(#"{"decision":"approve","summary":"Evidence is structured and adequate.","findings":[],"requiredRevisions":[]}"#),
                .done(finishReason: "stop"),
            ],
        ])
        let orchestrator = Orchestrator(
            log: log,
            allowsShell: true,
            responder: FixedResponder(.allow),
            executionPolicy: CoworkExecutionPolicy(maxConcurrentTasks: 2),
            taskReviewPolicy: .always
        ) { agent in
            switch agent.name {
            case Orchestrator.taskReviewerID: return judgeProvider
            case workerID: return workerProvider
            default: return mainProvider
            }
        }
        let mainAttached = await orchestrator.attach(Agent(
            name: Orchestrator.mainAgentID,
            workspaceRoot: workspace,
            modelBinding: AgentModelBinding(providerID: "main-provider", modelID: ModelID(rawValue: "main-model")),
            profile: .reviewed,
            coordinationDepth: Agent.defaultCoordinationDepth))
        let workerAttached = await orchestrator.attach(Agent(
            name: workerID,
            workspaceRoot: workspace,
            modelBinding: AgentModelBinding(providerID: "worker-provider", modelID: ModelID(rawValue: "worker-model")),
            profile: .reviewed))
        let judgeAttached = await orchestrator.attachTaskReviewer(Agent(
            name: Orchestrator.taskReviewerID,
            workspaceRoot: workspace,
            modelBinding: AgentModelBinding(providerID: "judge-provider", modelID: ModelID(rawValue: "judge-model")),
            profile: .reviewed))
        XCTAssertTrue(mainAttached && workerAttached && judgeAttached)

        let result = await orchestrator.submit("Delegate validation, then produce a reviewed answer.")

        XCTAssertTrue(result.succeeded)
        let request = try XCTUnwrap(judgeProvider.requests.first)
        let evidenceInput = try XCTUnwrap(request.messages.compactMap(\.content).last {
            $0.contains("<<<TASK_REVIEW_EVIDENCE_JSON>>>")
        })
        XCTAssertFalse(SecretScanner.containsSecret(evidenceInput))
        let start = try XCTUnwrap(evidenceInput.range(of: "<<<TASK_REVIEW_EVIDENCE_JSON>>>\n"))
        let end = try XCTUnwrap(evidenceInput.range(of: "\n<<<END_TASK_REVIEW_EVIDENCE_JSON>>>"))
        let json = String(evidenceInput[start.upperBound..<end.lowerBound])
        let object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        XCTAssertEqual(object["schema"] as? String, "councis.task_review_evidence.v1")
        let rootReport = try XCTUnwrap(object["rootTaskReport"] as? [String: Any])
        XCTAssertEqual(rootReport["detail"] as? String, "Final draft cites the worker validation.")
        let workerReports = try XCTUnwrap(object["workerTaskReports"] as? [[String: Any]])
        XCTAssertEqual(workerReports.first?["agent"] as? String, workerID.rawValue)
        XCTAssertTrue((workerReports.first?["summary"] as? String)?.contains("Changed file") == true)
        XCTAssertFalse((object["diffEvidence"] as? [[String: Any]] ?? []).isEmpty)
        XCTAssertFalse((object["testEvidence"] as? [[String: Any]] ?? []).isEmpty)
    }

    func testAlwaysPolicyFailsClosedWithoutAValidApproval() async throws {
        XCTAssertEqual(CoworkTaskReviewPolicy.always.exhaustionDisposition, .fail)
        let log = try makeLog()
        let workspace = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let mainProvider = TaskReviewScriptedProvider(["unapproved draft"])
        let judgeProvider = TaskReviewScriptedProvider(["not json", "still not json"])
        let orchestrator = makeOrchestrator(
            log: log,
            mainProvider: mainProvider,
            judgeProvider: judgeProvider,
            policy: .always)
        let attached = await attachMainAndJudge(orchestrator, workspace: workspace)
        XCTAssertTrue(attached.0 && attached.1)

        let result = await orchestrator.submit("A valid approval is mandatory.")

        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.status, .failed)
        XCTAssertNil(result.reviewVerdict)
        let rootTaskID = try XCTUnwrap(result.taskID)
        let events = await log.replay()
        XCTAssertFalse(events.contains {
            if case .taskCompleted(let payload) = $0.event { return payload.taskID == rootTaskID }
            return false
        })
        XCTAssertTrue(events.contains {
            guard case .taskReviewExhausted(let payload) = $0.event else { return false }
            return payload.rootTaskID == rootTaskID && payload.disposition == "fail"
        })
        let presentation = CodeProjection.build(
            from: events,
            presentationPolicy: .mandatoryTaskReview)
        XCTAssertTrue(presentation.items.filter { $0.kind == .agent }.isEmpty)
        XCTAssertFalse(presentation.items.contains { $0.body.contains("unapproved draft") })
    }

    func testFailDispositionNeverCompletesRootWithoutApproval() async throws {
        let log = try makeLog()
        let workspace = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let mainProvider = TaskReviewScriptedProvider(["draft"])
        let judgeProvider = TaskReviewScriptedProvider([
            #"{"decision":"revise","summary":"Still incomplete.","findings":["Missing proof."],"requiredRevisions":["Add proof."]}"#,
        ])
        let orchestrator = makeOrchestrator(
            log: log,
            mainProvider: mainProvider,
            judgeProvider: judgeProvider,
            policy: CoworkTaskReviewPolicy(maxRounds: 1, exhaustionDisposition: .fail))
        let attached = await attachMainAndJudge(orchestrator, workspace: workspace)
        XCTAssertTrue(attached.0 && attached.1)

        let result = await orchestrator.submit("Require explicit approval.")

        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.reviewVerdict?.decision, .revise)
        XCTAssertFalse(result.error?.contains("Still incomplete.") == true)
        XCTAssertEqual(result.error, "Task review exhausted 1 round(s) without approval.")
        let rootTaskID = try XCTUnwrap(result.taskID)
        let events = await log.replay()
        XCTAssertFalse(events.contains {
            if case .taskCompleted(let payload) = $0.event { return payload.taskID == rootTaskID }
            return false
        })
        let exhaustedSequence = try XCTUnwrap(events.first {
            if case .taskReviewExhausted(let payload) = $0.event { return payload.rootTaskID == rootTaskID }
            return false
        }?.seq)
        let failedSequence = try XCTUnwrap(events.first {
            if case .taskFailed(let payload) = $0.event { return payload.taskID == rootTaskID }
            return false
        }?.seq)
        XCTAssertLessThan(exhaustedSequence, failedSequence)
        let presentation = CodeProjection.build(
            from: events,
            presentationPolicy: .mandatoryTaskReview)
        XCTAssertFalse(presentation.items.contains { $0.body.contains("Still incomplete.") })
    }

    func testReviewSettlementPersistenceFailurePreventsRootCompletion() async throws {
        let log = try makeLog()
        let workspace = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let mainProvider = TaskReviewScriptedProvider(["draft"])
        let judgeProvider = TaskReviewScriptedProvider([
            #"{"decision":"approve","summary":"Approved.","findings":[],"requiredRevisions":[]}"#,
        ])
        let orchestrator = makeOrchestrator(
            log: log,
            mainProvider: mainProvider,
            judgeProvider: judgeProvider)
        let attached = await attachMainAndJudge(orchestrator, workspace: workspace)
        XCTAssertTrue(attached.0 && attached.1)
        await orchestrator.setTaskLifecycleEventAppender { event in
            if case .taskReviewSettled = event { throw TaskReviewTestError.persistenceFailure }
            try await log.append(event)
        }

        let result = await orchestrator.submit("Settlement must be durable.")

        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.status, .failed)
        let rootTaskID = try XCTUnwrap(result.taskID)
        let events = await log.replay()
        XCTAssertFalse(events.contains {
            if case .taskReviewSettled(let payload) = $0.event { return payload.rootTaskID == rootTaskID }
            return false
        })
        XCTAssertFalse(events.contains {
            if case .taskCompleted(let payload) = $0.event { return payload.taskID == rootTaskID }
            return false
        })
        XCTAssertTrue(events.contains {
            if case .taskFailed(let payload) = $0.event { return payload.taskID == rootTaskID }
            return false
        })
    }

    func testRuntimeRejectsAlwaysReviewWithOneSchedulerSlot() throws {
        let log = try makeLog()

        XCTAssertThrowsError(try Orchestrator.runtime(
            log: log,
            allowsShell: true,
            responder: FixedResponder(.allow),
            executionPolicy: CoworkExecutionPolicy(maxConcurrentTasks: 1),
            taskReviewPolicy: .always
        ) { _ in TaskReviewScriptedProvider(["unused"]) }) { error in
            XCTAssertEqual(
                error as? CoworkTaskReviewConfigurationError,
                .insufficientSchedulerConcurrency(required: 2, configured: 1))
        }
    }
}
