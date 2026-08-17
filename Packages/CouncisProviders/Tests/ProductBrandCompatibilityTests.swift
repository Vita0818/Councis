import XCTest
@testable import CouncisProviders

final class ProductBrandCompatibilityTests: XCTestCase {
    func testLegacyProviderAdaptersNormalizeToCouncisWriters() throws {
        let pairs = [
            ("intatis:siliconflow-v1", "councis:siliconflow-v1"),
            ("intatis:cohere-v2", "councis:cohere-v2"),
            ("intatis:legacy-openai-wire", "councis:legacy-openai-wire"),
        ]

        for (legacy, current) in pairs {
            let decoded = try JSONDecoder().decode(
                ProviderRequestAdapter.self,
                from: Data("\"\(legacy)\"".utf8))
            XCTAssertEqual(decoded.rawValue, current)
            XCTAssertEqual(
                String(
                    data: try JSONEncoder().encode(decoded),
                    encoding: .utf8),
                "\"\(current)\"")
        }
    }
}
