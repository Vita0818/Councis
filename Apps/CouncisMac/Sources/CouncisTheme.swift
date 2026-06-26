#if canImport(SwiftUI)
import SwiftUI

enum CouncisTheme {
    static let accentBlue = Color(red: 0.235, green: 0.455, blue: 0.651)
    static let accentHighlight = Color(red: 0.357, green: 0.569, blue: 0.784)
    static let accentDeep = Color(red: 0.184, green: 0.373, blue: 0.529)
    static let accentPale = Color(red: 0.906, green: 0.941, blue: 0.973)
    static let darkAccent = Color(red: 0.498, green: 0.682, blue: 0.847)

    static func primaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.898, green: 0.925, blue: 0.949)
            : Color(red: 0.129, green: 0.153, blue: 0.176)
    }

    static func secondaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.620, green: 0.675, blue: 0.725)
            : Color(red: 0.392, green: 0.443, blue: 0.490)
    }

    static func tertiaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.431, green: 0.482, blue: 0.529)
            : Color(red: 0.573, green: 0.627, blue: 0.667)
    }

    static func glassSurface(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.071, green: 0.086, blue: 0.102)
            : .white
    }

    static func glassStroke(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.243, green: 0.373, blue: 0.490)
            : Color(red: 0.796, green: 0.863, blue: 0.922)
    }

    static func pageBackground(_ scheme: ColorScheme) -> LinearGradient {
        if scheme == .dark {
            return LinearGradient(
                colors: [
                    Color(red: 0.055, green: 0.067, blue: 0.078),
                    Color(red: 0.075, green: 0.094, blue: 0.110),
                    Color(red: 0.059, green: 0.075, blue: 0.086)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                Color(red: 0.980, green: 0.984, blue: 0.988),
                Color(red: 0.933, green: 0.957, blue: 0.976),
                Color(red: 0.988, green: 0.990, blue: 0.992)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accentHighlight, accentBlue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

enum CouncisType {
    static func brand(_ size: CGFloat = 28, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func title(_ size: CGFloat = 22, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func section(_ size: CGFloat = 17, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }

    static func body(_ size: CGFloat = 14, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func chat(_ size: CGFloat = 15, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func caption(_ size: CGFloat = 12, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight)
    }

    static func mono(_ size: CGFloat = 12, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

private struct CouncisGlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    let cornerRadius: CGFloat
    let fillOpacity: Double
    let strokeOpacity: Double
    let shadowOpacity: Double

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let fill = scheme == .dark ? min(fillOpacity * 0.72, 0.34) : fillOpacity
        let stroke = scheme == .dark ? min(strokeOpacity * 0.72, 0.30) : strokeOpacity

        content
            .background {
                shape.fill(CouncisTheme.glassSurface(scheme).opacity(fill))
            }
            .background(.ultraThinMaterial, in: shape)
            .overlay {
                shape.stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(stroke),
                            CouncisTheme.glassStroke(scheme).opacity(stroke),
                            CouncisTheme.accentBlue.opacity(scheme == .dark ? 0.16 : 0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .shadow(
                color: Color.black.opacity(scheme == .dark ? max(shadowOpacity * 0.45, 0.07) : shadowOpacity),
                radius: 14,
                x: 0,
                y: 8
            )
    }
}

private struct CouncisGlassCapsuleModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let shape = Capsule(style: .continuous)
        content
            .background {
                shape.fill(CouncisTheme.glassSurface(scheme).opacity(scheme == .dark ? 0.28 : 0.60))
            }
            .background(.ultraThinMaterial, in: shape)
            .overlay {
                shape.stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(scheme == .dark ? 0.12 : 0.65),
                            CouncisTheme.accentBlue.opacity(scheme == .dark ? 0.28 : 0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
    }
}

extension View {
    func councisGlassCard(cornerRadius: CGFloat = 18,
                          fillOpacity: Double = 0.58,
                          strokeOpacity: Double = 0.50,
                          shadowOpacity: Double = 0.08) -> some View {
        modifier(CouncisGlassCardModifier(
            cornerRadius: cornerRadius,
            fillOpacity: fillOpacity,
            strokeOpacity: strokeOpacity,
            shadowOpacity: shadowOpacity
        ))
    }

    func councisGlassCapsule() -> some View {
        modifier(CouncisGlassCapsuleModifier())
    }
}
#endif
