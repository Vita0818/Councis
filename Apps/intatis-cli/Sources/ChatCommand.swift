import Foundation
import IntatisCore
import IntatisProviders

func runChatCommand(_ args: [String]) async throws {
    var mock = false
    var promptParts: [String] = []
    var i = 0

    while i < args.count {
        let arg = args[i]
        switch arg {
        case "--mock", "--dry-run":
            mock = true
        case "--help", "-h":
            printChatHelp()
            return
        default:
            promptParts.append(arg)
        }
        i += 1
    }

    let prompt = promptParts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !prompt.isEmpty else {
        printChatHelp()
        throw IntatisError.config("chat requires a prompt")
    }

    if mock {
        out("mock chat response: \(prompt)\n")
        return
    }

    let config = try CLIConfig.load(requireAPIKey: true)
    try await streamChat(prompt: prompt, config: config)
}

private func printChatHelp() {
    out("""
    USAGE
      councis chat [--mock] "prompt"

    Uses the OpenAI-compatible streaming /chat/completions path by default.
    Set COUNCIS_API_KEY, COUNCIS_BASE_URL, and COUNCIS_MODEL for real calls.

    """)
}

private func streamChat(prompt: String, config: CLIConfig) async throws {
    let endpoint = ProviderEndpoint(
        id: "chat",
        baseURL: config.baseURL,
        apiKeyRef: KeychainRef(service: "councis-cli", account: "chat"),
        wire: .openai
    )
    let provider = OpenAIWireProvider(endpoint: endpoint, apiKey: config.apiKey,
                                      http: URLSessionStreamingClient())
    let request = ChatRequest(
        model: ModelID(rawValue: config.model),
        messages: [
            ChatMessage(role: .system, content: "Follow exact-output requests precisely."),
            ChatMessage(role: .user, content: prompt),
        ],
        reasoningEffort: config.reasoningEffort,
        includeUsage: config.includeUsage
    )

    var sawContent = false
    for try await chunk in provider.stream(request) {
        switch chunk {
        case .delta(let text):
            sawContent = true
            out(text)
        case .usage, .done:
            break
        }
    }
    if sawContent {
        out("\n")
    } else {
        throw IntatisError.provider("empty response")
    }
}
