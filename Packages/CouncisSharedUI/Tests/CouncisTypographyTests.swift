#if canImport(SwiftUI)
import XCTest
@testable import CouncisSharedUI

final class CouncisTypographyTests: XCTestCase {
    func testSharedTypographyRolesKeepTheCrossPlatformDesignContract() {
        let expected: [CouncisTypographyRole: CouncisTypographySpec] = [
            .brand: CouncisTypographySpec(
                nominalPointSize: 28,
                weight: .semibold,
                design: .serif),
            .largeTitle: CouncisTypographySpec(
                nominalPointSize: 30,
                weight: .semibold,
                design: .serif),
            .title: CouncisTypographySpec(
                nominalPointSize: 20,
                weight: .semibold,
                design: .serif),
            .headline: CouncisTypographySpec(
                nominalPointSize: 16,
                weight: .semibold,
                design: .sansSerif),
            .body: CouncisTypographySpec(
                nominalPointSize: 14,
                weight: .regular,
                design: .sansSerif),
            .caption: CouncisTypographySpec(
                nominalPointSize: 12,
                weight: .medium,
                design: .sansSerif),
            .metadata: CouncisTypographySpec(
                nominalPointSize: 10,
                weight: .medium,
                design: .sansSerif),
            .monospaced: CouncisTypographySpec(
                nominalPointSize: 13,
                weight: .regular,
                design: .monospaced),
            .chat: CouncisTypographySpec(
                nominalPointSize: 15,
                weight: .regular,
                design: .sansSerif),
        ]

        XCTAssertEqual(Set(expected.keys), Set(CouncisTypographyRole.allCases))
        for role in CouncisTypographyRole.allCases {
            XCTAssertEqual(CouncisTypography.spec(for: role), expected[role])
        }
    }
}
#endif
