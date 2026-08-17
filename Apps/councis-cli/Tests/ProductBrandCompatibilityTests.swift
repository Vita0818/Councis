import Foundation
import XCTest
@testable import CouncisCLI

final class CLIProductBrandCompatibilityTests: XCTestCase {
    func testLegacyEnvironmentCanBridgeButCurrentEnvironmentWins() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "councis-brand-config-\(UUID().uuidString)",
                isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true)
        let file = root.appendingPathComponent("councis.json")
        let data = Data(#"""
        {
          "model": "route/base",
          "judge_model": "route/base",
          "permission_reviewer_model": "route/base",
          "provider": {
            "route": {
              "npm": "@ai-sdk/openai-compatible",
              "options": { "baseURL": "https://example.invalid/v1" },
              "models": {
                "base": { "name": "Base" },
                "legacy": { "name": "Legacy" },
                "current": { "name": "Current" }
              }
            }
          }
        }
        """#.utf8)
        try data.write(to: file)

        let legacy = try CLIConfig.load(
            configurationFileURL: file,
            environment: ["INTATIS_MODEL": "route/legacy"])
        XCTAssertEqual(legacy.model, "legacy")

        let current = try CLIConfig.load(
            configurationFileURL: file,
            environment: [
                "INTATIS_MODEL": "route/legacy",
                "COUNCIS_MODEL": "route/current",
            ])
        XCTAssertEqual(current.model, "current")
    }
}
