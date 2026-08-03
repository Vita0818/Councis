import XCTest
import Foundation
import IntatisCore
import IntatisProtocol
import IntatisConversation

final class EventCompatibilityTests: XCTestCase {
    func testOldTaskCreatedEventWithoutMetadataStillDecodes() throws {
        let json = """
        {"seq":1,"ts":"2026-06-23T12:00:00Z","session":"sess_old","v":1,"type":"task_created","payload":{"contract":{"id":"task_old","kind":"agent_invocation","issuer":"main","assignee":"worker","objective":"Old task","roleHint":"worker","expectedDeliverable":"answer","relatedAgents":[],"relatedTasks":[],"constraints":[]}}}
        """

        let envelope = try Envelope.makeDecoder().decode(Envelope.self, from: Data(json.utf8))

        guard case .taskCreated(let payload) = envelope.event else {
            return XCTFail("expected task_created")
        }
        XCTAssertEqual(payload.contract.id, TaskID(rawValue: "task_old"))
        XCTAssertNil(payload.metadata)
    }

    func testOldAgentAttachedEventWithoutMetadataStillDecodes() throws {
        let json = """
        {"seq":2,"ts":"2026-06-23T12:00:00Z","session":"sess_old","v":1,"type":"agent_attached","payload":{"agent":"worker","path":"/tmp/worker","model":"m","profile":"reviewed"}}
        """

        let envelope = try Envelope.makeDecoder().decode(Envelope.self, from: Data(json.utf8))

        guard case .agentAttached(let payload) = envelope.event else {
            return XCTFail("expected agent_attached")
        }
        XCTAssertEqual(payload.agent, AgentID(rawValue: "worker"))
        XCTAssertNil(payload.providerID)
        XCTAssertNil(payload.metadata)
    }

    func testOldAgentSpawnedEventWithoutProviderStillDecodes() throws {
        let json = """
        {"seq":3,"ts":"2026-06-23T12:00:00Z","session":"sess_old","v":1,"type":"agent_spawned","payload":{"requestedBy":"main","agent":"worker","path":"/tmp/worker","model":"m"}}
        """

        let envelope = try Envelope.makeDecoder().decode(Envelope.self, from: Data(json.utf8))

        guard case .agentSpawned(let payload) = envelope.event else {
            return XCTFail("expected agent_spawned")
        }
        XCTAssertEqual(payload.model, ModelID(rawValue: "m"))
        XCTAssertNil(payload.providerID)
    }

    func testProviderAwareAgentLifecycleEventsRoundTrip() throws {
        let worker = AgentID(rawValue: "worker")
        let model = ModelID(rawValue: "vendor/model")
        let events: [Event] = [
            .agentAttachRequested(AgentAttachRequestedPayload(
                agent: worker,
                path: "/tmp/worker",
                providerID: "provider-a",
                model: model,
                profile: "reviewed")),
            .agentAttached(AgentAttachedPayload(
                agent: worker,
                path: "/tmp/worker",
                providerID: "provider-a",
                model: model,
                profile: "reviewed")),
            .agentSpawnRequested(AgentSpawnRequestedPayload(
                requestedBy: AgentID(rawValue: "main"),
                agent: worker,
                path: "/tmp/worker",
                providerID: "provider-a",
                model: model)),
            .agentSpawned(AgentSpawnedPayload(
                requestedBy: AgentID(rawValue: "main"),
                agent: worker,
                path: "/tmp/worker",
                providerID: "provider-a",
                model: model)),
            .agentModelBound(AgentModelBoundPayload(
                agent: worker,
                providerID: "provider-b",
                model: ModelID(rawValue: "replacement-model"),
                reason: "explicit migration")),
        ]

        for (index, event) in events.enumerated() {
            let envelope = Envelope(
                seq: index,
                ts: Date(timeIntervalSince1970: TimeInterval(index)),
                session: SessionID(rawValue: "sess_binding"),
                event: event)
            let data = try Envelope.makeEncoder().encode(envelope)
            let decoded = try Envelope.makeDecoder().decode(Envelope.self, from: data)
            XCTAssertEqual(decoded, envelope)
        }
    }

    func testUnknownFutureEventDoesNotCrashReplayOrReuseSequence() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("intatis-unknown-event-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("events.jsonl")
        let known = """
        {"seq":0,"ts":"2026-06-23T12:00:00Z","session":"sess_future","v":1,"type":"user_message","payload":{"text":"hello"}}
        """
        let unknown = """
        {"seq":1,"ts":"2026-06-23T12:00:01Z","session":"sess_future","v":1,"type":"future_cowork_event","payload":{"value":true}}
        """
        try (known + "\n" + unknown + "\n").data(using: .utf8)!.write(to: url)
        let log = try EventLog(session: SessionID(rawValue: "sess_future"), fileURL: url)

        let appended = try await log.append(.userMessage(.init(text: "after future event")))
        let replay = await log.replay()

        XCTAssertEqual(appended.seq, 2)
        XCTAssertEqual(replay.map(\.seq), [0, 2])
        XCTAssertEqual(replay.count, 2)
        XCTAssertEqual(replay.first?.event.type, .userMessage)
    }
}
