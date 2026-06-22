import Foundation
import IntatisCore
import IntatisProviders

enum Mode: String { case chat, work, code, cowork }

/// Persistent config at `~/.councis/config.json` (string values; null values are ignored).
/// `councis settings` writes it; env vars override it; both override defaults.
enum ConfigFile {
    static var url: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".councis/config.json")
    }

    static func read() -> [String: String] {
        guard let data = try? Data(contentsOf: url),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return [:] }
        var out: [String: String] = [:]
        for (key, value) in obj {
            if let string = value as? String, !string.isEmpty {
                out[key] = string
            }
        }
        return out
    }

    static func write(_ dict: [String: String]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}

/// Connect to ANY OpenAI-compatible endpoint. Resolution precedence per field:
/// environment variable → config file → built-in default.
struct CLIConfig {
    let baseURL: URL
    let apiKey: String
    let model: String
    let wire: WireFormat
    let reasoningEffort: ReasoningEffort?
    let mode: Mode
    let includeUsage: Bool
    let maxSteps: Int

    static let defaultBaseURL = "https://api.openai.com/v1"
    static let defaultModel = "gpt-4o-mini"

    static func load(requireAPIKey: Bool = true) throws -> CLIConfig {
        let env = ProcessInfo.processInfo.environment
        let file = ConfigFile.read()
        func value(_ envKey: String, _ legacyEnvKey: String?, _ fileKeys: [String], fallback: String?) -> String? {
            if let e = env[envKey], !e.isEmpty { return e }
            if let legacyEnvKey, let e = env[legacyEnvKey], !e.isEmpty { return e }
            for fileKey in fileKeys {
                if let f = file[fileKey], !f.isEmpty { return f }
            }
            return fallback
        }

        let baseString = value("COUNCIS_BASE_URL", "INTATIS_BASE_URL", ["baseURL", "endpoint"], fallback: defaultBaseURL)!
        guard let baseURL = URL(string: baseString) else {
            throw IntatisError.config("invalid base URL: \(baseString)")
        }
        let resolvedAPIKey = value("COUNCIS_API_KEY", "INTATIS_API_KEY", ["apiKey"], fallback: nil) ?? ""
        if requireAPIKey && resolvedAPIKey.isEmpty {
            throw IntatisError.config("Missing API key. Set COUNCIS_API_KEY or configure \(ConfigFile.url.path).")
        }
        let model = value("COUNCIS_MODEL", "INTATIS_MODEL", ["model"], fallback: defaultModel)!
        let reasoning = value("COUNCIS_REASONING", "INTATIS_REASONING", ["reasoning"], fallback: nil)
            .flatMap { ReasoningEffort(rawValue: $0.lowercased()) }
        let mode = Mode(rawValue: value("COUNCIS_MODE", "INTATIS_MODE", ["mode"], fallback: "chat")!.lowercased()) ?? .chat
        // Ask the endpoint for token usage (default on). Set COUNCIS_USAGE=0 if an
        // endpoint rejects the stream_options field.
        let usageStr = value("COUNCIS_USAGE", "INTATIS_USAGE", ["usage"], fallback: "1")!.lowercased()
        let includeUsage = !(usageStr == "0" || usageStr == "false" || usageStr == "off")
        // How many tool round-trips one turn may take before giving up. Long
        // agentic tasks need plenty; override with COUNCIS_MAX_STEPS.
        let maxSteps = max(1, Int(value("COUNCIS_MAX_STEPS", "INTATIS_MAX_STEPS", ["maxSteps"], fallback: "50")!) ?? 50)

        return CLIConfig(baseURL: baseURL, apiKey: resolvedAPIKey, model: model, wire: .openai,
                         reasoningEffort: reasoning, mode: mode, includeUsage: includeUsage,
                         maxSteps: maxSteps)
    }

    func providerConfig() -> ProviderConfig {
        let endpoint = ProviderEndpoint(
            id: "cli", baseURL: baseURL,
            apiKeyRef: KeychainRef(service: "councis-cli", account: "cli"), wire: wire)
        let ref = ModelRef(endpoint: "cli", model: ModelID(rawValue: model))
        return ProviderConfig(endpoints: [endpoint], models: ResolvedModels(chat: ref, agent: ref))
    }
}

struct StaticSecretResolver: SecretResolver {
    let key: String
    func secret(for ref: KeychainRef) async throws -> String { key }
}
