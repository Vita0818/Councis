import XCTest
@testable import CouncisSharedUI

final class MessageRendererModeTests: XCTestCase {
    func testDefaultsToMicrosoftWhenNoPreferenceExistsAfterCutover() {
        XCTAssertEqual(
            CouncisMessageRendererMode.resolve(
                persistedRawValue: nil,
                arguments: ["Councis"]),
            .microsoft)
    }

    func testPersistedPlainSafeModeIsPreserved() {
        XCTAssertEqual(
            CouncisMessageRendererMode.resolve(
                persistedRawValue: CouncisMessageRendererMode.plainSafe.rawValue,
                arguments: ["Councis"]),
            .plainSafe)
    }

    func testLaunchArgumentsOverridePersistedPreference() {
        XCTAssertEqual(
            CouncisMessageRendererMode.resolve(
                persistedRawValue: CouncisMessageRendererMode.microsoft.rawValue,
                arguments: ["Councis", CouncisMessageRendererMode.plainSafeLaunchArgument]),
            .plainSafe)
        XCTAssertEqual(
            CouncisMessageRendererMode.resolve(
                persistedRawValue: CouncisMessageRendererMode.plainSafe.rawValue,
                arguments: ["Councis", CouncisMessageRendererMode.microsoftLaunchArgument]),
            .microsoft)
    }

    func testPlainSafeWinsContradictoryLaunchArguments() {
        XCTAssertEqual(
            CouncisMessageRendererMode.resolve(
                persistedRawValue: nil,
                arguments: [
                    "Councis",
                    CouncisMessageRendererMode.microsoftLaunchArgument,
                    CouncisMessageRendererMode.plainSafeLaunchArgument,
                ]),
            .plainSafe)
    }

    func testUnknownPersistedValueFailsToPlainSafe() {
        XCTAssertEqual(
            CouncisMessageRendererMode.resolve(
                persistedRawValue: "future-value",
                arguments: ["Councis"]),
            .plainSafe)
    }

    func testLegacyRichPreferenceAndLaunchArgumentMigrateToMicrosoft() {
        XCTAssertEqual(
            CouncisMessageRendererMode.resolve(
                persistedRawValue: "rich",
                arguments: ["Councis"]),
            .microsoft)
        XCTAssertEqual(
            CouncisMessageRendererMode.resolve(
                persistedRawValue: CouncisMessageRendererMode.plainSafe.rawValue,
                arguments: ["Councis", CouncisMessageRendererMode.legacyRichLaunchArgument]),
            .microsoft)
    }

    func testPlainSafeRenderPlanPreservesRawTextAndLineEndings() {
        let raw = "  **first**\r\n| a | b |\r`$code$`\n公式 $x_i$ 与 \\$29.99  "
        let plan = CouncisMessageRenderPlan.resolve(
            rawText: raw,
            isComplete: true,
            policyIsRich: true,
            rendererMode: .plainSafe)

        XCTAssertEqual(plan.displayText, raw)
        XCTAssertEqual(Data(plan.displayText.utf8), Data(raw.utf8))
        XCTAssertFalse(plan.usesRichRenderer)
    }

    func testEmptyStreamingRenderPlanUsesPlaceholderWithoutRichWork() {
        let plan = CouncisMessageRenderPlan.resolve(
            rawText: "",
            isComplete: false,
            policyIsRich: true,
            rendererMode: .plainSafe)

        XCTAssertEqual(plan.displayText, "…")
        XCTAssertFalse(plan.usesRichRenderer)
    }

    func testCompletedEmptyMessageRemainsByteExactEmptyText() {
        let plan = CouncisMessageRenderPlan.resolve(
            rawText: "",
            isComplete: true,
            policyIsRich: true,
            rendererMode: .plainSafe)

        XCTAssertEqual(plan.displayText, "")
        XCTAssertFalse(plan.usesRichRenderer)
    }

    func testRichModeRoutesEligibleMessagesToRichRenderer() {
        let plan = CouncisMessageRenderPlan.resolve(
            rawText: "**assistant source**",
            isComplete: true,
            policyIsRich: true,
            rendererMode: .microsoft)

        XCTAssertEqual(plan.displayText, "**assistant source**")
        XCTAssertTrue(plan.usesRichRenderer)
        XCTAssertTrue(plan.acceptsRichDocument(rawText: "**assistant source**"))
        XCTAssertFalse(plan.acceptsRichDocument(rawText: "**older snapshot**"))
    }

    func testRolePolicyCanAlwaysForcePlainRendering() {
        let plan = CouncisMessageRenderPlan.resolve(
            rawText: "**user source**",
            isComplete: true,
            policyIsRich: false,
            rendererMode: .microsoft)

        XCTAssertEqual(plan.displayText, "**user source**")
        XCTAssertFalse(plan.usesRichRenderer)
    }
}
