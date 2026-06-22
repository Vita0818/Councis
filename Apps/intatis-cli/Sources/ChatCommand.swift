import Foundation

func runChatCommand(_ args: [String]) async throws {
    if args.isEmpty {
        printChatHelp()
        out("chat › ")
        guard let line = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !line.isEmpty else {
            return
        }
        try await runCouncilEngineCommand([line], surface: "chat", defaultPreset: "elite-chat")
        return
    }
    try await runCouncilEngineCommand(args, surface: "chat", defaultPreset: "elite-chat")
}

private func printChatHelp() {
    out("""
    USAGE
      councis chat [--preset elite-chat] [--mock] "prompt"

    Chat is council-powered by default: multiple candidate models answer in
    parallel, then the judge synthesizes the final answer. It has no filesystem
    tools and performs no project operations.

    """)
}
