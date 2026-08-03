import XCTest
import IntatisCore
import IntatisProtocol
import IntatisConversation

final class CoworkProjectionTests: XCTestCase {
    private let session = SessionID(rawValue: "projection")
    private let main = AgentID(rawValue: "main")
    private let worker = AgentID(rawValue: "worker")

    func testTaskQueuedStartedCompletedReplayIntoProjection() {
        let contract = taskContract()
        let envelopes: [Envelope] = [
            env(0, .taskCreated(TaskCreatedPayload(contract: contract))),
            env(1, .taskAssigned(TaskAssignedPayload(contract: contract))),
            env(2, .taskQueued(TaskQueuedPayload(
                contract: contract,
                rootTaskID: contract.id,
                issuer: main,
                assignee: worker,
                hopCount: 1,
                visitedAgents: [main, worker]))),
            env(3, .taskStarted(TaskStartedPayload(taskID: contract.id, agent: worker))),
            env(4, .taskCompleted(TaskCompletedPayload(taskID: contract.id, agent: worker, result: "done"))),
        ]

        let projection = CoworkProjection.build(from: envelopes)

        XCTAssertEqual(projection.tasks[contract.id]?.status, .completed)
        XCTAssertEqual(projection.tasks[contract.id]?.result, "done")
        XCTAssertEqual(projection.completedTasks.map(\.id), [contract.id])
        XCTAssertEqual(projection.mailboxes[worker]?.completedTasks, [contract.id])
    }

    func testTaskFailedReplayIntoProjection() {
        let contract = taskContract()
        let envelopes: [Envelope] = [
            env(0, .taskCreated(TaskCreatedPayload(contract: contract))),
            env(1, .taskQueued(TaskQueuedPayload(
                contract: contract,
                rootTaskID: contract.id,
                issuer: main,
                assignee: worker,
                hopCount: 1,
                visitedAgents: [main, worker]))),
            env(2, .taskFailed(TaskFailedPayload(taskID: contract.id, agent: worker, error: "missing agent"))),
        ]

        let projection = CoworkProjection.build(from: envelopes)

        XCTAssertEqual(projection.tasks[contract.id]?.status, .failed)
        XCTAssertEqual(projection.tasks[contract.id]?.error, "missing agent")
        XCTAssertEqual(projection.failedTasks.map(\.id), [contract.id])
    }

    func testLeaseReplayCreatesVisibleLeaseState() {
        let workspaceLease = WorkspaceLease(
            id: WorkspaceLeaseID(rawValue: "wlease_1"),
            workspaceID: WorkspaceID(rawValue: "workspace_1"),
            rootPath: "/tmp/work",
            access: .readOnly)
        let capabilityLease = CapabilityLease(
            id: CapabilityLeaseID(rawValue: "clease_1"),
            taskID: TaskID(rawValue: "task_1"),
            tools: [.readWorkspace, .searchWorkspace])
        let projection = CoworkProjection.build(from: [
            env(0, .workspaceLeaseGranted(WorkspaceLeaseGrantedPayload(agent: worker, lease: workspaceLease))),
            env(1, .capabilityLeaseCreated(CapabilityLeaseCreatedPayload(agent: worker, lease: capabilityLease))),
        ])

        XCTAssertEqual(projection.workspaceLeases[workspaceLease.id], workspaceLease)
        XCTAssertEqual(projection.capabilityLeases[capabilityLease.id], capabilityLease)
    }

    func testProjectionReconstructsAgentRosterAndMailboxMessages() {
        let message = AgentMessagePayload(
            from: main,
            to: worker,
            content: "status?",
            kind: .sendMessage,
            messageId: MessageID(rawValue: "msg_status"),
            taskID: TaskID(rawValue: "task_root"))
        let projection = CoworkProjection.build(from: [
            env(0, .agentAttached(AgentAttachedPayload(
                agent: main,
                path: "/tmp/main",
                model: ModelID(rawValue: "m"),
                profile: "reviewed"))),
            env(1, .agentAttached(AgentAttachedPayload(
                agent: worker,
                path: "/tmp/worker",
                model: ModelID(rawValue: "m"),
                profile: "reviewed"))),
            env(2, .agentMessage(message)),
            env(3, .agentDetached(AgentDetachedPayload(agent: main))),
        ])

        XCTAssertNil(projection.agentRoster[main])
        XCTAssertEqual(projection.agentRoster[worker]?.path, "/tmp/worker")
        XCTAssertEqual(projection.agentMessages, [message])
        XCTAssertEqual(projection.mailboxes[worker]?.pendingMessages, [MessageID(rawValue: "msg_status")])
    }

