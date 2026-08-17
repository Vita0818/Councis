import XCTest
@testable import CouncisCore

final class ProductIdentityTests: XCTestCase {
    func testCurrentIdentityUsesOnlyCouncisNamespace() {
        XCTAssertEqual(CouncisProductIdentity.productName, "Councis")
        XCTAssertEqual(
            CouncisProductIdentity.bundleIdentifier,
            "com.Vita0818.Councis")
        XCTAssertEqual(
            CouncisProductIdentity.applicationSupportDirectoryName,
            "Councis")
        XCTAssertEqual(
            CouncisProductIdentity.configurationFileName,
            "councis.json")
        XCTAssertFalse(
            CouncisProductIdentity.mcpKeychainService
                .localizedCaseInsensitiveContains("intatis"))
    }

    func testLegacyIdentityIsExplicitlyReadOnlyAndDistinct() {
        XCTAssertNotEqual(
            LegacyIntatisCompatibility.applicationSupportDirectoryName,
            CouncisProductIdentity.applicationSupportDirectoryName)
        XCTAssertNotEqual(
            LegacyIntatisCompatibility.mcpKeychainService,
            CouncisProductIdentity.mcpKeychainService)
        XCTAssertEqual(
            LegacyIntatisCompatibility.ProtocolIdentity
                .authorizationContextField,
            "__intatis_authorization_context")
    }
}
