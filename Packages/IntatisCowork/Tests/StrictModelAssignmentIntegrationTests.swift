import XCTest
import Foundation
import IntatisCore
import IntatisProtocol
import IntatisProviders
import IntatisPermission
import IntatisConversation
import IntatisAgentKernel
@testable import IntatisCowork

private struct StrictModelTestProvider: ToolCallingProvider {
    func stream(_ request: AgentRequest) -> AsyncThrowingStream<AgentChunk, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.textDelta(#"{"decision":"allow","reason":"test approval"}"#))
            continuation.yield(.done(finishReason: "stop"))
            continuation.finish()
        }
    }
}

private actor ProviderBindingRecorder {
    private var observations: [(AgentID, AgentModelBinding)] = []

    func record(_ agent: Agent) {
        observations.append((agent.name, agent.modelBinding))
    }

    func bindingsByAgent() -> [AgentID: AgentModelBinding] {
        Dictionary(uniqueKeysWithValues: observations)
    }
}

private actor AgentRequestModelRecorder {
    private var observations: [AgentID: [ModelID]] = [:]

    func record(agent: AgentID, model: ModelID) {
        observations[agent, default: []].append(model)
    }

    func models(for agent: AgentID) -> [ModelID] {
        observations[agent] ?? []
    }
}

private struct RequestModelRecordingProvider: ToolCallingProvider {
    let agent: AgentID
    let recorder: AgentRequestModelRecorder

    func stream(_ request: AgentRequest) -> AsyncThrowingStream<AgentChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await recorder.record(agent: agent, model: request.model)
                continuation.yield(.textDelta("completed by @\(agent.rawValue)"))
                continuation.yield(.done(finishReason: "stop"))
                continuation.finish()
            }
        }
    }
}

private actor SuspendedAttachResponder: PermissionResponder {
    private var pendingDecision: CheckedContinuation<PermissionDecision, Never>?
    private var requestWaiters: [CheckedContinuation<Void, Never>] = []
    private var receivedRequest = false

    func requestApproval(_ request: PermissionRequestPayload) async -> PermissionDecision {
        await withCheckedContinuation { continuation in
            pendingDecision = continuation
            receivedRequest = true
            let waiters = requestWaiters
            requestWaiters.removeAll()
            for waiter in waiters {
                waiter.resume()
            }
        }
    }

    func waitUntilRequested() async {
        if receivedRequest { return }
        await withCheckedContinuation { continuation in
            requestWaiters.append(continuation)
        }
    }

    func resolve(_ decision: PermissionDecision) {
        let continuation = pendingDecision
        pendingDecision = nil
        continuation?.resume(returning: decision)
    }
}

