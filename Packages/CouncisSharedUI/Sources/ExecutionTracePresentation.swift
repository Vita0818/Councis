import Foundation
import CouncisConversation
import CouncisCore

/// Backend-only control for the verbose Code/Cowork execution transcript.
///
/// The EventLog and projections always retain the complete execution history.
/// This policy only decides which projected items reach the conversation UI.
public enum CouncisExecutionTracePresentation {
    public static let launchArgument = "-CouncisShowExecutionTrace"
    public static let environmentVariable = "COUNCIS_SHOW_EXECUTION_TRACE"

    /// Defaults to `false`. This is intentionally not backed by UserDefaults or
    /// exposed through a settings control; changing it requires a new process.
    public static var isEnabled: Bool {
        resolve(
            arguments: ProcessInfo.processInfo.arguments,
            environment: ProcessInfo.processInfo.environment)
    }

    public static func resolve(
        arguments: [String],
        environment: [String: String]
    ) -> Bool {
        if arguments.contains(launchArgument)
            || arguments.contains(
                LegacyIntatisCompatibility.LaunchArgument
                    .showExecutionTrace) {
            return true
        }

        guard let rawValue = environment[environmentVariable]
                ?? environment[
                    LegacyIntatisCompatibility.Environment
                        .showExecutionTrace] else {
            return false
        }
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on", "enabled":
            return true
        default:
            return false
        }
    }

    public static func displayedItems(_ items: [CodeItem]) -> [CodeItem] {
        displayedItems(items, showExecutionTrace: isEnabled)
    }

    public static func displayedItems(
        _ items: [CodeItem],
        showExecutionTrace: Bool
    ) -> [CodeItem] {
        guard !showExecutionTrace else { return items }
        return items.filter(\.isDefaultConversationPresentationItem)
    }
}
