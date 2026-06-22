import Foundation

/// `councis` — the CLI prototype. Pure command-line Swift, so it builds and runs
/// from SwiftPM with no Xcode: `swift run councis`.
@main
struct CouncisCLI {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        let command = args.first ?? ""
        do {
            switch command {
            case "":
                try await runChatCommand([])
            case "chat":
                try await runChatCommand(Array(args.dropFirst()))
            case "work":
                try await runWorkCommand(Array(args.dropFirst()))
            case "council":
                try await runCouncilCommand(Array(args.dropFirst()))
            case "settings":
                try runSettings()
            case "config":
                printConfig(try CLIConfig.load(requireAPIKey: false))
            case "selftest":
                try await runSelfTest()
            case "help", "--help", "-h":
                printHelp()
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
}
