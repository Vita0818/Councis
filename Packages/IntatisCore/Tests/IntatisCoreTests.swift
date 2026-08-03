import XCTest
@testable import IntatisCore

final class IntatisCoreTests: XCTestCase {

    func testProfilePresets() {
        XCTAssertFalse(PlatformProfile.macAppStore.allowsShell)
        XCTAssertTrue(PlatformProfile.macDeveloperID.allowsShell)
        XCTAssertFalse(PlatformProfile.iOS.allowsWorkspace)
        XCTAssertEqual(PlatformProfile.iOS.surfaces, [.chat])
        XCTAssertTrue(PlatformProfile.macAppStore.supports(.cowork))
        XCTAssertFalse(PlatformProfile.iOS.supports(.code))
    }

    func testIDCodesAsBareString() throws {
        let id = SessionID(rawValue: "sess_test")
        let data = try JSONEncoder().encode(id)
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"sess_test\"")
        let back = try JSONDecoder().decode(SessionID.self, from: data)
        XCTAssertEqual(back, id)
    }

    func testIDGenPrefixAndUniqueness() {
        XCTAssertTrue(SessionID.new().rawValue.hasPrefix("sess_"))
        XCTAssertNotEqual(MessageID.new(), MessageID.new())
    }

    func testSessionKindWorkspace() {
        XCTAssertFalse(SessionKind.chat.usesWorkspace)
        XCTAssertTrue(SessionKind.code.usesWorkspace)
        XCTAssertTrue(SessionKind.cowork.usesWorkspace)
    }

    func testAgentModelBindingValidatesNormalizesAndRoundTrips() throws {
        let binding = try AgentModelBinding(
            validatingProviderID: "  provider-a  ",
            modelID: ModelID(rawValue: "  vendor/model-a  "))

        XCTAssertEqual(binding.providerID, "provider-a")
        XCTAssertEqual(binding.modelID, ModelID(rawValue: "vendor/model-a"))
        XCTAssertTrue(binding.isResolved)

        let data = try JSONEncoder().encode(binding)
        XCTAssertEqual(try JSONDecoder().decode(AgentModelBinding.self, from: data), binding)
    }

    func testAgentModelBindingRejectsEmptyIdentifiersIncludingDuringDecode() {
        XCTAssertThrowsError(try AgentModelBinding(
            validatingProviderID: " \n ",
            modelID: ModelID(rawValue: "model")))
        XCTAssertThrowsError(try AgentModelBinding(
            validatingProviderID: "provider",
            modelID: ModelID(rawValue: " \t ")))

        let invalidJSON = Data(#"{"providerID":"provider","modelID":" "}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(AgentModelBinding.self, from: invalidJSON))
    }

    func testAgentModelBindingHashIncludesProviderAndModel() {
        let first = AgentModelBinding(
            providerID: "provider-a",
            modelID: ModelID(rawValue: "model"))
        let differentProvider = AgentModelBinding(
            providerID: "provider-b",
            modelID: ModelID(rawValue: "model"))
        let differentModel = AgentModelBinding(
            providerID: "provider-a",
            modelID: ModelID(rawValue: "other"))

        XCTAssertEqual(Set([first, first, differentProvider, differentModel]).count, 3)
        XCTAssertFalse(AgentModelBinding(
            providerID: AgentModelBinding.unresolvedLegacyProviderID,
            modelID: ModelID(rawValue: "model")).isResolved)
    }
}
