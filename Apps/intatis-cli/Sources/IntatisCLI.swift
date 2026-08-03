import Foundation
import IntatisCore

/// `councis` is a thin product wrapper around the Intatis Cowork runtime. Chat
/// and Work differ only in their workspace/capability envelope and team preset.
@main
struct CouncisCLI {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        let command = args.first ?? ""
        do {
            switch command {
            case "", "chat", "work", "cowork", "code":
                // Parse before requiring credentials so `chat --help` and the
                // explicit legacy `--mock` rejection work on a fresh install.
                let parseConfig = try CLIConfig.load(requireAPIKey: false)
                let mode = command.isEmpty ? parseConfig.mode : (Mode.parse(command) ?? .chat)
                let launchArgs = command.isEmpty ? args : Array(args.dropFirst())
                let launch = try parseLaunchArguments(
                    launchArgs,
                    mode: mode,
                    config: parseConfig)
                if launch.showHelp {
                    printHelp()
                    return
                }
                let config = try CLIConfig.load()
                let preset = try loadTeamPreset(named: launch.presetName, mode: mode, config: config)
                try await runMode(
                    config,
                    mode: mode,
                    workspace: launch.workspace,
                    preset: preset,
                    oneShotPrompt: launch.prompt)
            case "settings":
                try runSettings()
            case "config":
                printConfig(try CLIConfig.load(requireAPIKey: false))
            case "selftest":
                try await runSelfTest()
            case "runs":
                try printLegacyCouncilRuns(Array(args.dropFirst()))
            case "help", "--help", "-h":
                printHelp()
            case let removed where removed == "--mock" || removed.hasPrefix("--mock="):
                throw CouncisCLIError.argument(Self.legacyMockRemovalMessage)
            default:
                errOut("unknown command: \(command)\n\n")
                printHelp()
                exit(2)
            }
        } catch {
            errOut("error: \(error.localizedDescription)\n")
            exit(1)
        }
    }

    static let legacyMockRemovalMessage =
        "--mock is unavailable because the legacy Council engine was removed; use `councis selftest` for an offline smoke test"
}

enum CouncisCLIError: Error, LocalizedError, Equatable {
    case argument(String)
    case execution(String)

    var errorDescription: String? {
        switch self {
        case .argument(let message), .execution(let message): return message
        }
    }
}

struct LaunchArguments: Equatable {
    var presetName: String
    var workspace: URL
    var prompt: String?
    var showHelp: Bool
}

/// Parses only launch syntax; it does not read credentials, load presets, or
/// start a runtime. Internal visibility lets the offline self-test exercise the
/// historical one-shot forms without spawning another process.
func parseLaunchArguments(
    _ args: [String],
    mode: Mode,
    config: CLIConfig,
    currentDirectory: URL = URL(
        fileURLWithPath: FileManager.default.currentDirectoryPath,
        isDirectory: true),
    directoryExists: (URL) -> Bool = { url in
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(
            atPath: url.path,
            isDirectory: &isDirectory) && isDirectory.boolValue
    }
) throws -> LaunchArguments {
    var presetName = config.preset ?? mode.defaultPresetName
    var explicitWorkspacePath: String?
    var positional: [String] = []
    var afterSeparator = false
    var forcePositionalPrompt = false
    var index = 0

    func resolvedURL(_ rawPath: String) -> URL {
        let expanded = (rawPath as NSString).expandingTildeInPath
        if (expanded as NSString).isAbsolutePath {
            return URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL
        }
        return currentDirectory
            .appendingPathComponent(expanded, isDirectory: true)
            .standardizedFileURL
    }

    func optionValue(_ option: String) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < args.count,
              !args[valueIndex].isEmpty,
              args[valueIndex] != "--",
              !args[valueIndex].hasPrefix("--") else {
            throw CouncisCLIError.argument("\(option) requires a value")
        }
        index = valueIndex
        return args[valueIndex]
    }

    while index < args.count {
        let argument = args[index]
        if afterSeparator {
            positional.append(argument)
            index += 1
            continue
        }

        switch argument {
        case "--":
            afterSeparator = true
            forcePositionalPrompt = true
        case "--preset":
            presetName = try optionValue("--preset")
        case let value where value.hasPrefix("--preset="):
            presetName = String(value.dropFirst("--preset=".count))
            guard !presetName.isEmpty else {
                throw CouncisCLIError.argument("--preset requires a value")
            }
        case "--workspace", "--dir":
            guard mode == .work else {
                throw CouncisCLIError.argument("\(argument) is available only in work mode")
            }
            guard explicitWorkspacePath == nil else {
                throw CouncisCLIError.argument("only one workspace may be supplied")
            }
            explicitWorkspacePath = try optionValue(argument)
        case let value where value.hasPrefix("--workspace=") || value.hasPrefix("--dir="):
            guard mode == .work else {
                throw CouncisCLIError.argument("workspace options are available only in work mode")
            }
            guard explicitWorkspacePath == nil else {
                throw CouncisCLIError.argument("only one workspace may be supplied")
            }
            guard let separator = value.firstIndex(of: "=") else {
                preconditionFailure("workspace option matched without =")
            }
            let rawPath = String(value[value.index(after: separator)...])
            guard !rawPath.isEmpty else {
                throw CouncisCLIError.argument("workspace option requires a directory")
            }
            explicitWorkspacePath = rawPath
        case "--help", "-h":
            return LaunchArguments(
                presetName: presetName,
                workspace: currentDirectory.standardizedFileURL,
                prompt: nil,
                showHelp: true)
        case let value where value == "--mock" || value.hasPrefix("--mock="):
            throw CouncisCLIError.argument(CouncisCLI.legacyMockRemovalMessage)
        default:
            guard !argument.hasPrefix("-") else {
                throw CouncisCLIError.argument(
                    "unknown option: \(argument) (use `--` before prompt text that begins with `-`)")
            }
            positional.append(argument)
        }
        index += 1
    }

    var workspace = currentDirectory.standardizedFileURL
    var promptTokens = positional

    if let explicitWorkspacePath {
        workspace = resolvedURL(explicitWorkspacePath)
        guard directoryExists(workspace) else {
            throw CouncisCLIError.argument(
                "workspace is not an existing directory: \(workspace.path)")
        }
    } else if mode == .work,
              !forcePositionalPrompt,
              positional.count == 1 {
        // Compatibility with historical `councis work DIR` is intentionally
        // narrow: a sole positional token is a workspace only when it already
        // exists as a directory. Every other positional sequence is a prompt.
        let candidate = resolvedURL(positional[0])
        if directoryExists(candidate) {
            workspace = candidate
            promptTokens = []
        }
    }

    let joinedPrompt = promptTokens
        .joined(separator: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return LaunchArguments(
        presetName: presetName,
        workspace: workspace,
        prompt: joinedPrompt.isEmpty ? nil : joinedPrompt,
        showHelp: false)
}