    func testProjectionTracksLifecycleBindingThenExplicitBoundOverridesAndDetachClears() {
        let lifecycleEvents: [Envelope] = [
            env(0, .agentAttached(AgentAttachedPayload(
                agent: worker,
                path: "/tmp/worker",
                providerID: "provider-a",
                model: ModelID(rawValue: "initial-model"),
                profile: "reviewed"))),
            env(1, .agentSpawned(AgentSpawnedPayload(
                requestedBy: main,
                agent: worker,
                path: "/tmp/worker",
                providerID: "provider-b",
                model: ModelID(rawValue: "spawn-model")))),
        ]

        let lifecycle = CoworkProjection.build(from: lifecycleEvents)
        XCTAssertEqual(lifecycle.agentRoster[worker]?.providerID, "provider-b")
        XCTAssertEqual(lifecycle.agentModelBindings[worker], AgentModelBinding(
            providerID: "provider-b",
            modelID: ModelID(rawValue: "spawn-model")))

        let reboundEvents = lifecycleEvents + [
            env(2, .agentModelBound(AgentModelBoundPayload(
                agent: worker,
                providerID: "provider-c",
                model: ModelID(rawValue: "bound-model"),
                reason: "legacy provider migration"))),
        ]
        let rebound = CoworkProjection.build(from: reboundEvents)
        XCTAssertEqual(rebound.agentModelBindings[worker], AgentModelBinding(
            providerID: "provider-c",
            modelID: ModelID(rawValue: "bound-model")))

        let detached = CoworkProjection.build(from: reboundEvents + [
            env(3, .agentDetached(AgentDetachedPayload(agent: worker))),
        ])
        XCTAssertNil(detached.agentRoster[worker])
        XCTAssertNil(detached.agentModelBindings[worker])
    }

    func testLegacyModelOnlyLifecycleDoesNotInventProviderBinding() {
        let projection = CoworkProjection.build(from: [
            env(0, .agentAttached(AgentAttachedPayload(
                agent: worker,
                path: "/tmp/worker",
                model: ModelID(rawValue: "legacy-model"),
                profile: "reviewed"))),
            env(1, .agentSpawned(AgentSpawnedPayload(
                requestedBy: main,
                agent: worker,
                path: "/tmp/worker",
                model: ModelID(rawValue: "legacy-model")))),
        ])

        XCTAssertNil(projection.agentRoster[worker]?.providerID)
        XCTAssertNil(projection.agentModelBindings[worker])
    }

    func testProjectionRestoresAgentStatusAndReplayIsStable() {
        let contract = taskContract()
        let workspaceLease = WorkspaceLease(
            id: WorkspaceLeaseID(rawValue: "wlease_projection"),
            workspaceID: WorkspaceID(rawValue: "workspace_projection"),
            rootPath: "/tmp/worker",
            access: .readOnly)
        let capabilityLease = CapabilityLease(
            id: CapabilityLeaseID(rawValue: "clease_projection"),
            taskID: contract.id,
            tools: [.readWorkspace, .searchWorkspace, .requestDelegation])
        let envelopes: [Envelope] = [
            env(0, .agentAttached(AgentAttachedPayload(
                agent: worker,
                path: "/tmp/worker",
                model: ModelID(rawValue: "m"),
                profile: "reviewed"))),
            env(1, .workspaceLeaseGranted(WorkspaceLeaseGrantedPayload(agent: worker, lease: workspaceLease))),
            env(2, .capabilityLeaseCreated(CapabilityLeaseCreatedPayload(agent: worker, lease: capabilityLease))),
            env(3, .taskCreated(TaskCreatedPayload(contract: contract))),
            env(4, .taskQueued(TaskQueuedPayload(
                contract: contract,
                rootTaskID: contract.id,
                issuer: main,
                assignee: worker,
                hopCount: 1,
                visitedAgents: [main, worker]))),
            env(5, .agentStatus(AgentStatusPayload(agent: worker, state: .thinking, task: "count files"))),
            env(6, .taskStarted(TaskStartedPayload(taskID: contract.id, agent: worker))),
        ]

        let first = CoworkProjection.build(from: envelopes)
        let second = CoworkProjection.build(from: envelopes)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.agentRoster[worker]?.path, "/tmp/worker")
        XCTAssertEqual(first.agentStatuses[worker], .thinking)
        XCTAssertEqual(first.runningTasks.map(\.id), [contract.id])
        XCTAssertEqual(first.mailboxes[worker]?.pendingTasks, [])
        XCTAssertEqual(first.workspaceLeases[workspaceLease.id], workspaceLease)
        XCTAssertEqual(first.capabilityLeases[capabilityLease.id], capabilityLease)
    }

    private func taskContract() -> TaskContract {
        TaskContract(
            id: TaskID(rawValue: "task_projection"),
            issuer: main,
            assignee: worker,
            objective: "Do projection task.",
            roleHint: "projection worker",
            expectedDeliverable: "done")
    }

    private func env(_ seq: Int, _ event: Event) -> Envelope {
        Envelope(seq: seq, ts: Date(timeIntervalSince1970: TimeInterval(seq)), session: session, event: event)
    }
}
