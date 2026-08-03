import Foundation
import IntatisCore
import IntatisProviders

enum Mode: String, Codable, Sendable {
    case chat
    case work

    static func parse(_ raw: String) -> Mode? {
        switch raw.lowercased() {
        case "chat": return .chat
        case "work", "cowork", "code": return .work
        default: return nil
        }
    }

    var defaultPresetName: String {
        switch self {
        case .chat: return "elite-chat"
        case .work: return "elite-work"
        }
    }
}

/// Councis owns its configuration namespace. The old Intatis file remains a
/// read-only fallback so an existing installation can migrate without losing
/// its endpoint settings; all writes go to `~/.councis/config.json`.
enum ConfigFile {
    static var url: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".councis/config.json")
    }

    static var legacyURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/intatis/config.json")
    }

    private static let scalarKeys: Set<String> = [
        "baseURL", "apiKey", "model", "reasoning", "mode", "usage",
        "maxSteps", "defaultProvider", "preset",
    ]

    static func read() -> [String: String] {
        readRoot().reduce(into: [:]) { result, item in
            if let value = item.value as? String { result[item.key] = value }
        }
    }

    static func readProviderRecords() -> [CLIProviderRecord] {
        guard let value = readRoot()["providers"],
              JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value) else { return [] }
        return (try? JSONDecoder().decode([CLIProviderRecord].self, from: data)) ?? []
    }

    static func write(_ dict: [String: String]) throws {
        var root = readRoot()
        for key in scalarKeys { root.removeValue(forKey: key) }
        for (key, value) in dict { root[key] = value }

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private static func readRoot() -> [String: Any] {
        let source = FileManager.default.fileExists(atPath: url.path) ? url : legacyURL
        guard let data = try? Data(contentsOf: source),
              let object = try? JSONSerialization.jsonObject(with: data),
              let root = object as? [String: Any] else { return [:] }
        return root
    }
}

/// Endpoint records live in the private (0600) Councis config, never in team
/// presets. `apiKeyEnv` is preferred; `apiKey` supports the interactive legacy
/// setup and is deliberately never printed.
struct CLIProviderRecord: Codable, Sendable {
    var id: String
    var baseURL: String
    var apiKeyEnv: String?
    var apiKey: String?
    var wire: WireFormat?
}

struct CLIProviderRuntime: Sendable {
    let id: String
    let baseURL: URL
    let wire: WireFormat
    let apiKey: String?
}

/// Connects a Councis team to one or more OpenAI-compatible endpoints.
/// Resolution precedence is COUNCIS_* env → INTATIS_* compatibility env →
/// ~/.councis/config.json → the old Intatis config → built-in defaults.
struct CLIConfig: Sendable {
    let providers: [CLIProviderRuntime]
    let defaultProviderID: String
    let model: String
    let reasoningEffort: ReasoningEffort?
    let mode: Mode
    let preset: String?
    let includeUsage: Bool
    let maxSteps: Int

    static let defaultBaseURL = "https://api.openai.com/v1"
    static let defaultModel = "gpt-4o-mini"
    static let defaultProviderID = "openai-compatible"

    var defaultProvider: CLIProviderRuntime {
        providers.first { $0.id == defaultProviderID } ?? providers[0]
    }

    // Compatibility conveniences used by config/settings presentation.
    var baseURL: URL { defaultProvider.baseURL }
    var apiKey: String { defaultProvider.apiKey ?? "" }
    var wire: WireFormat { defaultProvider.wire }

