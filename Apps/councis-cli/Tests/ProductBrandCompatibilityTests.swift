import Foundation
import XCTest
@testable import CouncisCLI

final class CLIProductBrandCompatibilityTests: XCTestCase {
    func testIntatisEnvironmentDoesNotOverrideCouncisConfiguration() throws {
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

        let isolated = try CLIConfig.load(
            configurationFileURL: file,
            environment: ["INTATIS_MODEL": "route/legacy"])
        XCTAssertEqual(isolated.model, "base")

        let current = try CLIConfig.load(
            configurationFileURL: file,
            environment: [
                "INTATIS_MODEL": "route/legacy",
                "COUNCIS_MODEL": "route/current",
            ])
        XCTAssertEqual(current.model, "current")
        XCTAssertEqual(current.judgeModel.providerID, "route")
        XCTAssertEqual(current.judgeModel.modelID, "base")
    }

    func testIntatisConfigLocationsAreNotDiscovered() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "councis-config-isolation-\(UUID().uuidString)",
                isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let support = root.appendingPathComponent(
            "Application Support",
            isDirectory: true)
        let legacyUserConfig = root
            .appendingPathComponent(".config/intatis", isDirectory: true)
            .appendingPathComponent("intatis.json")
        let legacyAppConfig = support
            .appendingPathComponent("Intatis", isDirectory: true)
            .appendingPathComponent("intatis.json")
        for url in [legacyUserConfig, legacyAppConfig] {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try Data("{}".utf8).write(to: url)
        }

        XCTAssertNil(CLIModernProviderConfig.existingURL(
            environment: ["INTATIS_CONFIG": legacyUserConfig.path],
            homeDirectory: root,
            applicationSupportDirectory: support))

        let current = root
            .appendingPathComponent(".config/councis", isDirectory: true)
            .appendingPathComponent("councis.json")
        try FileManager.default.createDirectory(
            at: current.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: current)
        XCTAssertEqual(
            CLIModernProviderConfig.existingURL(
                environment: ["INTATIS_CONFIG": legacyUserConfig.path],
                homeDirectory: root,
                applicationSupportDirectory: support),
            current.standardizedFileURL)
    }
}
