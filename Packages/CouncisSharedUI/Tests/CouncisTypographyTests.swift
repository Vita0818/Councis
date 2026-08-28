#if canImport(SwiftUI)
import CoreText
import CryptoKit
import Foundation
import XCTest
@testable import CouncisSharedUI

final class CouncisTypographyTests: XCTestCase {
    func testSharedTypographyRolesKeepTheCrossPlatformDesignContract() {
        let expected: [CouncisTypographyRole: CouncisTypographySpec] = [
            .brand: CouncisTypographySpec(
                nominalPointSize: 28,
                weight: .semibold,
                design: .jetBrainsMono),
            .largeTitle: CouncisTypographySpec(
                nominalPointSize: 30,
                weight: .semibold,
                design: .jetBrainsMono),
            .title: CouncisTypographySpec(
                nominalPointSize: 20,
                weight: .semibold,
                design: .jetBrainsMono),
            .headline: CouncisTypographySpec(
                nominalPointSize: 16,
                weight: .semibold,
                design: .jetBrainsMono),
            .body: CouncisTypographySpec(
                nominalPointSize: 14,
                weight: .regular,
                design: .jetBrainsMono),
            .caption: CouncisTypographySpec(
                nominalPointSize: 12,
                weight: .medium,
                design: .jetBrainsMono),
            .metadata: CouncisTypographySpec(
                nominalPointSize: 10,
                weight: .medium,
                design: .jetBrainsMono),
            .monospaced: CouncisTypographySpec(
                nominalPointSize: 13,
                weight: .regular,
                design: .jetBrainsMono),
            .chat: CouncisTypographySpec(
                nominalPointSize: 15,
                weight: .regular,
                design: .jetBrainsMono),
        ]

        XCTAssertEqual(Set(expected.keys), Set(CouncisTypographyRole.allCases))
        for role in CouncisTypographyRole.allCases {
            XCTAssertEqual(CouncisTypography.spec(for: role), expected[role])
        }
    }

    func testBundledJetBrainsMonoUsesPingFangForSimplifiedChinese() {
        CouncisTypography.prepareBundledFonts()
        let font = CouncisTypography.coreTextFont(
            size: 15,
            weight: .semibold,
            italic: false)

        XCTAssertEqual(
            CTFontCopyPostScriptName(font) as String,
            "JetBrainsMono-SemiBold")
        XCTAssertEqual(
            CTFontCopyFamilyName(font) as String,
            CouncisTypography.latinFamilyName)
        XCTAssertEqual(
            resolvedFamily(for: "English", in: font),
            CouncisTypography.latinFamilyName)
        XCTAssertEqual(
            resolvedFamily(for: "中文", in: font),
            CouncisTypography.simplifiedChineseFallbackFamilyName)

        let italic = CouncisTypography.coreTextFont(
            size: 15,
            weight: .bold,
            italic: true)
        XCTAssertEqual(
            CTFontCopyPostScriptName(italic) as String,
            "JetBrainsMono-BoldItalic")
        XCTAssertEqual(resolvedFamily(for: "中文", in: italic), "PingFang SC")
    }

