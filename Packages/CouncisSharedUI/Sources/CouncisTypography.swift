#if canImport(SwiftUI)
import CoreText
import Foundation
import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Cross-platform typography roles shared by every Councis Apple surface.
///
/// Latin text is always sourced from the exact bundled JetBrains Mono files.
/// Simplified Chinese is explicitly cascaded to PingFang SC at the matching
/// weight. Formula glyphs are not created here: the Markdown renderer keeps
/// LaTeX in iosMath and therefore retains its independent math typeface.
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
        /// Legacy values remain source-compatible for downstream consumers.
        case sansSerif
        case serif
        case monospaced
        case jetBrainsMono
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

/// Semantic SwiftUI styles that preserve the current nominal platform sizes
/// while selecting Councis's bundled typeface instead of an Apple system face.
public enum CouncisSemanticTextStyle: String, CaseIterable, Hashable, Sendable {
    case largeTitle
    case title
    case title2
    case title3
    case headline
    case subheadline
    case body
    case callout
    case footnote
    case caption
    case caption2

    fileprivate var defaultWeight: Font.Weight {
        switch self {
        case .headline:
            return .bold
        case .caption2:
            return .medium
        default:
            return .regular
        }
    }

    fileprivate var preferredPointSize: CGFloat {
        #if canImport(AppKit)
        let textStyle: NSFont.TextStyle = switch self {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .body: .body
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        }
        return NSFont.preferredFont(forTextStyle: textStyle).pointSize
        #elseif canImport(UIKit)
        let textStyle: UIFont.TextStyle = switch self {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .body: .body
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        }
        return UIFont.preferredFont(forTextStyle: textStyle).pointSize
        #else
        return switch self {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline, .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        }
        #endif
    }
}

public enum CouncisTypography {
    public static let bundledFontVersion = "2.304"
    public static let latinFamilyName = "JetBrains Mono"
    public static let simplifiedChineseFallbackFamilyName = "PingFang SC"

    public static func spec(for role: CouncisTypographyRole) -> CouncisTypographySpec {
        switch role {
        case .brand:
            return CouncisTypographySpec(
                nominalPointSize: 28,
                weight: .semibold,
                design: .jetBrainsMono)
        case .largeTitle:
            return CouncisTypographySpec(
                nominalPointSize: 30,
                weight: .semibold,
                design: .jetBrainsMono)
        case .title:
            return CouncisTypographySpec(
                nominalPointSize: 20,
                weight: .semibold,
                design: .jetBrainsMono)
        case .headline:
            return CouncisTypographySpec(
                nominalPointSize: 16,
                weight: .semibold,
                design: .jetBrainsMono)
        case .body:
            return CouncisTypographySpec(
                nominalPointSize: 14,
                weight: .regular,
                design: .jetBrainsMono)
        case .caption:
            return CouncisTypographySpec(
                nominalPointSize: 12,
                weight: .medium,
                design: .jetBrainsMono)
        case .metadata:
            return CouncisTypographySpec(
                nominalPointSize: 10,
                weight: .medium,
                design: .jetBrainsMono)
        case .monospaced:
            return CouncisTypographySpec(
                nominalPointSize: 13,
                weight: .regular,
                design: .jetBrainsMono)
        case .chat:
            return CouncisTypographySpec(
                nominalPointSize: 15,
                weight: .regular,
                design: .jetBrainsMono)
        }
    }

    /// Eagerly validates all bundled font descriptors and the PingFang SC
    /// cascade. A missing or substituted resource is an explicit launch error,
    /// not a silent fallback to a different Latin family.
    public static func prepareBundledFonts() {
        CouncisBundledFontStore.prepare()
    }

    public static func font(
        for role: CouncisTypographyRole,
        size: CGFloat? = nil,
        weight: Font.Weight? = nil
    ) -> Font {
        let spec = spec(for: role)
        return fixed(
            size ?? spec.nominalPointSize,
            weight: weight ?? spec.weight.swiftUIWeight)
    }

    public static func semantic(
        _ style: CouncisSemanticTextStyle,
        weight: Font.Weight? = nil
    ) -> Font {
        fixed(
            style.preferredPointSize,
            weight: weight ?? style.defaultWeight)
    }

