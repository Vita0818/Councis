import XCTest
@testable import CouncisMCP

final class MCPProductBrandCompatibilityTests: XCTestCase {
    func testLegacyUserProvenanceDecodesAndNewEncodingUsesCouncis() throws {
        let decoded = try JSONDecoder().decode(
            MCPConfigurationSourceKind.self,
            from: Data(#""intatis_user""#.utf8))
        XCTAssertEqual(decoded, .councisUser)
        XCTAssertEqual(
            String(
                data: try JSONEncoder().encode(decoded),
                encoding: .utf8),
            #""councis_user""#)
    }
}