    func testBundledJetBrainsMonoInventoryMatchesPinnedRelease() throws {
        let expected: [String: String] = [
            "JetBrainsMono-Bold.ttf": "5590990c82e097397517f275f430af4546e1c45cff408bde4255dad142479dcb",
            "JetBrainsMono-BoldItalic.ttf": "4039d5ce0ed225bf9c8b2c8c6436290ae2f356b7e90d70fa666227238324aa3b",
            "JetBrainsMono-ExtraBold.ttf": "8e501d3a6a883e83ea4f7852804fb0894cebdd67751bb1006b37a476cef34cd6",
            "JetBrainsMono-ExtraBoldItalic.ttf": "ec3a860fa87d0a3b1451277d1c2f3072f5ba19d2367aec54f7169d5710872610",
            "JetBrainsMono-ExtraLight.ttf": "8391e7ec13e8ba758c1838f56bccd973228ccf4dc74aa5bffe9525b9147b12f8",
            "JetBrainsMono-ExtraLightItalic.ttf": "3c7fee57538f18b61cc5f0784a8133fe5ee95feb41f633e8f6f7ef609e6207ec",
            "JetBrainsMono-Italic.ttf": "9d0a1f7a708e6af183f1193b7e81d40da294f5c67682c085d8401c60aac8ded4",
            "JetBrainsMono-Light.ttf": "60c18d7dd58d81b3bbd12e8ce32744a8771bfe2b5280574082b0eaed46c60d24",
            "JetBrainsMono-LightItalic.ttf": "18ffadb91fa711b45feae027ddfd561e7f97ace805ec4baf9905046cf450befb",
            "JetBrainsMono-Medium.ttf": "31c92d01a8a08528b718a43addf0ad3df0af2ca4b7b3290a452f70f358e14d3d",
            "JetBrainsMono-MediumItalic.ttf": "4477fda6bd472ef96b11bc1083370f7fc3ff427bdc807e682ced5819e3dee9df",
            "JetBrainsMono-Regular.ttf": "a0bf60ef0f83c5ed4d7a75d45838548b1f6873372dfac88f71804491898d138f",
            "JetBrainsMono-SemiBold.ttf": "1b3bfa1ed5665a4ce3f9feb68d2d4e40e70bf8b4b7d9a3edd418f321b4e166a0",
            "JetBrainsMono-SemiBoldItalic.ttf": "3b3000507a7285872395ddbb4e53a28f07910dbf494fb0d5e1421dd60b5d8436",
            "JetBrainsMono-Thin.ttf": "0756e8e8cf1d65fa7519776764479b3973efb15af4f419d5d7274dc27ae1b702",
            "JetBrainsMono-ThinItalic.ttf": "ebcdd13119b6beb7457e2f76b31094cb8cf1108e567030f8402b24dde018e76a",
            "OFL.txt": "30f0c136e3c88e422d0791acd97238870f9054a9729bc34cf2ff0d4ed8cac4ad",
        ]

        XCTAssertEqual(CouncisTypography.bundledFontVersion, "2.304")
        XCTAssertEqual(
            Set(CouncisTypography.bundledFontFileNames),
            Set(expected.keys).union(["SHA256SUMS"]))
        for (fileName, digest) in expected {
            let url = try XCTUnwrap(
                CouncisTypography.bundledFontResourceURL(named: fileName))
            XCTAssertEqual(sha256(try Data(contentsOf: url)), digest, fileName)
        }

        let sumsURL = try XCTUnwrap(
            CouncisTypography.bundledFontResourceURL(named: "SHA256SUMS"))
        let sums = try String(contentsOf: sumsURL, encoding: .utf8)
        for (fileName, digest) in expected {
            XCTAssertTrue(
                sums.contains("\(digest)  \(fileName)"),
                "SHA256SUMS is missing \(fileName)")
        }
    }

    func testProductSwiftUISourcesDoNotBypassSharedTypography() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let roots = [
            repositoryRoot.appendingPathComponent("Apps/CouncisMac/Sources"),
            repositoryRoot.appendingPathComponent(
                "Packages/CouncisSharedUI/Sources"),
        ]
        let forbidden = [
            ".font(.system(",
            ".font(.largeTitle",
            ".font(.title",
            ".font(.headline",
            ".font(.subheadline",
            ".font(.body",
            ".font(.callout",
            ".font(.footnote",
            ".font(.caption",
            "Font.system(",
            ".fontDesign(",
            ".monospaced()",
            "NSFont.systemFont(",
            "UIFont.systemFont(",
            ".monospacedSystemFont(",
        ]

        for root in roots {
            let enumerator = try XCTUnwrap(
                FileManager.default.enumerator(
                    at: root,
                    includingPropertiesForKeys: nil))
            for case let url as URL in enumerator where url.pathExtension == "swift" {
                let source = try String(contentsOf: url, encoding: .utf8)
                let compact = source.filter { !$0.isWhitespace }
                for token in forbidden {
                    XCTAssertFalse(
                        compact.contains(token),
                        "\(url.path) bypasses CouncisTypography with \(token)")
                }
            }
        }
    }

    private func resolvedFamily(for text: String, in font: CTFont) -> String {
        let length = (text as NSString).length
        let resolved = CTFontCreateForString(
            font,
            text as CFString,
            CFRange(location: 0, length: length))
        return CTFontCopyFamilyName(resolved) as String
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
#endif
