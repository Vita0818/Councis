import Foundation
import XCTest
@testable import CouncisMCP

final class SDKClientOnlySurfaceTests: XCTestCase {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testVendoredSDKContainsOnlyExternalClientSurface() throws {
        let vendor = repositoryRoot.appendingPathComponent("Vendor/MCPClientSDK")
        let sources = vendor.appendingPathComponent("Sources/MCP")
        let enumerator = try XCTUnwrap(
            FileManager.default.enumerator(
                at: sources,
                includingPropertiesForKeys: nil
            )
        )
        let swiftFiles = enumerator.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
        let combined = try swiftFiles
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")

        for forbidden in [
            "public actor Server",
            "HTTPServerTransport",
            "public actor InMemoryTransport",
            "public actor NetworkTransport",
            "public struct BearerTokenInfo",
            "public struct OAuthProtectedResourceServerMetadata",
            "MCPConformanceServer",
        ] {
            XCTAssertFalse(
                combined.contains(forbidden),
                "Client SDK unexpectedly exposes forbidden server surface: \(forbidden)"
            )
        }

        let transports = swiftFiles
            .filter { $0.path.contains("/Base/Transports/") }
            .map(\.lastPathComponent)
            .sorted()
        XCTAssertEqual(
            transports,
            [
                "HTTPClientTransport.swift",
                "HTTPClientWireConstants.swift",
                "StdioTransport.swift",
            ]
        )

        let manifest = try String(
            contentsOf: vendor.appendingPathComponent("Package.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(manifest.contains(".executableTarget"))
        XCTAssertFalse(manifest.contains("swift-nio"))
        XCTAssertFalse(manifest.contains("swift-docc"))
        XCTAssertEqual(
            manifest.components(separatedBy: ".library(name: \"MCP\"").count - 1,
            1
        )
    }

    func testResolvedGraphExcludesUpstreamServerOnlyDependencies() throws {
        let resolved = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Package.resolved"),
            encoding: .utf8
        )
        for identity in [
            "\"swift-nio\"",
            "\"swift-docc-plugin\"",
            "\"swift-docc-symbolkit\"",
            "\"swift-atomics\"",
            "\"swift-collections\"",
        ] {
            XCTAssertFalse(resolved.contains(identity))
        }
        for identity in [
            "\"eventsource\"",
            "\"swift-log\"",
            "\"swift-system\"",
        ] {
            XCTAssertTrue(resolved.contains(identity))
        }
    }

    func testProductTargetLinkageContainsOnlyDeveloperIDApp() throws {
        let project = try String(
            contentsOf: repositoryRoot.appendingPathComponent("project.yml"),
            encoding: .utf8
        )
        let developerID = try section(
            named: "  CouncisMac:",
            endingAt: "\nschemes:",
            in: project
        )

        XCTAssertTrue(developerID.contains("product: CouncisMCP"))
        XCTAssertTrue(developerID.contains("product: CouncisMCPStdio"))
        XCTAssertTrue(developerID.contains("PRODUCT_BUNDLE_IDENTIFIER: com.Vita0818.Councis"))
        XCTAssertFalse(project.contains("CouncisMacAppStore"))
        XCTAssertFalse(project.contains("CouncisiOS"))
        XCTAssertFalse(project.contains("COUNCIS_MAC_APP_STORE"))
    }

    private func section(
        named startMarker: String,
        endingAt endMarker: String,
        in text: String
    ) throws -> String {
        let start = try XCTUnwrap(text.range(of: startMarker))
        let suffix = text[start.lowerBound...]
        let end = try XCTUnwrap(suffix.range(of: endMarker))
        return String(suffix[..<end.lowerBound])
    }
}
