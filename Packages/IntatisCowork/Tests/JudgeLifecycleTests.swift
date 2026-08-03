import XCTest
import Foundation
import IntatisCore
import IntatisProtocol
import IntatisProviders
import IntatisPermission
import IntatisConversation
import IntatisAgentKernel
@testable import IntatisCowork

private final class JudgeLifecycleScriptedProvider: ToolCallingProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [String]
    private var capturedRequestCount = 0

    init(_ responses: [String]) {
        self.responses = responses
    }

    var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return capturedRequestCount
    }

    func stream(_ request: AgentRequest) -> AsyncThrowingStream<AgentChunk, Error> {
        lock.lock()
        capturedRequestCount += 1
        let response = responses.isEmpty ? "" : responses.removeFirst()
        lock.unlock()
        return AsyncThrowingStream { continuation in
            if !response.isEmpty {
                continuation.yield(.textDelta(response))
            }
            continuation.yield(.done(finishReason: "stop"))
            continuation.finish()
        }
    }
}

/// Keeps the producer side alive after the consumer is cancelled. This models
/// a remote provider for which cancellation acknowledgement cannot be proven.
private final class JudgeLifecycleHangingProvider: ToolCallingProvider, @unchecked Sendable {
    private typealias StreamContinuation = AsyncThrowingStream<AgentChunk, Error>.Continuation

    private let lock = NSLock()
    private var capturedRequestCount = 0
    private var continuations: [StreamContinuation] = []

    var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return capturedRequestCount
    }

    func stream(_ request: AgentRequest) -> AsyncThrowingStream<AgentChunk, Error> {
        AsyncThrowingStream { continuation in
            lock.lock()
            capturedRequestCount += 1
            continuations.append(continuation)
            lock.unlock()
        }
    }

    func finishAll() {
        lock.lock()
        let retained = continuations
        continuations.removeAll()
        lock.unlock()
        for continuation in retained {
            continuation.finish()
        }
    }

    func waitUntilRequestCount(
        _ expected: Int,
        attempts: Int = 100,
        intervalNanoseconds: UInt64 = 2_000_000
    ) async -> Bool {
        for _ in 0..<attempts {
            if requestCount >= expected {
                return true
            }
            try? await Task.sleep(nanoseconds: intervalNanoseconds)
        }
        return requestCount >= expected
    }
}

private actor JudgeLifecycleLateApprovalGate {
    private var released = false
    private var emitted = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !released else { return }
        await withCheckedContinuation { continuation in
            if released {
                continuation.resume()
            } else {
                waiters.append(continuation)
            }
        }
    }

    func release() {
        guard !released else { return }
        released = true
        let pending = waiters
        waiters.removeAll()
        for waiter in pending {
            waiter.resume()
        }
    }

    func markEmitted() {
        emitted = true
    }

    func approvalWasEmitted() -> Bool {
        emitted
    }
}

/// Its producer deliberately outlives stream-consumer cancellation, then emits
/// a syntactically valid approval only after the test opens the second phase.
private final class JudgeLifecycleLateApprovalProvider: ToolCallingProvider, @unchecked Sendable {
    private let lock = NSLock()
    private let gate = JudgeLifecycleLateApprovalGate()
    private var capturedRequestCount = 0

