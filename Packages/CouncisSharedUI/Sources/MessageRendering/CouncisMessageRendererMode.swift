import Foundation
import CouncisCore

/// Product-level renderer selection. Rich rendering is a disposable projection;
/// `plainSafe` always renders the raw message without entering a Markdown engine.
public enum CouncisMessageRendererMode: String, CaseIterable, Sendable {
    case microsoft
    case plainSafe

    public static let defaultsKey = "councis.messageRendering.mode.v1"
    public static let plainSafeLaunchArgument = "-CouncisPlainSafeMessages"
    public static let microsoftLaunchArgument = "-CouncisMicrosoftMarkdownMessages"
    public static let legacyRichLaunchArgument = "-CouncisRichTextMessages"

    public static func launchOverride(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Self? {
        // Fail safe if contradictory arguments are supplied.
        if arguments.contains(plainSafeLaunchArgument) {
            return .plainSafe
        }
        if arguments.contains(
            LegacyIntatisCompatibility.LaunchArgument.plainSafeMessages) {
            return .plainSafe
        }
        if arguments.contains(microsoftLaunchArgument)
            || arguments.contains(legacyRichLaunchArgument)
            || arguments.contains(
                LegacyIntatisCompatibility.LaunchArgument
                    .microsoftMarkdownMessages)
            || arguments.contains(
                LegacyIntatisCompatibility.LaunchArgument.richTextMessages) {
            return .microsoft
        }
        return nil
    }

    public static func resolve(
        persistedRawValue: String?,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Self {
        if let launchOverride = launchOverride(arguments: arguments) {
            return launchOverride
        }
        // `rich` was the Phase 0 name for the legacy implementation. Preserve
        // the user's intent while moving the implementation to the upstream
        // renderer; no session data or message schema changes.
        if persistedRawValue == "rich" {
            return .microsoft
        }
        guard let persistedRawValue else { return .microsoft }
        return Self(rawValue: persistedRawValue) ?? .plainSafe
    }
}

/// Pure routing result shared by the first paint and asynchronous render task.
/// It deliberately contains no Markdown types or parsing logic.
public struct CouncisMessageRenderPlan: Equatable, Sendable {
    public let displayText: String
    public let usesRichRenderer: Bool

    /// A previously parsed document must never cover a newer streaming snapshot.
    public func acceptsRichDocument(rawText: String) -> Bool {
        usesRichRenderer && rawText == displayText
    }

    public static func resolve(
        rawText: String,
        isComplete: Bool,
        policyIsRich: Bool,
        rendererMode: CouncisMessageRendererMode
    ) -> Self {
        let displayText = rawText.isEmpty && !isComplete ? "…" : rawText
        return Self(
            displayText: displayText,
            usesRichRenderer: policyIsRich && rendererMode == .microsoft)
    }
}
