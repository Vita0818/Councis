import XCTest
import Foundation
import IntatisProtocol
import IntatisTools
@testable import IntatisCowork

private struct RecordedSpawn: Equatable, Sendable {
    let name: String
    let path: String
    let provider: String?
    let model: String?
    let canCoordinate: Bool
}

private actor RecordingAgentManager: AgentManager {
    private var calls: [RecordedSpawn] = []

    func spawnAgent(name: String,
                    path: String,
                    provider: String?,
                    model: String?,
                    canCoordinate: Bool) async -> String {
        calls.append(RecordedSpawn(
            name: name,
            path: path,
            provider: provider,
            model: model,
            canCoordinate: canCoordinate))
        return "spawned @\(name)"
    }

    func listAgents() async -> String { "" }
    func removeAgent(name: String) async -> String { "" }
    func recordedCalls() -> [RecordedSpawn] { calls }
}

final class SpawnAgentToolModelBindingTests: XCTestCase {
    func testOmittedProviderAndModelReachManagerAsNilForPoolSelection() async throws {
        let manager = RecordingAgentManager()
        let observation = try await SpawnAgentTool().execute(
            ToolArgs(raw: #"{"name":"worker","path":"/tmp/work"}"#),
            in: context(manager: manager))

        XCTAssertEqual(observation.text, "spawned @worker")
        let calls = await manager.recordedCalls()
        XCTAssertEqual(calls, [RecordedSpawn(
            name: "worker",
            path: "/tmp/work",
            provider: nil,
            model: nil,
            canCoordinate: false)])
    }

    func testExplicitProviderAndModelReachManagerTogether() async throws {
        let manager = RecordingAgentManager()
        let observation = try await SpawnAgentTool().execute(
            ToolArgs(raw: #"{"name":"worker","path":"/tmp/work","provider":"anthropic","model":"opus","canCoordinate":true}"#),
            in: context(manager: manager))

        XCTAssertEqual(observation.text, "spawned @worker")
        let calls = await manager.recordedCalls()
        XCTAssertEqual(calls, [RecordedSpawn(
            name: "worker",
            path: "/tmp/work",
            provider: "anthropic",
            model: "opus",
            canCoordinate: true)])
    }

    func testPartialBindingIsRejectedBeforeManagerInvocation() async throws {
        let manager = RecordingAgentManager()
        let providerOnly = try await SpawnAgentTool().execute(
            ToolArgs(raw: #"{"name":"a","path":"/tmp/work","provider":"anthropic"}"#),
            in: context(manager: manager))
        let modelOnly = try await SpawnAgentTool().execute(
            ToolArgs(raw: #"{"name":"b","path":"/tmp/work","model":"opus"}"#),
            in: context(manager: manager))

        XCTAssertEqual(providerOnly.text, "error: provider and model must be supplied together")
        XCTAssertEqual(modelOnly.text, "error: provider and model must be supplied together")
        let calls = await manager.recordedCalls()
        XCTAssertTrue(calls.isEmpty)
    }

    func testDescriptorDocumentsPoolSelectionAndNoParentInheritance() {
        let description = SpawnAgentTool.descriptor.description
        XCTAssertTrue(description.contains("unused compatible binding from the team worker pool"))
        XCTAssertTrue(description.contains("parent model is never inherited"))

        guard case .object(let schema) = SpawnAgentTool.descriptor.parameters,
              case .object(let properties)? = schema["properties"] else {
            return XCTFail("spawn_agent must expose an object properties schema")
        }
        XCTAssertNotNil(properties["provider"])
        XCTAssertNotNil(properties["model"])
    }

    private func context(manager: AgentManager) -> ToolContext {
        ToolContext(
            workspaceRoot: FileManager.default.temporaryDirectory,
            agentManager: manager)
    }
}