    public static func fixed(
        _ size: CGFloat,
        weight: Font.Weight = .regular
    ) -> Font {
        Font(coreTextFont(size: size, weight: weight, italic: false))
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

    static func coreTextFont(
        size: CGFloat,
        weight: Font.Weight,
        italic: Bool
    ) -> CTFont {
        CouncisBundledFontStore.font(
            face: CouncisBundledFontFace(weight: weight, italic: italic),
            size: size)
    }

    #if canImport(AppKit)
    static func platformFont(
        size: CGFloat,
        weight: Font.Weight,
        italic: Bool = false
    ) -> NSFont {
        coreTextFont(size: size, weight: weight, italic: italic) as NSFont
    }
    #elseif canImport(UIKit)
    static func platformFont(
        size: CGFloat,
        weight: Font.Weight,
        italic: Bool = false
    ) -> UIFont {
        coreTextFont(size: size, weight: weight, italic: italic) as UIFont
    }
    #endif

    static var bundledFontFileNames: [String] {
        CouncisBundledFontFace.allCases.map(\.fileName)
            + ["OFL.txt", "SHA256SUMS"]
    }

    static func bundledFontResourceURL(named fileName: String) -> URL? {
        let url = URL(fileURLWithPath: fileName)
        let baseName = url.deletingPathExtension().lastPathComponent
        let fileExtension = url.pathExtension
        return Bundle.module.url(
            forResource: baseName,
            withExtension: fileExtension.isEmpty ? nil : fileExtension,
            subdirectory: "Fonts")
    }
}

private enum CouncisBundledFontFace: String, CaseIterable {
    case thin
    case thinItalic
    case extraLight
    case extraLightItalic
    case light
    case lightItalic
    case regular
    case italic
    case medium
    case mediumItalic
    case semibold
    case semiboldItalic
    case bold
    case boldItalic
    case extraBold
    case extraBoldItalic

    init(weight: Font.Weight, italic: Bool) {
        let upright: CouncisBundledFontFace
        if weight == .ultraLight {
            upright = .thin
        } else if weight == .thin {
            upright = .extraLight
        } else if weight == .light {
            upright = .light
        } else if weight == .medium {
            upright = .medium
        } else if weight == .semibold {
            upright = .semibold
        } else if weight == .bold {
            upright = .bold
        } else if weight == .heavy || weight == .black {
            upright = .extraBold
        } else {
            upright = .regular
        }

        guard italic else {
            self = upright
            return
        }
        self = switch upright {
        case .thin: .thinItalic
        case .extraLight: .extraLightItalic
        case .light: .lightItalic
        case .regular: .italic
        case .medium: .mediumItalic
        case .semibold: .semiboldItalic
        case .bold: .boldItalic
        case .extraBold: .extraBoldItalic
        case .thinItalic, .extraLightItalic, .lightItalic, .italic,
             .mediumItalic, .semiboldItalic, .boldItalic, .extraBoldItalic:
            upright
        }
    }

    var fileName: String {
        "\(postScriptName).ttf"
    }

    var postScriptName: String {
        switch self {
        case .thin: "JetBrainsMono-Thin"
        case .thinItalic: "JetBrainsMono-ThinItalic"
        case .extraLight: "JetBrainsMono-ExtraLight"
        case .extraLightItalic: "JetBrainsMono-ExtraLightItalic"
        case .light: "JetBrainsMono-Light"
        case .lightItalic: "JetBrainsMono-LightItalic"
        case .regular: "JetBrainsMono-Regular"
        case .italic: "JetBrainsMono-Italic"
        case .medium: "JetBrainsMono-Medium"
        case .mediumItalic: "JetBrainsMono-MediumItalic"
        case .semibold: "JetBrainsMono-SemiBold"
        case .semiboldItalic: "JetBrainsMono-SemiBoldItalic"
        case .bold: "JetBrainsMono-Bold"
        case .boldItalic: "JetBrainsMono-BoldItalic"
        case .extraBold: "JetBrainsMono-ExtraBold"
        case .extraBoldItalic: "JetBrainsMono-ExtraBoldItalic"
        }
    }

    var pingFangPostScriptName: String {
        switch self {
        case .thin, .thinItalic:
            return "PingFangSC-Ultralight"
        case .extraLight, .extraLightItalic:
            return "PingFangSC-Thin"
        case .light, .lightItalic:
            return "PingFangSC-Light"
        case .regular, .italic:
            return "PingFangSC-Regular"
        case .medium, .mediumItalic:
            return "PingFangSC-Medium"
        case .semibold, .semiboldItalic, .bold, .boldItalic,
             .extraBold, .extraBoldItalic:
            return "PingFangSC-Semibold"
        }
    }
}

private final class CouncisCTFontBox: NSObject {
    let font: CTFont

