import XCTest
import IntatisCore
import IntatisCowork
@testable import IntatisMacTeamSupport

final class CoworkTeamConfigurationTests: XCTestCase {
    func testReservedRoleIDsMatchCouncisRuntimeContract() {
        XCTAssertEqual(CoworkTeamConfiguration.mainAgentID.rawValue, "main")
        XCTAssertEqual(CoworkTeamConfiguration.judgeAgentID.rawValue, "judge")
    }

    func testDeriveFixesMainJudgeAndRemainingWorkers() throws {
        let main = binding("openai", "gpt-main")
        let judge = binding("anthropic", "judge-model")
        let workerA = binding("google", "worker-a")
        let workerB = binding("openai", "worker-b")

        let team = try CoworkTeamConfiguration.derive(
            availableBindings: [workerA, main, judge, workerB, workerA],
            preferredMain: main)

        XCTAssertEqual(team.mainBinding, main)
        XCTAssertEqual(team.judgeBinding, workerA)
        XCTAssertEqual(team.workerModelPool, [judge, workerB])
        XCTAssertEqual(team.strictModelAssignmentPolicy.allowedBindings, [main, workerA])
        XCTAssertEqual(team.strictModelAssignmentPolicy.workerPool.map(\.binding), [judge, workerB])
        XCTAssertEqual(team.strictModelAssignmentPolicy.fixedAgentBindings ?? [], [
            FixedAgentModelBinding(
                agentID: CoworkTeamConfiguration.mainAgentID,
                binding: main),
            FixedAgentModelBinding(
                agentID: CoworkTeamConfiguration.judgeAgentID,
                binding: workerA),
        ])
        XCTAssertTrue(team.strictModelAssignmentPolicy.uniquePerActiveAgent)
        XCTAssertFalse(team.strictModelAssignmentPolicy.inheritParentModel)
        XCTAssertEqual(team.strictModelAssignmentPolicy.onExhausted, .reject)
    }

    func testDeriveRejectsCatalogWithOnlyOneUniqueBinding() {
        let only = binding("openai", "only-model")
        XCTAssertThrowsError(try CoworkTeamConfiguration.derive(
            availableBindings: [only, only],
            preferredMain: only)) { error in
            XCTAssertEqual(
                error as? CoworkTeamConfigurationError,
                .insufficientUniqueBindings(configured: 1))
        }
    }

    func testValidationKeepsPersistedRolesFixed() throws {
        let main = binding("openai", "main")
        let judge = binding("anthropic", "judge")
        let worker = binding("google", "worker")
        let team = try CoworkTeamConfiguration(
            mainBinding: main,
            judgeBinding: judge,
            workerModelPool: [worker])

        XCTAssertEqual(
            try team.validated(availableBindings: [worker, judge, main]),
            team)
        XCTAssertThrowsError(try team.validated(availableBindings: [main, worker])) { error in
            XCTAssertEqual(
                error as? CoworkTeamConfigurationError,
                .configuredBindingUnavailable(role: "@judge", binding: judge))
        }
    }

    func testStrictPolicyAssignsUnusedWorkerThenRejectsExhaustion() throws {
        let main = binding("openai", "main")
        let judge = binding("anthropic", "judge")
        let worker = binding("google", "worker")
        let team = try CoworkTeamConfiguration(
            mainBinding: main,
            judgeBinding: judge,
            workerModelPool: [worker])

        let first = try team.strictModelAssignmentPolicy.resolve(
            providerID: nil,
            modelID: nil,
            parentBinding: nil,
            occupiedBindings: [main, judge])
        XCTAssertEqual(first.binding, worker)

        XCTAssertThrowsError(try team.strictModelAssignmentPolicy.resolve(
            providerID: nil,
            modelID: nil,
            parentBinding: nil,
            occupiedBindings: [main, judge, worker])) { error in
            XCTAssertEqual(
                error as? ModelAssignmentError,
                .poolExhausted(.reject))
        }
    }

    private func binding(_ provider: String, _ model: String) -> AgentModelBinding {
        AgentModelBinding(providerID: provider, modelID: ModelID(rawValue: model))
    }
}