final class StrictModelAssignmentIntegrationTests: XCTestCase {
    private func makeLog() throws -> EventLog {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("councis-strict-model-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("events.jsonl")
        return try EventLog(session: SessionID.new(), fileURL: url)
    }

    private func makeWorkspace(_ name: String = "workspace") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("councis-strict-model-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func binding(_ provider: String, _ model: String) -> AgentModelBinding {
        AgentModelBinding(
            providerID: provider,
            modelID: ModelID(rawValue: model))
    }

    private func policy(workerPool: [AgentModelBinding] = [],
                        allowedBindings: [AgentModelBinding] = [],
                        fixedAgentBindings: [FixedAgentModelBinding] = [],
                        onExhausted: ModelPoolExhaustionPolicy = .askUser) -> ModelAssignmentPolicy {
        ModelAssignmentPolicy(
            workerPool: workerPool.map { ModelPoolEntry(binding: $0) },
            allowedBindings: allowedBindings,
            fixedAgentBindings: fixedAgentBindings,
            uniquePerActiveAgent: true,
            inheritParentModel: false,
            onExhausted: onExhausted)
    }

    private func orchestrator(log: EventLog,
                              policy: ModelAssignmentPolicy,
                              responder: PermissionResponder = FixedResponder(.allow),
                              taskReviewPolicy: CoworkTaskReviewPolicy? = nil,
                              recorder: ProviderBindingRecorder? = nil) -> Orchestrator {
        Orchestrator(
            log: log,
            allowsShell: true,
            responder: responder,
            executionPolicy: CoworkExecutionPolicy(maxConcurrentTasks: 2),
            taskReviewPolicy: taskReviewPolicy,
            modelAssignmentPolicy: policy
        ) { agent in
            await recorder?.record(agent)
            return StrictModelTestProvider()
        }
    }

    private func makeAgent(name: AgentID,
                           workspace: URL,
                           binding: AgentModelBinding,
                           coordinates: Bool = false) -> Agent {
        Agent(
            name: name,
            workspaceRoot: workspace,
            modelBinding: binding,
            profile: .reviewed,
            coordinationDepth: coordinates ? Agent.defaultCoordinationDepth : 0)
    }

    func testMainAndJudgeCannotShareStrictDataPlaneBinding() async throws {
        let log = try makeLog()
        let workspace = try makeWorkspace("main-judge")
        defer { try? FileManager.default.removeItem(at: workspace) }
        let shared = binding("provider-a", "shared-model")
        let runtime = orchestrator(
            log: log,
            policy: policy(allowedBindings: [shared]),
            taskReviewPolicy: .always)

        let mainAttached = await runtime.attach(makeAgent(
            name: Orchestrator.mainAgentID,
            workspace: workspace,
            binding: shared,
            coordinates: true))
        let judgeAttached = await runtime.attachTaskReviewer(makeAgent(
            name: Orchestrator.taskReviewerID,
            workspace: workspace,
            binding: shared))

        XCTAssertTrue(mainAttached)
        XCTAssertFalse(judgeAttached)
        let attachedNames = await runtime.agentNames()
        XCTAssertEqual(attachedNames, [Orchestrator.mainAgentID])
        let errors = await log.replay().compactMap { envelope -> ErrorPayload? in
            guard case .error(let payload) = envelope.event else { return nil }
            return payload
        }
        XCTAssertTrue(errors.contains {
            $0.code == "model_assignment_rejected"
                && $0.message.contains("already used by an active agent")
        })
    }

    func testReservedRolesRejectSwappedBindingsDuringAdmission() async throws {
        let log = try makeLog()
        let workspace = try makeWorkspace("fixed-role-admission")
        defer { try? FileManager.default.removeItem(at: workspace) }
        let mainBinding = binding("provider-main", "main-model")
        let judgeBinding = binding("provider-judge", "judge-model")
        let fixed = [
            FixedAgentModelBinding(
                agentID: Orchestrator.mainAgentID,
                binding: mainBinding),
            FixedAgentModelBinding(
                agentID: Orchestrator.taskReviewerID,
                binding: judgeBinding),
        ]
        let runtime = orchestrator(
            log: log,
            policy: policy(
                allowedBindings: [mainBinding, judgeBinding],
                fixedAgentBindings: fixed),
            taskReviewPolicy: .always)

        let swappedMain = await runtime.attach(makeAgent(
            name: Orchestrator.mainAgentID,
            workspace: workspace,
            binding: judgeBinding,
            coordinates: true))
        let swappedJudge = await runtime.attachTaskReviewer(makeAgent(
            name: Orchestrator.taskReviewerID,
            workspace: workspace,
            binding: mainBinding))
        let workerUsingReservedMain = await runtime.attach(makeAgent(
            name: AgentID(rawValue: "worker"),
            workspace: workspace,
            binding: mainBinding))

        XCTAssertFalse(swappedMain)
        XCTAssertFalse(swappedJudge)
        XCTAssertFalse(workerUsingReservedMain)
        let admittedAgents = await runtime.agentList()
        XCTAssertTrue(admittedAgents.isEmpty)
        let messages = await log.replay().compactMap { envelope -> String? in
            guard case .error(let payload) = envelope.event,
                  payload.code == "model_assignment_rejected" else { return nil }
            return payload.message
        }
        XCTAssertTrue(messages.contains { $0.contains("@main") && $0.contains("is fixed to") })
        XCTAssertTrue(messages.contains { $0.contains("@judge") && $0.contains("is fixed to") })
        XCTAssertTrue(messages.contains { $0.contains("reserved for @main") })
    }

    func testStrictRestoreRejectsSwappedReservedRoleBindings() async throws {
        let log = try makeLog()
        let workspace = try makeWorkspace("fixed-role-restore")
        defer { try? FileManager.default.removeItem(at: workspace) }
        let mainBinding = binding("provider-main", "main-model")
        let judgeBinding = binding("provider-judge", "judge-model")
        try await log.append(.agentAttached(AgentAttachedPayload(
            agent: Orchestrator.mainAgentID,
            path: workspace.path,
            providerID: judgeBinding.providerID,
            model: judgeBinding.modelID,
            profile: PermissionProfile.reviewed.rawValue)))
        try await log.append(.agentAttached(AgentAttachedPayload(
            agent: Orchestrator.taskReviewerID,
            path: workspace.path,
            providerID: mainBinding.providerID,
            model: mainBinding.modelID,
            profile: PermissionProfile.readOnly.rawValue)))
        try await log.append(.agentAttached(AgentAttachedPayload(
            agent: AgentID(rawValue: "worker-using-reserved-main"),
            path: workspace.path,
            providerID: mainBinding.providerID,
            model: mainBinding.modelID,
            profile: PermissionProfile.reviewed.rawValue)))
        let runtime = orchestrator(
            log: log,
            policy: policy(
                allowedBindings: [mainBinding, judgeBinding],
                fixedAgentBindings: [
                    FixedAgentModelBinding(
                        agentID: Orchestrator.mainAgentID,
                        binding: mainBinding),
                    FixedAgentModelBinding(
                        agentID: Orchestrator.taskReviewerID,
                        binding: judgeBinding),
                ]),
            taskReviewPolicy: .always)

        await runtime.restore(from: CoworkProjection.build(from: await log.replay()))

        let restoredAgents = await runtime.agentList()
        XCTAssertTrue(restoredAgents.isEmpty)
        let errors = await log.replay().compactMap { envelope -> ErrorPayload? in
            guard case .error(let payload) = envelope.event else { return nil }
            return payload
        }
        XCTAssertEqual(
            errors.filter { $0.code == "restore_model_assignment_rejected" }.count,
            3)
        XCTAssertTrue(errors.contains {
            $0.code == "restore_model_assignment_rejected"
                && $0.message.contains("@main")
                && $0.message.contains("is fixed to")
        })
        XCTAssertTrue(errors.contains {
            $0.code == "restore_model_assignment_rejected"
                && $0.message.contains("@judge")
                && $0.message.contains("is fixed to")
        })
        XCTAssertTrue(errors.contains {
            $0.code == "restore_model_assignment_rejected"
                && $0.message.contains("worker-using-reserved-main")
                && $0.message.contains("reserved for @main")
        })
    }

    func testOmittedSpawnBindingUsesPoolOrderNeverParentThenFailsExplicitlyWhenExhausted() async throws {
        let log = try makeLog()
        let mainWorkspace = try makeWorkspace("pool-main")
        let firstWorkspace = try makeWorkspace("pool-first")
        let secondWorkspace = try makeWorkspace("pool-second")
        let exhaustedWorkspace = try makeWorkspace("pool-exhausted")
        defer {
            try? FileManager.default.removeItem(at: mainWorkspace)
            try? FileManager.default.removeItem(at: firstWorkspace)
            try? FileManager.default.removeItem(at: secondWorkspace)
            try? FileManager.default.removeItem(at: exhaustedWorkspace)
        }
        let mainBinding = binding("provider-main", "parent-model")
        let firstBinding = binding("provider-first", "worker-one")
        let secondBinding = binding("provider-second", "worker-two")
        let runtime = orchestrator(
            log: log,
            policy: policy(
                workerPool: [firstBinding, secondBinding],
                allowedBindings: [mainBinding]))
        let mainAttached = await runtime.attach(makeAgent(
            name: Orchestrator.mainAgentID,
            workspace: mainWorkspace,
            binding: mainBinding,
            coordinates: true))
        XCTAssertTrue(mainAttached)

        let firstResult = await runtime.spawnFromTool(
            requestedBy: Orchestrator.mainAgentID,
            name: "worker-first",
            path: firstWorkspace.path,
            provider: nil,
            model: nil)
        let secondResult = await runtime.spawnFromTool(
            requestedBy: Orchestrator.mainAgentID,
            name: "worker-second",
            path: secondWorkspace.path,
            provider: nil,
            model: nil)
        let exhaustedResult = await runtime.spawnFromTool(
            requestedBy: Orchestrator.mainAgentID,
            name: "worker-exhausted",
            path: exhaustedWorkspace.path,
            provider: nil,
            model: nil)

        XCTAssertTrue(firstResult.contains("provider-first/worker-one"))
        XCTAssertTrue(secondResult.contains("provider-second/worker-two"))
        XCTAssertEqual(
            exhaustedResult,
            "error: no unused compatible worker model remains; ask the user to choose or expand the model pool")
        let agents = await runtime.agentList()
        let actual = Dictionary(uniqueKeysWithValues: agents.map { ($0.name, $0.modelBinding) })
        XCTAssertEqual(actual[AgentID(rawValue: "worker-first")], firstBinding)
        XCTAssertEqual(actual[AgentID(rawValue: "worker-second")], secondBinding)
        XCTAssertNotEqual(actual[AgentID(rawValue: "worker-first")], mainBinding)
        XCTAssertNotEqual(actual[AgentID(rawValue: "worker-second")], mainBinding)
        XCTAssertNil(actual[AgentID(rawValue: "worker-exhausted")])
    }

    func testSameModelNameOnDifferentProvidersIsAllowed() async throws {
        let log = try makeLog()
        let firstWorkspace = try makeWorkspace("same-model-a")
        let secondWorkspace = try makeWorkspace("same-model-b")
        defer {
            try? FileManager.default.removeItem(at: firstWorkspace)
            try? FileManager.default.removeItem(at: secondWorkspace)
        }
        let first = binding("provider-a", "shared-name")
        let second = binding("provider-b", "shared-name")
        let runtime = orchestrator(
            log: log,
            policy: policy(allowedBindings: [first, second]))

        let firstAttached = await runtime.attach(makeAgent(
            name: AgentID(rawValue: "worker-a"),
            workspace: firstWorkspace,
            binding: first))
        let secondAttached = await runtime.attach(makeAgent(
            name: AgentID(rawValue: "worker-b"),
            workspace: secondWorkspace,
            binding: second))

        XCTAssertTrue(firstAttached)
        XCTAssertTrue(secondAttached)
        let bindings = Dictionary(uniqueKeysWithValues: await runtime.agentList().map {
            ($0.name, $0.modelBinding)
        })
        XCTAssertEqual(bindings[AgentID(rawValue: "worker-a")], first)
        XCTAssertEqual(bindings[AgentID(rawValue: "worker-b")], second)
    }

    func testPermissionReviewerCanShareMainBinding() async throws {
        let log = try makeLog()
        let workspace = try makeWorkspace("reviewer-shares-main")
        defer { try? FileManager.default.removeItem(at: workspace) }
        let shared = binding("provider-shared", "shared-model")
        let runtime = orchestrator(
            log: log,
            policy: policy(allowedBindings: [shared]))
        let mainAttached = await runtime.attach(makeAgent(
            name: Orchestrator.mainAgentID,
            workspace: workspace,
            binding: shared,
            coordinates: true))
        XCTAssertTrue(mainAttached)

        let enabled = await runtime.enableAutomaticPermissionReview(
            modelBinding: shared,
            workspaceRoot: workspace)

        XCTAssertEqual(enabled, .enabled(Orchestrator.automaticPermissionReviewerID))
        let bindings = Dictionary(uniqueKeysWithValues: await runtime.agentList().map {
            ($0.name, $0.modelBinding)
        })
        XCTAssertEqual(bindings[Orchestrator.mainAgentID], shared)
        XCTAssertEqual(bindings[Orchestrator.automaticPermissionReviewerID], shared)
    }

    func testPermissionReviewerDoesNotConsumeWorkerPoolBinding() async throws {
        let log = try makeLog()
        let mainWorkspace = try makeWorkspace("reviewer-pool-main")
        let workerWorkspace = try makeWorkspace("reviewer-pool-worker")
        defer {
            try? FileManager.default.removeItem(at: mainWorkspace)
            try? FileManager.default.removeItem(at: workerWorkspace)
        }
        let mainBinding = binding("provider-main", "main-model")
        let poolBinding = binding("provider-pool", "pool-model")
        let runtime = orchestrator(
            log: log,
            policy: policy(
                workerPool: [poolBinding],
                allowedBindings: [mainBinding]))
        let mainAttached = await runtime.attach(makeAgent(
            name: Orchestrator.mainAgentID,
            workspace: mainWorkspace,
            binding: mainBinding,
            coordinates: true))
        XCTAssertTrue(mainAttached)
        let enabled = await runtime.enableAutomaticPermissionReview(
            modelBinding: poolBinding,
            workspaceRoot: mainWorkspace)
        XCTAssertEqual(enabled, .enabled(Orchestrator.automaticPermissionReviewerID))

        let result = await runtime.spawnFromTool(
            requestedBy: Orchestrator.mainAgentID,
            name: "pool-worker",
            path: workerWorkspace.path,
            provider: nil,
            model: nil)

        XCTAssertTrue(result.contains("provider-pool/pool-model"))
        let bindings = Dictionary(uniqueKeysWithValues: await runtime.agentList().map {
            ($0.name, $0.modelBinding)
        })
        XCTAssertEqual(bindings[Orchestrator.automaticPermissionReviewerID], poolBinding)
        XCTAssertEqual(bindings[AgentID(rawValue: "pool-worker")], poolBinding)
    }

    func testDetachReleasesBindingForAnotherAgent() async throws {
        let log = try makeLog()
        let firstWorkspace = try makeWorkspace("reuse-first")
        let secondWorkspace = try makeWorkspace("reuse-second")
        defer {
            try? FileManager.default.removeItem(at: firstWorkspace)
            try? FileManager.default.removeItem(at: secondWorkspace)
        }
        let reusable = binding("provider-reusable", "worker-model")
        let runtime = orchestrator(
            log: log,
            policy: policy(allowedBindings: [reusable]))
        let firstID = AgentID(rawValue: "first-owner")
        let secondID = AgentID(rawValue: "second-owner")

        let firstAttached = await runtime.attach(makeAgent(
            name: firstID,
            workspace: firstWorkspace,
            binding: reusable))
        let detached = await runtime.detach(firstID, reason: "release model binding")
        let secondAttached = await runtime.attach(makeAgent(
            name: secondID,
            workspace: secondWorkspace,
            binding: reusable))
        XCTAssertTrue(firstAttached)
        XCTAssertTrue(detached)
        XCTAssertTrue(secondAttached)

        let agents = await runtime.agentList()
        XCTAssertFalse(agents.contains { $0.name == firstID })
        XCTAssertEqual(agents.first { $0.name == secondID }?.modelBinding, reusable)
    }

    func testLegacyModelOnlyRestorePersistsOneStableBindingMigration() async throws {
        let log = try makeLog()
        let workspace = try makeWorkspace("legacy-restore")
        defer { try? FileManager.default.removeItem(at: workspace) }
        let migrated = binding("legacy-provider", "legacy-model")
        try await log.append(.agentAttached(AgentAttachedPayload(
            agent: Orchestrator.mainAgentID,
            path: workspace.path,
            model: migrated.modelID,
            profile: PermissionProfile.reviewed.rawValue)))
        let strictPolicy = policy(allowedBindings: [migrated])
        let runtime = Orchestrator(
            log: log,
            allowsShell: true,
            responder: FixedResponder(.allow),
            modelAssignmentPolicy: strictPolicy,
            legacyProviderID: migrated.providerID
        ) { _ in StrictModelTestProvider() }

        await runtime.restore(from: CoworkProjection.build(from: await log.replay()))
        let firstRestoreBinding = await runtime.agentList().first?.modelBinding
        XCTAssertEqual(firstRestoreBinding, migrated)
        var migrations = await log.replay().compactMap { envelope -> AgentModelBoundPayload? in
            guard case .agentModelBound(let payload) = envelope.event else { return nil }
            return payload
        }
        XCTAssertEqual(migrations.count, 1)
        XCTAssertEqual(migrations.first?.binding, migrated)
        XCTAssertEqual(migrations.first?.reason, "legacy model-only lifecycle migration")

        await runtime.restore(from: CoworkProjection.build(from: await log.replay()))

        let secondRestoreBinding = await runtime.agentList().first?.modelBinding
        XCTAssertEqual(secondRestoreBinding, migrated)
        migrations = await log.replay().compactMap { envelope -> AgentModelBoundPayload? in
            guard case .agentModelBound(let payload) = envelope.event else { return nil }
            return payload
        }
        XCTAssertEqual(migrations.count, 1, "a durable migration must not be appended again")
    }

    func testProviderAwareLifecycleRestoreKeepsExactBindingWithoutRebind() async throws {
        let log = try makeLog()
        let workspace = try makeWorkspace("provider-aware-restore")
        defer { try? FileManager.default.removeItem(at: workspace) }
        let expected = binding("persisted-provider", "persisted-model")
        let workerID = AgentID(rawValue: "persisted-worker")
        try await log.append(.agentAttached(AgentAttachedPayload(
            agent: workerID,
            path: workspace.path,
            providerID: expected.providerID,
            model: expected.modelID,
            profile: PermissionProfile.reviewed.rawValue)))
        let runtime = orchestrator(
            log: log,
            policy: policy(allowedBindings: [expected]))

        await runtime.restore(from: CoworkProjection.build(from: await log.replay()))
        let firstBinding = await runtime.agentList().first { $0.name == workerID }?.modelBinding
        XCTAssertEqual(firstBinding, expected)

        await runtime.restore(from: CoworkProjection.build(from: await log.replay()))
        let secondBinding = await runtime.agentList().first { $0.name == workerID }?.modelBinding
        XCTAssertEqual(secondBinding, expected)
        let rebinds = await log.replay().filter {
            if case .agentModelBound = $0.event { return true }
            return false
        }
        XCTAssertTrue(rebinds.isEmpty, "provider-aware lifecycle events must not be migrated or rebound")
    }

    func testStrictRestoreWithoutProviderFailsClosed() async throws {
        let log = try makeLog()
        let workspace = try makeWorkspace("strict-restore-missing-provider")
        defer { try? FileManager.default.removeItem(at: workspace) }
        let expected = binding("configured-provider", "legacy-model")
        try await log.append(.agentAttached(AgentAttachedPayload(
            agent: AgentID(rawValue: "legacy-worker"),
            path: workspace.path,
            model: expected.modelID,
            profile: PermissionProfile.reviewed.rawValue)))
        let runtime = orchestrator(
            log: log,
            policy: policy(allowedBindings: [expected]))

        await runtime.restore(from: CoworkProjection.build(from: await log.replay()))

        let restoredAgents = await runtime.agentList()
        XCTAssertTrue(restoredAgents.isEmpty)
        let errors = await log.replay().compactMap { envelope -> ErrorPayload? in
            guard case .error(let payload) = envelope.event else { return nil }
            return payload
        }
        XCTAssertTrue(errors.contains {
            $0.code == "restore_missing_provider_binding"
                && $0.message.contains("no legacy provider migration is configured")
        })
        let reboundEvents = await log.replay()
        XCTAssertFalse(reboundEvents.contains {
            if case .agentModelBound = $0.event { return true }
            return false
        })
    }

    func testProviderResolverReceivesEachAgentsActualBinding() async throws {
        let log = try makeLog()
        let mainWorkspace = try makeWorkspace("provider-for-main")
        let workerWorkspace = try makeWorkspace("provider-for-worker")
        defer {
            try? FileManager.default.removeItem(at: mainWorkspace)
            try? FileManager.default.removeItem(at: workerWorkspace)
        }
        let mainBinding = binding("endpoint-a", "same-model-name")
        let workerBinding = binding("endpoint-b", "same-model-name")
        let recorder = ProviderBindingRecorder()
        let runtime = orchestrator(
            log: log,
            policy: policy(allowedBindings: [mainBinding, workerBinding]),
            recorder: recorder)
        let mainAttached = await runtime.attach(makeAgent(
            name: Orchestrator.mainAgentID,
            workspace: mainWorkspace,
            binding: mainBinding,
            coordinates: true))
        let workerID = AgentID(rawValue: "provider-worker")
        let workerAttached = await runtime.attach(makeAgent(
            name: workerID,
            workspace: workerWorkspace,
            binding: workerBinding))
        XCTAssertTrue(mainAttached)
        XCTAssertTrue(workerAttached)

        let mainResult = await runtime.send("run main", to: Orchestrator.mainAgentID)
        let workerResult = await runtime.send("run worker", to: workerID)
        XCTAssertEqual(mainResult, .sent)
        XCTAssertEqual(workerResult, .sent)

        let observed = await recorder.bindingsByAgent()
        XCTAssertEqual(observed[Orchestrator.mainAgentID], mainBinding)
        XCTAssertEqual(observed[workerID], workerBinding)
    }

    func testEachAgentRequestUsesItsOwnBoundModel() async throws {
        let log = try makeLog()
        let mainWorkspace = try makeWorkspace("request-model-main")
        let workerWorkspace = try makeWorkspace("request-model-worker")
        defer {
            try? FileManager.default.removeItem(at: mainWorkspace)
            try? FileManager.default.removeItem(at: workerWorkspace)
        }
        let mainBinding = binding("endpoint-a", "main-model")
        let workerBinding = binding("endpoint-b", "worker-model")
        let recorder = AgentRequestModelRecorder()
        let runtime = Orchestrator(
            log: log,
            allowsShell: true,
            responder: FixedResponder(.allow),
            modelAssignmentPolicy: policy(allowedBindings: [mainBinding, workerBinding])
        ) { agent in
            RequestModelRecordingProvider(agent: agent.name, recorder: recorder)
        }
        let workerID = AgentID(rawValue: "request-model-worker")
        let mainAttached = await runtime.attach(makeAgent(
            name: Orchestrator.mainAgentID,
            workspace: mainWorkspace,
            binding: mainBinding,
            coordinates: true))
        let workerAttached = await runtime.attach(makeAgent(
            name: workerID,
            workspace: workerWorkspace,
            binding: workerBinding))
        XCTAssertTrue(mainAttached)
        XCTAssertTrue(workerAttached)

        let mainResult = await runtime.send("run main", to: Orchestrator.mainAgentID)
        let workerResult = await runtime.send("run worker", to: workerID)
        XCTAssertEqual(mainResult, .sent)
        XCTAssertEqual(workerResult, .sent)

        let mainModels = await recorder.models(for: Orchestrator.mainAgentID)
        let workerModels = await recorder.models(for: workerID)
        XCTAssertEqual(mainModels, [mainBinding.modelID])
        XCTAssertEqual(workerModels, [workerBinding.modelID])
    }

    func testConcurrentAttachReservationRejectsDuplicateWhileFirstWaitsForPermission() async throws {
        let log = try makeLog()
        let firstWorkspace = try makeWorkspace("reserved-first")
        let secondWorkspace = try makeWorkspace("reserved-second")
        defer {
            try? FileManager.default.removeItem(at: firstWorkspace)
            try? FileManager.default.removeItem(at: secondWorkspace)
        }
        let shared = binding("provider-reserved", "reserved-model")
        let responder = SuspendedAttachResponder()
        let runtime = orchestrator(
            log: log,
            policy: policy(allowedBindings: [shared]),
            responder: responder)
        let firstID = AgentID(rawValue: "reserved-first")
        let secondID = AgentID(rawValue: "reserved-second")

        let firstAttach = Task {
            await runtime.attach(makeAgent(
                name: firstID,
                workspace: firstWorkspace,
                binding: shared))
        }
        await responder.waitUntilRequested()

        let secondAttached = await runtime.attach(makeAgent(
            name: secondID,
            workspace: secondWorkspace,
            binding: shared))
        XCTAssertFalse(secondAttached)
        await responder.resolve(.allow)
        let firstAttached = await firstAttach.value
        XCTAssertTrue(firstAttached)

        let agents = await runtime.agentList()
        XCTAssertEqual(agents.map(\.name), [firstID])
        let events = await log.replay()
        XCTAssertEqual(events.filter { $0.event.type == .permissionRequest }.count, 1)
        XCTAssertTrue(events.contains {
            guard case .error(let payload) = $0.event else { return false }
            return payload.code == "model_assignment_rejected"
                && payload.message.contains("already used by an active agent")
        })
    }
}