    init(_ font: CTFont) {
        self.font = font
    }
}

private enum CouncisBundledFontStore {
    private static let descriptors: [CouncisBundledFontFace: CTFontDescriptor] = {
        var result: [CouncisBundledFontFace: CTFontDescriptor] = [:]
        for face in CouncisBundledFontFace.allCases {
            guard let url = CouncisTypography.bundledFontResourceURL(
                named: face.fileName)
            else {
                fatalError("Missing bundled JetBrains Mono resource: \(face.fileName)")
            }
            guard let candidates = CTFontManagerCreateFontDescriptorsFromURL(
                url as CFURL) as? [CTFontDescriptor],
                candidates.count == 1,
                let descriptor = candidates.first
            else {
                fatalError("Unreadable bundled JetBrains Mono resource: \(face.fileName)")
            }
            let validationFont = CTFontCreateWithFontDescriptor(
                descriptor,
                13,
                nil)
            guard CTFontCopyPostScriptName(validationFont) as String
                    == face.postScriptName,
                  CTFontCopyFamilyName(validationFont) as String
                    == CouncisTypography.latinFamilyName
            else {
                fatalError("Unexpected bundled font identity: \(face.fileName)")
            }
            result[face] = descriptor
        }
        return result
    }()

    private static let cache = NSCache<NSString, CouncisCTFontBox>()

    static func prepare() {
        _ = descriptors
        for face in CouncisBundledFontFace.allCases {
            _ = font(face: face, size: 13)
        }
    }

    static func font(
        face: CouncisBundledFontFace,
        size: CGFloat
    ) -> CTFont {
        guard size.isFinite, size > 0 else {
            fatalError("Councis typography requires a finite positive point size")
        }
        let key = NSString(
            string: "\(face.rawValue):\(Double(size).bitPattern)")
        if let cached = cache.object(forKey: key) {
            return cached.font
        }
        guard let baseDescriptor = descriptors[face] else {
            fatalError("Missing bundled JetBrains Mono descriptor: \(face.fileName)")
        }

        let pingFang = CTFontCreateWithName(
            face.pingFangPostScriptName as CFString,
            size,
            nil)
        guard CTFontCopyPostScriptName(pingFang) as String
                == face.pingFangPostScriptName,
              CTFontCopyFamilyName(pingFang) as String
                == CouncisTypography.simplifiedChineseFallbackFamilyName
        else {
            fatalError("Required PingFang SC fallback is unavailable")
        }
        let cascadeAttributes: [CFString: Any] = [
            kCTFontCascadeListAttribute: [CTFontCopyFontDescriptor(pingFang)],
        ]
        let cascadedDescriptor = CTFontDescriptorCreateCopyWithAttributes(
            baseDescriptor,
            cascadeAttributes as CFDictionary)
        let font = CTFontCreateWithFontDescriptor(
            cascadedDescriptor,
            size,
            nil)
        guard CTFontCopyPostScriptName(font) as String == face.postScriptName,
              CTFontCopyFamilyName(font) as String
                == CouncisTypography.latinFamilyName
        else {
            fatalError("Bundled JetBrains Mono could not be instantiated")
        }
        cache.setObject(CouncisCTFontBox(font), forKey: key)
        return font
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

/// Drop-in semantic names used by existing SwiftUI call sites. Keeping the
/// replacement on `Font` makes the migration mechanical and prevents a view
/// from accidentally opting back into an Apple Latin system face.
public extension Font {
    static var councisLargeTitle: Font {
        CouncisTypography.semantic(.largeTitle)
    }

    static var councisTitle: Font {
        CouncisTypography.semantic(.title)
    }

    static var councisTitle2: Font {
        CouncisTypography.semantic(.title2)
    }

    static var councisTitle3: Font {
        CouncisTypography.semantic(.title3)
    }

    static var councisHeadline: Font {
        CouncisTypography.semantic(.headline)
    }

    static var councisSubheadline: Font {
        CouncisTypography.semantic(.subheadline)
    }

    static var councisBody: Font {
        CouncisTypography.semantic(.body)
    }

    static var councisCallout: Font {
        CouncisTypography.semantic(.callout)
    }

    static var councisFootnote: Font {
        CouncisTypography.semantic(.footnote)
    }

    static var councisCaption: Font {
        CouncisTypography.semantic(.caption)
    }

    static var councisCaption2: Font {
        CouncisTypography.semantic(.caption2)
    }

    static func councisFixed(
        size: CGFloat,
        weight: Font.Weight = .regular
    ) -> Font {
        CouncisTypography.fixed(size, weight: weight)
    }
}
#endif
