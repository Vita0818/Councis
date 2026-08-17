#if canImport(SwiftUI)
import SwiftUI

/// Cross-platform typography roles shared by the macOS workbench and iOS Chat.
///
/// App views may scale the nominal point size with `@ScaledMetric`, but should
/// keep the role's weight and design so both platforms retain the same visual
/// voice: serif for brand/page titles, system sans for interface and message
/// text, and monospaced system text for technical values.
public enum CouncisTypographyRole: String, CaseIterable, Hashable, Sendable {
    case brand
    case largeTitle
    case title
    case headline
    case body
    case caption
    case metadata
    case monospaced
    case chat
}

public struct CouncisTypographySpec: Equatable, Sendable {
    public enum Design: String, Sendable {
        case sansSerif
        case serif
        case monospaced
    }

    public enum Weight: String, Sendable {
        case regular
        case medium
        case semibold
    }

    public let nominalPointSize: CGFloat
    public let weight: Weight
    public let design: Design

    public init(
        nominalPointSize: CGFloat,
        weight: Weight,
        design: Design
    ) {
        self.nominalPointSize = nominalPointSize
        self.weight = weight
        self.design = design
    }
}

public enum CouncisTypography {
    public static func spec(for role: CouncisTypographyRole) -> CouncisTypographySpec {
        switch role {
        case .brand:
            return CouncisTypographySpec(
                nominalPointSize: 28,
                weight: .semibold,
                design: .serif)
        case .largeTitle:
            return CouncisTypographySpec(
                nominalPointSize: 30,
                weight: .semibold,
                design: .serif)
        case .title:
            return CouncisTypographySpec(
                nominalPointSize: 20,
                weight: .semibold,
                design: .serif)
        case .headline:
            return CouncisTypographySpec(
                nominalPointSize: 16,
                weight: .semibold,
                design: .sansSerif)
        case .body:
            return CouncisTypographySpec(
                nominalPointSize: 14,
                weight: .regular,
                design: .sansSerif)
        case .caption:
            return CouncisTypographySpec(
                nominalPointSize: 12,
                weight: .medium,
                design: .sansSerif)
        case .metadata:
            return CouncisTypographySpec(
                nominalPointSize: 10,
                weight: .medium,
                design: .sansSerif)
        case .monospaced:
            return CouncisTypographySpec(
                nominalPointSize: 13,
                weight: .regular,
                design: .monospaced)
        case .chat:
            return CouncisTypographySpec(
                nominalPointSize: 15,
                weight: .regular,
                design: .sansSerif)
        }
    }

    public static func font(
        for role: CouncisTypographyRole,
        size: CGFloat? = nil,
        weight: Font.Weight? = nil
    ) -> Font {
        let spec = spec(for: role)
        return .system(
            size: size ?? spec.nominalPointSize,
            weight: weight ?? spec.weight.swiftUIWeight,
            design: spec.design.swiftUIDesign)
    }

    public static func brand(
        _ size: CGFloat? = nil,
        _ weight: Font.Weight? = nil
    ) -> Font {
        font(for: .brand, size: size, weight: weight)
    }

    public static func largeTitle(
        _ size: CGFloat? = nil,
        _ weight: Font.Weight? = nil
    ) -> Font {
        font(for: .largeTitle, size: size, weight: weight)
    }

    public static func title(
        _ size: CGFloat? = nil,
        _ weight: Font.Weight? = nil
    ) -> Font {
        font(for: .title, size: size, weight: weight)
    }

    public static func headline(
        _ size: CGFloat? = nil,
        _ weight: Font.Weight? = nil
    ) -> Font {
        font(for: .headline, size: size, weight: weight)
    }

    public static func body(
        _ size: CGFloat? = nil,
        _ weight: Font.Weight? = nil
    ) -> Font {
        font(for: .body, size: size, weight: weight)
    }

    public static func caption(
        _ size: CGFloat? = nil,
        _ weight: Font.Weight? = nil
    ) -> Font {
        font(for: .caption, size: size, weight: weight)
    }

    public static func metadata(
        _ size: CGFloat? = nil,
        _ weight: Font.Weight? = nil
    ) -> Font {
        font(for: .metadata, size: size, weight: weight)
    }

    public static func mono(
        _ size: CGFloat? = nil,
        _ weight: Font.Weight? = nil
    ) -> Font {
        font(for: .monospaced, size: size, weight: weight)
    }

    public static func chat(
        _ size: CGFloat? = nil,
        _ weight: Font.Weight? = nil
    ) -> Font {
        font(for: .chat, size: size, weight: weight)
    }
}

private extension CouncisTypographySpec.Design {
    var swiftUIDesign: Font.Design {
        switch self {
        case .sansSerif:
            return .default
        case .serif:
            return .serif
        case .monospaced:
            return .monospaced
        }
    }
}

private extension CouncisTypographySpec.Weight {
    var swiftUIWeight: Font.Weight {
        switch self {
        case .regular:
            return .regular
        case .medium:
            return .medium
        case .semibold:
            return .semibold
        }
    }
}
#endif
