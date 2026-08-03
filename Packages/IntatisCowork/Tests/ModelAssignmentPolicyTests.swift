import XCTest
import IntatisCore
import IntatisProviders
@testable import IntatisCowork

final class ModelAssignmentPolicyTests: XCTestCase {
    private let first = AgentModelBinding(
        providerID: "provider-a",
        modelID: ModelID(rawValue: "model-a"))
    private let second = AgentModelBinding(
        providerID: "provider-b",
        modelID: ModelID(rawValue: "model-b"))

    private func policy(onExhausted: ModelPoolExhaustionPolicy = .askUser) -> ModelAssignmentPolicy {
        ModelAssignmentPolicy(
            workerPool: [ModelPoolEntry(binding: first), ModelPoolEntry(binding: second)],
            allowedBindings: [first, second],
            onExhausted: onExhausted)
    }

    func testOmittedBindingUsesFirstUnusedCompatiblePoolEntry() throws {
        let assignment = try policy().resolve(
            providerID: nil,
            modelID: nil,
            parentBinding: first,
            occupiedBindings: [first])

        XCTAssertEqual(assignment.binding, second)
        XCTAssertEqual(assignment.source, .pool)
    }

    func testStrictPolicyNeverInheritsParentWhenPoolIsExhausted() {
        XCTAssertThrowsError(try policy().resolve(
            providerID: nil,
            modelID: nil,
            parentBinding: first,
            occupiedBindings: [first, second])) { error in
                XCTAssertEqual(error as? ModelAssignmentError, .poolExhausted(.askUser))
            }
    }

    func testExplicitBindingRequiresProviderAndModelTogether() {
        XCTAssertThrowsError(try policy().resolve(
            providerID: "provider-a",
            modelID: nil,
            parentBinding: nil,
            occupiedBindings: [])) { error in
                XCTAssertEqual(error as? ModelAssignmentError, .partialBinding)
            }
    }

    func testDuplicateFullBindingRejectedButSameModelOnDifferentProviderAllowed() throws {
        XCTAssertThrowsError(try policy().resolve(
            providerID: first.providerID,
            modelID: first.modelID.rawValue,
            parentBinding: nil,
            occupiedBindings: [first])) { error in
                XCTAssertEqual(error as? ModelAssignmentError, .bindingAlreadyInUse(self.first))
            }

        let sameModelElsewhere = AgentModelBinding(
            providerID: second.providerID,
            modelID: first.modelID)
        var expanded = policy()
        expanded.allowedBindings.append(sameModelElsewhere)
        let assignment = try expanded.resolve(
            providerID: sameModelElsewhere.providerID,
            modelID: sameModelElsewhere.modelID.rawValue,
            parentBinding: nil,
            occupiedBindings: [first])
        XCTAssertEqual(assignment.binding, sameModelElsewhere)
    }

    func testCapabilityMismatchIsRejected() {
        let chatOnly = ModelPoolEntry(binding: first, capabilities: [.chat])
        let policy = ModelAssignmentPolicy(
            workerPool: [chatOnly],
            allowedBindings: [first])

        XCTAssertThrowsError(try policy.resolve(
            providerID: first.providerID,
            modelID: first.modelID.rawValue,
            parentBinding: nil,
            occupiedBindings: [],
            requiredCapabilities: [.toolCalling])) { error in
                XCTAssertEqual(
                    error as? ModelAssignmentError,
                    .missingCapability(self.first, .toolCalling))
            }
    }
}