    static func load(requireAPIKey: Bool = true) throws -> CLIConfig {
        let env = ProcessInfo.processInfo.environment
        let file = ConfigFile.read()

        func envValue(_ councis: String, legacy: String? = nil) -> String? {
            if let value = env[councis], !value.isEmpty { return value }
            if let legacy, let value = env[legacy], !value.isEmpty { return value }
            return nil
        }
        func value(_ councis: String, legacy: String?, fileKey: String, fallback: String?) -> String? {
            envValue(councis, legacy: legacy) ?? file[fileKey].flatMap { $0.isEmpty ? nil : $0 } ?? fallback
        }

        let configuredRecords = ConfigFile.readProviderRecords()
        let selectedProviderID = value(
            "COUNCIS_PROVIDER", legacy: "INTATIS_PROVIDER", fileKey: "defaultProvider",
            fallback: configuredRecords.first?.id ?? defaultProviderID)!
        let globalBaseURL = envValue("COUNCIS_BASE_URL", legacy: "INTATIS_BASE_URL")
        let globalAPIKey = envValue("COUNCIS_API_KEY", legacy: "INTATIS_API_KEY")

        let records: [CLIProviderRecord]
        if configuredRecords.isEmpty {
            records = [CLIProviderRecord(
                id: selectedProviderID,
                baseURL: globalBaseURL ?? file["baseURL"] ?? defaultBaseURL,
                apiKeyEnv: nil,
                apiKey: globalAPIKey ?? file["apiKey"],
                wire: .openai)]
        } else {
            records = configuredRecords
        }

        var runtimes: [CLIProviderRuntime] = []
        for record in records {
            let providerEnvKey = "COUNCIS_\(environmentToken(record.id))_API_KEY"
            let baseString = record.id == selectedProviderID
                ? (globalBaseURL ?? record.baseURL)
                : record.baseURL
            guard let baseURL = URL(string: baseString),
                  let scheme = baseURL.scheme?.lowercased(),
                  (scheme == "http" || scheme == "https"),
                  baseURL.host?.isEmpty == false else {
                throw IntatisError.config("invalid base URL for provider '\(record.id)': \(baseString)")
            }
            let providerKey = record.apiKeyEnv.flatMap { env[$0] }.flatMap { $0.isEmpty ? nil : $0 }
                ?? env[providerEnvKey].flatMap { $0.isEmpty ? nil : $0 }
                ?? (record.id == selectedProviderID ? globalAPIKey : nil)
                ?? record.apiKey
                ?? (record.id == selectedProviderID ? file["apiKey"] : nil)
            runtimes.append(CLIProviderRuntime(
                id: record.id, baseURL: baseURL, wire: record.wire ?? .openai, apiKey: providerKey))
        }

        guard !runtimes.isEmpty else {
            throw IntatisError.config("no providers configured")
        }
        guard runtimes.contains(where: { $0.id == selectedProviderID }) else {
            throw IntatisError.config("default provider '\(selectedProviderID)' is not present in providers")
        }
        if requireAPIKey,
           runtimes.first(where: { $0.id == selectedProviderID })?.apiKey?.isEmpty != false {
            throw IntatisError.config(
                "no API key for provider '\(selectedProviderID)' — run `councis settings`, set COUNCIS_API_KEY, or configure that provider's apiKeyEnv")
        }

        let model = value("COUNCIS_MODEL", legacy: "INTATIS_MODEL", fileKey: "model", fallback: defaultModel)!
        let reasoning = value("COUNCIS_REASONING", legacy: "INTATIS_REASONING", fileKey: "reasoning", fallback: nil)
            .flatMap { ReasoningEffort(rawValue: $0.lowercased()) }
        let modeRaw = value("COUNCIS_MODE", legacy: "INTATIS_MODE", fileKey: "mode", fallback: "chat")!
        let mode = Mode.parse(modeRaw) ?? .chat
        let preset = value("COUNCIS_PRESET", legacy: nil, fileKey: "preset", fallback: nil)
        let usage = value("COUNCIS_USAGE", legacy: "INTATIS_USAGE", fileKey: "usage", fallback: "1")!.lowercased()
        let includeUsage = !(usage == "0" || usage == "false" || usage == "off")
        let maxStepsString = value(
            "COUNCIS_MAX_STEPS", legacy: "INTATIS_MAX_STEPS", fileKey: "maxSteps", fallback: "50")!
        let maxSteps = max(1, Int(maxStepsString) ?? 50)

        return CLIConfig(
            providers: runtimes,
            defaultProviderID: selectedProviderID,
            model: model,
            reasoningEffort: reasoning,
            mode: mode,
            preset: preset,
            includeUsage: includeUsage,
            maxSteps: maxSteps)
    }

    func providerConfig(defaultProviderID requestedProviderID: String? = nil,
                        model: String? = nil) throws -> ProviderConfig {
        let providerID = try resolveProviderID(requestedProviderID)
        let endpoints = providers.map {
            ProviderEndpoint(
                id: $0.id,
                baseURL: $0.baseURL,
                apiKeyRef: KeychainRef(service: "councis-cli", account: $0.id),
                wire: $0.wire)
        }
        let ref = ModelRef(endpoint: providerID, model: ModelID(rawValue: model ?? self.model))
        return ProviderConfig(endpoints: endpoints, models: ResolvedModels(chat: ref, agent: ref))
    }

    func resolveProviderID(_ requestedProviderID: String?) throws -> String {
        let requested = requestedProviderID?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let requested, !requested.isEmpty,
           providers.contains(where: { $0.id == requested }) {
            return requested
        }
        // A legacy preset commonly used the generic label
        // `openai-compatible`; a single configured endpoint is unambiguous.
        if let requested, !requested.isEmpty,
           requested == "openai-compatible", providers.count == 1 {
            return providers[0].id
        }
        if requested == nil || requested?.isEmpty == true { return defaultProviderID }
        throw IntatisError.config(
            "preset references unknown provider '\(requested!)' (configured: \(providers.map(\.id).joined(separator: ", ")))")
    }

    func secretResolver() -> CLISecretResolver {
        CLISecretResolver(keys: Dictionary(uniqueKeysWithValues: providers.compactMap {
            guard let key = $0.apiKey, !key.isEmpty else { return nil }
            return ($0.id, key)
        }))
    }

    func baseURL(for providerID: String) -> URL? {
        providers.first { $0.id == providerID }?.baseURL
    }

    private static func environmentToken(_ id: String) -> String {
        let mapped = id.uppercased().unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar)) : "_"
        }
        return String(mapped)
    }
}

struct CLISecretResolver: SecretResolver {
    let keys: [String: String]

    func secret(for ref: KeychainRef) async throws -> String {
        guard let key = keys[ref.account], !key.isEmpty else {
            throw IntatisError.config(
                "no API key for provider '\(ref.account)' — set COUNCIS_\(providerEnvironmentToken(ref.account))_API_KEY or update ~/.councis/config.json")
        }
        return key
    }

    private func providerEnvironmentToken(_ id: String) -> String {
        let mapped = id.uppercased().unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar)) : "_"
        }
        return String(mapped)
    }
}