    var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return capturedRequestCount
    }

    func stream(_ request: AgentRequest) -> AsyncThrowingStream<AgentChunk, Error> {
        lock.lock()
        capturedRequestCount += 1
        lock.unlock()
        return AsyncThrowingStream { continuation in
            let gate = self.gate
            _ = Task.detached {
                await gate.wait()
                continuation.yield(.textDelta(
                    #"{"decision":"approve","summary":"late approval must lose","findings":[],"requiredRevisions":[]}"#))
                continuation.yield(.done(finishReason: "stop"))
                continuation.finish()
                await gate.markEmitted()
            }
            continuation.onTermination = { _ in
                // Intentionally do not cancel the detached producer. This is
                // the uncooperative provider behavior the shutdown barrier
                // must survive.
            }
        }
    }

    func releaseApproval() async {
        await gate.release()
    }

    func waitUntilRequestCount(
        _ expected: Int,
        attempts: Int = 100,
        intervalNanoseconds: UInt64 = 2_000_000
    ) async -> Bool {
        for _ in 0..<attempts {
            if requestCount >= expected {
                return true
            }
            try? await Task.sleep(nanoseconds: intervalNanoseconds)
        }
        return requestCount >= expected
    }

    func waitUntilApprovalEmitted(
        attempts: Int = 100,
        intervalNanoseconds: UInt64 = 2_000_000
    ) async -> Bool {
        for _ in 0..<attempts {
            if await gate.approvalWasEmitted() {
                return true
            }
            try? await Task.sleep(nanoseconds: intervalNanoseconds)
        }
        return await gate.approvalWasEmitted()
    }
}

private actor JudgeLifecycleTaskStartGate {
    private var entered = false
    private var releaseRequested = false
    private var enteredWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiter: CheckedContinuation<Void, Never>?

    func pause() async {
        entered = true
        let waiters = enteredWaiters
        enteredWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
        guard !releaseRequested else { return }
        await withCheckedContinuation { continuation in
            if releaseRequested {
                continuation.resume()
            } else {
                releaseWaiter = continuation
            }
        }
    }

    func waitUntilEntered() async {
        guard !entered else { return }
        await withCheckedContinuation { continuation in
            enteredWaiters.append(continuation)
        }
    }

    func release() {
        releaseRequested = true
        releaseWaiter?.resume()
        releaseWaiter = nil
    }
}

final class JudgeLifecycleTests: XCTestCase {
    private func makeLog() throws -> EventLog {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("councis-judge-lifecycle-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("events.jsonl")
        return try EventLog(session: SessionID.new(), fileURL: url)
    }

    private func makeWorkspace() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("councis-judge-lifecycle-ws-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeOrchestrator(
        log: EventLog,
        mainProvider: any ToolCallingProvider,
        judgeProvider: any ToolCallingProvider,
        policy: CoworkTaskReviewPolicy = .always
    ) -> Orchestrator {
        Orchestrator(
            log: log,
            allowsShell: true,
            responder: FixedResponder(.allow),
            executionPolicy: CoworkExecutionPolicy(maxConcurrentTasks: 2),
            taskReviewPolicy: policy
        ) { agent in
            agent.name == Orchestrator.taskReviewerID ? judgeProvider : mainProvider
        }
    }

    @discardableResult
    private func attachMainAndJudge(
        _ orchestrator: Orchestrator,
        workspace: URL
    ) async -> (main: Bool, judge: Bool) {
        let main = await orchestrator.attach(Agent(
            name: Orchestrator.mainAgentID,
            workspaceRoot: workspace,
            modelBinding: AgentModelBinding(
                providerID: "main-provider",
                modelID: ModelID(rawValue: "main-model")),
            profile: .reviewed,
            coordinationDepth: Agent.defaultCoordinationDepth))
        let judge = await orchestrator.attachTaskReviewer(Agent(
            name: Orchestrator.taskReviewerID,
            workspaceRoot: workspace,
            modelBinding: AgentModelBinding(
                providerID: "judge-provider",
                modelID: ModelID(rawValue: "judge-model")),
            profile: .reviewed,
            coordinationDepth: Agent.defaultCoordinationDepth))
        return (main, judge)
    }

    func testAttachedReservedJudgeReportsHealthy() async throws {
        let log = try makeLog()
        let workspace = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let provider = JudgeLifecycleScriptedProvider([])
        let orchestrator = makeOrchestrator(
            log: log,
            mainProvider: provider,
            judgeProvider: provider)

        let attached = await attachMainAndJudge(orchestrator, workspace: workspace)

        XCTAssertTrue(attached.main)
        XCTAssertTrue(attached.judge)
        let health = await orchestrator.taskReviewerHealth()
        XCTAssertEqual(health, .healthy)
    }

    func testRestoreSettlesOrphanedReviewAsInterruptedAndNeverReplaysOldReviewTask() async throws {
        let log = try makeLog()
        let workspace = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let provider = JudgeLifecycleScriptedProvider([
            #"{"decision":"approve","summary":"must not execute","findings":[],"requiredRevisions":[]}"#,
        ])
        let bootstrap = makeOrchestrator(
            log: log,
            mainProvider: provider,
            judgeProvider: provider)
        let attached = await attachMainAndJudge(bootstrap, workspace: workspace)
        XCTAssertTrue(attached.main && attached.judge)

        let rootTaskID = TaskID.new()
        let reviewTaskID = TaskID.new()
        let reviewID = TaskReviewID.new()
        let root = TaskContract(
            id: rootTaskID,
            kind: .root,
            issuer: nil,
            assignee: Orchestrator.mainAgentID,
            objective: "root interrupted while its Judge review was pending",
            roleHint: "root",
            expectedDeliverable: "reviewed result",
            replyMode: TaskReplyMode.none,
            maxAttempts: 1)
        let review = TaskContract(
            id: reviewTaskID,
            kind: .review,
            issuer: Orchestrator.mainAgentID,
            assignee: Orchestrator.taskReviewerID,
            parentTaskID: rootTaskID,
            objective: "orphaned review input",
            roleHint: "independent task quality reviewer",
            expectedDeliverable: "One strict TaskReviewVerdict JSON object.",
            relatedAgents: [Orchestrator.mainAgentID, Orchestrator.taskReviewerID],
            relatedTasks: [rootTaskID],
            replyMode: .answer,
            executionTimeoutSeconds: 30,
            maxAttempts: 1)
        try await log.append(.taskCreated(TaskCreatedPayload(contract: root)))
        try await log.append(.taskAssigned(TaskAssignedPayload(contract: root)))
        try await log.append(.taskQueued(TaskQueuedPayload(
            contract: root,
            rootTaskID: rootTaskID,
            assignee: Orchestrator.mainAgentID,
            hopCount: 0,
            visitedAgents: [Orchestrator.mainAgentID],
            attempt: 1)))
        try await log.append(.taskStarted(TaskStartedPayload(
            taskID: rootTaskID,
            agent: Orchestrator.mainAgentID,
            attempt: 1)))
        try await log.append(.taskCreated(TaskCreatedPayload(contract: review)))
        try await log.append(.taskAssigned(TaskAssignedPayload(contract: review)))
        try await log.append(.taskQueued(TaskQueuedPayload(
            contract: review,
            rootTaskID: rootTaskID,
            parentTaskID: rootTaskID,
            issuer: Orchestrator.mainAgentID,
            assignee: Orchestrator.taskReviewerID,
            causalParentID: rootTaskID,
            hopCount: 1,
            visitedAgents: [Orchestrator.mainAgentID, Orchestrator.taskReviewerID],
            attempt: 1)))
        try await log.append(.taskReviewRequested(TaskReviewRequestedPayload(
            reviewID: reviewID,
            rootTaskID: rootTaskID,
            reviewTaskID: reviewTaskID,
            reviewer: Orchestrator.taskReviewerID,
            round: 1,
            rootAttempt: 1,
            reviewInput: review.objective)))
        try await log.append(.taskCancelled(TaskCancelledPayload(
            taskID: rootTaskID,
            agent: Orchestrator.mainAgentID,
            reason: "host restarted",
            attempt: 1)))

        let restored = makeOrchestrator(
            log: log,
            mainProvider: provider,
            judgeProvider: provider)
        await restored.restore(from: CoworkProjection.build(from: await log.replay()))
        await restored.resumePendingTasks()
        await restored.runSchedulerUntilIdle()

        let events = await log.replay()
        let settlements = events.compactMap { envelope -> TaskReviewSettledPayload? in
            guard case .taskReviewSettled(let payload) = envelope.event,
                  payload.reviewID == reviewID else { return nil }
            return payload
        }
        XCTAssertEqual(settlements.count, 1)
        let settlement = try XCTUnwrap(settlements.first)
        XCTAssertEqual(settlement.rootTaskID, rootTaskID)
        XCTAssertEqual(settlement.reviewTaskID, reviewTaskID)
        XCTAssertNil(settlement.verdict)
        let recoveryError = settlement.error?.lowercased() ?? ""
        XCTAssertTrue(
            recoveryError.contains("interrupted") || recoveryError.contains("restart"),
            "unexpected orphan settlement error: \(recoveryError)")
        let projection = CoworkProjection.build(from: events)
        XCTAssertEqual(projection.tasks[reviewTaskID]?.status, .cancelled)
        XCTAssertEqual(provider.requestCount, 0)
    }

    func testJudgeProviderTimeoutQuarantinesLifecycleAndLaterRootFailsClosedWithoutAnotherDispatch() async throws {
        let log = try makeLog()
        let workspace = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let mainProvider = JudgeLifecycleScriptedProvider(["first draft", "second draft"])
        let judgeProvider = JudgeLifecycleHangingProvider()
        defer { judgeProvider.finishAll() }
        let orchestrator = makeOrchestrator(
            log: log,
            mainProvider: mainProvider,
            judgeProvider: judgeProvider,
            policy: CoworkTaskReviewPolicy(
                maxRounds: 1,
                reviewTimeoutSeconds: 0.04,
                exhaustionDisposition: .fail))
        let attached = await attachMainAndJudge(orchestrator, workspace: workspace)
        XCTAssertTrue(attached.main && attached.judge)

        let first = await orchestrator.submit("Trigger a Judge provider timeout.")

        XCTAssertFalse(first.succeeded)
        let health = await orchestrator.taskReviewerHealth()
        guard case .quarantined(let reason) = health else {
            return XCTFail("Judge must be quarantined after an unacknowledged provider timeout; got \(health)")
        }
        XCTAssertFalse(reason.isEmpty)
        XCTAssertEqual(judgeProvider.requestCount, 1)

        let second = await orchestrator.submit("This root must fail closed while Judge is quarantined.")

        XCTAssertFalse(second.succeeded)
        XCTAssertEqual(judgeProvider.requestCount, 1)
    }

    func testCancellingDispatchedJudgeTaskAlsoQuarantinesLifecycle() async throws {
        let log = try makeLog()
        let workspace = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let mainProvider = JudgeLifecycleScriptedProvider(["draft"])
        let judgeProvider = JudgeLifecycleHangingProvider()
        defer { judgeProvider.finishAll() }
        let orchestrator = makeOrchestrator(
            log: log,
            mainProvider: mainProvider,
            judgeProvider: judgeProvider,
            policy: CoworkTaskReviewPolicy(
                maxRounds: 1,
                reviewTimeoutSeconds: 0.5,
                exhaustionDisposition: .fail))
        let attached = await attachMainAndJudge(orchestrator, workspace: workspace)
        XCTAssertTrue(attached.main && attached.judge)

        let submission = Task {
            await orchestrator.submit("Cancel the dispatched Judge task.")
        }
        let judgeStarted = await judgeProvider.waitUntilRequestCount(1)
        XCTAssertTrue(judgeStarted)
        let events = await log.replay()
        let reviewTaskID = try XCTUnwrap(events.compactMap { envelope -> TaskID? in
            guard case .taskReviewRequested(let payload) = envelope.event else { return nil }
            return payload.reviewTaskID
        }.first)
        let cancelled = await orchestrator.cancel(
            taskID: reviewTaskID,
            reason: "test cancelled the dispatched Judge provider")
        let result = await submission.value

        XCTAssertTrue(cancelled)
        XCTAssertFalse(result.succeeded)
        let health = await orchestrator.taskReviewerHealth()
        guard case .quarantined(let reason) = health else {
            return XCTFail("Judge must be quarantined after dispatched review cancellation; got \(health)")
        }
        XCTAssertFalse(reason.isEmpty)
        XCTAssertEqual(judgeProvider.requestCount, 1)
    }

    func testReviewDeadlineIncludesTimeWaitingAtSchedulerStartGate() async throws {
        let log = try makeLog()
        let workspace = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let mainProvider = JudgeLifecycleScriptedProvider(["draft"])
        let judgeProvider = JudgeLifecycleScriptedProvider([
            #"{"decision":"approve","summary":"too late","findings":[],"requiredRevisions":[]}"#,
        ])
        let orchestrator = makeOrchestrator(
            log: log,
            mainProvider: mainProvider,
            judgeProvider: judgeProvider,
            policy: CoworkTaskReviewPolicy(
                maxRounds: 1,
                reviewTimeoutSeconds: 0.04,
                exhaustionDisposition: .fail))
        let attached = await attachMainAndJudge(orchestrator, workspace: workspace)
        XCTAssertTrue(attached.main && attached.judge)

        let gate = JudgeLifecycleTaskStartGate()
        await orchestrator.setTaskStartGate { taskID in
            let isReview = await log.replay().contains { envelope in
                guard case .taskCreated(let payload) = envelope.event else { return false }
                return payload.contract.id == taskID && payload.contract.kind == .review
            }
            if isReview {
                await gate.pause()
            }
        }

        let submission = Task {
            await orchestrator.submit("The review deadline must include queue waiting.")
        }
        await gate.waitUntilEntered()
        try await Task.sleep(nanoseconds: 120_000_000)
        await gate.release()
        let result = await submission.value

        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(judgeProvider.requestCount, 0)
        let replayed = await log.replay()
        let requested = try XCTUnwrap(replayed.compactMap { envelope -> TaskReviewRequestedPayload? in
            guard case .taskReviewRequested(let payload) = envelope.event else { return nil }
            return payload
        }.first)
        let createdAt = try XCTUnwrap(requested.createdAt)
        let deadline = try XCTUnwrap(requested.deadline)
        XCTAssertGreaterThanOrEqual(deadline, createdAt)
        let health = await orchestrator.taskReviewerHealth()
        if case .quarantined(let reason) = health {
            XCTFail("A pre-dispatch deadline must not quarantine the provider: \(reason)")
        }
        let timeoutDiagnostics = await log.replay().compactMap { envelope -> String? in
            switch envelope.event {
            case .taskReviewSettled(let payload):
                return payload.error
            case .taskCancelled(let payload):
                return payload.reason
            default:
                return nil
            }
        }.joined(separator: "\n").lowercased()
        XCTAssertTrue(
            timeoutDiagnostics.contains("deadline")
                || timeoutDiagnostics.contains("timed out")
                || timeoutDiagnostics.contains("timeout"),
            "missing durable end-to-end deadline diagnostic: \(timeoutDiagnostics)")
    }

    func testCancelAllKeepsShutdownBarrierAgainstLateUncooperativeApproval() async throws {
        let log = try makeLog()
        let workspace = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let mainProvider = JudgeLifecycleScriptedProvider(["private draft"])
        let judgeProvider = JudgeLifecycleLateApprovalProvider()
        let orchestrator = makeOrchestrator(
            log: log,
            mainProvider: mainProvider,
            judgeProvider: judgeProvider,
            policy: CoworkTaskReviewPolicy(
                maxRounds: 1,
                reviewTimeoutSeconds: 5,
                exhaustionDisposition: .fail))
        let attached = await attachMainAndJudge(orchestrator, workspace: workspace)
        XCTAssertTrue(attached.main && attached.judge)

        let submission = Task {
            await orchestrator.submit("A late approval must not cross shutdown.")
        }
        let judgeStarted = await judgeProvider.waitUntilRequestCount(1)
        XCTAssertTrue(judgeStarted)

        await orchestrator.cancelAll(reason: "test session shutdown")
        let healthAtBarrier = await orchestrator.taskReviewerHealth()
        XCTAssertNotEqual(healthAtBarrier, .healthy)

        // Phase two: the provider ignores cancellation and emits a valid
        // approval only after cancelAll has installed and drained its barrier.
        await judgeProvider.releaseApproval()
        let emitted = await judgeProvider.waitUntilApprovalEmitted()
        XCTAssertTrue(emitted)
        let result = await submission.value
        for _ in 0..<10 {
            await Task.yield()
        }

        XCTAssertFalse(result.succeeded)
        XCTAssertNil(result.result)
        let healthAfterLateApproval = await orchestrator.taskReviewerHealth()
        XCTAssertNotEqual(healthAfterLateApproval, .healthy)

        let events = await log.replay()
        let request = try XCTUnwrap(events.compactMap { envelope -> TaskReviewRequestedPayload? in
            guard case .taskReviewRequested(let payload) = envelope.event else { return nil }
            return payload
        }.first)
        XCTAssertFalse(events.contains { envelope in
            guard case .taskCompleted(let payload) = envelope.event else { return false }
            return payload.taskID == request.rootTaskID
        })
        XCTAssertFalse(events.contains { envelope in
            guard case .taskReviewSettled(let payload) = envelope.event else { return false }
            return payload.rootTaskID == request.rootTaskID
                && payload.verdict?.decision == .approve
        })
        let presentation = CodeProjection.build(
            from: events,
            presentationPolicy: .mandatoryTaskReview)
        XCTAssertTrue(presentation.items.filter { $0.kind == .agent }.isEmpty)
    }

    func testCancelAllAfterDurableApprovalSettlementStillPreventsRootCompletion() async throws {
        let log = try makeLog()
        let workspace = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let mainProvider = JudgeLifecycleScriptedProvider(["private approved draft"])
        let judgeProvider = JudgeLifecycleScriptedProvider([
            #"{"decision":"approve","summary":"durably approved before quiesce","findings":[],"requiredRevisions":[]}"#,
        ])
        let orchestrator = makeOrchestrator(
            log: log,
            mainProvider: mainProvider,
            judgeProvider: judgeProvider,
            policy: CoworkTaskReviewPolicy(
                maxRounds: 1,
                reviewTimeoutSeconds: 5,
                exhaustionDisposition: .fail))
        let attached = await attachMainAndJudge(orchestrator, workspace: workspace)
        XCTAssertTrue(attached.main && attached.judge)

        let settlementGate = JudgeLifecycleTaskStartGate()
        await orchestrator.setTaskLifecycleEventAppender { event in
            try await log.append(event)
            guard case .taskReviewSettled(let payload) = event,
                  payload.verdict?.decision == .approve else { return }
            // The approval is durable, but reviewRootTaskIfNeeded has not yet
            // returned it to the root execution.
            await settlementGate.pause()
        }

        let submission = Task {
            await orchestrator.submit("Quiesce after settlement but before root completion.")
        }
        await settlementGate.waitUntilEntered()

        let shutdown = Task {
            await orchestrator.cancelAll(reason: "quiesce after durable review settlement")
        }
        var observedShutdownBarrier = false
        for _ in 0..<100 {
            if await orchestrator.taskReviewerHealth() == .shuttingDown {
                observedShutdownBarrier = true
                break
            }
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
        XCTAssertTrue(observedShutdownBarrier)

        // cancelAll is waiting for the root execution to drain. Releasing the
        // appender now exercises the exact post-settlement health/cancellation
        // recheck before any root completion can be committed.
        await settlementGate.release()
        await shutdown.value
        let result = await submission.value

        XCTAssertFalse(result.succeeded)
        XCTAssertNil(result.result)
        let health = await orchestrator.taskReviewerHealth()
        XCTAssertEqual(health, .shuttingDown)

        let events = await log.replay()
        let approval = try XCTUnwrap(events.compactMap { envelope -> TaskReviewSettledPayload? in
            guard case .taskReviewSettled(let payload) = envelope.event,
                  payload.verdict?.decision == .approve else { return nil }
            return payload
        }.first)
        XCTAssertFalse(events.contains { envelope in
            guard case .taskCompleted(let payload) = envelope.event else { return false }
            return payload.taskID == approval.rootTaskID
        })
        let presentation = CodeProjection.build(
            from: events,
            presentationPolicy: .mandatoryTaskReview)
        XCTAssertTrue(presentation.items.filter { $0.kind == .agent }.isEmpty)
    }
}
