import Foundation
import IntatisCore
import IntatisProviders
import IntatisCowork

enum TeamPresetSource: String, Sendable {
    case team
    case legacyCouncil
}

struct TeamAgentDefinition: Codable, Hashable, Sendable {
    var name: String?
    var providerID: String
    var model: String
    var required: Bool?

    private enum CodingKeys: String, CodingKey {
        case name
        case providerID
        case provider
        case model
        case required
    }

    init(name: String? = nil, providerID: String, model: String, required: Bool? = nil) {
        self.name = name
        self.providerID = providerID
        self.model = model
        self.required = required
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        providerID = try container.decodeIfPresent(String.self, forKey: .providerID)
            ?? container.decodeIfPresent(String.self, forKey: .provider)
            ?? CLIConfig.defaultProviderID
        model = try container.decode(String.self, forKey: .model)
        required = try container.decodeIfPresent(Bool.self, forKey: .required)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encode(providerID, forKey: .providerID)
        try container.encode(model, forKey: .model)
        try container.encodeIfPresent(required, forKey: .required)
    }

    var identity: String { "\(providerID)/\(model)" }
}

struct TeamProviderMetadata: Codable, Hashable, Sendable {
    var id: String
    var displayName: String?
    var configHint: String?
}

enum TeamModelAssignmentStrategy: String, Codable, Sendable {
    case unique = "unique"
    case legacyCompatible = "legacy-compatible"
}

enum TeamPoolExhaustionPolicy: String, Codable, Sendable {
    case fail
    case requireExplicitModel = "require-explicit-model"
}

struct TeamModelAssignment: Codable, Sendable {
    var strategy: TeamModelAssignmentStrategy
    var onPoolExhaustion: TeamPoolExhaustionPolicy
    var excludeControlPlaneAgents: Bool

    init(strategy: TeamModelAssignmentStrategy = .unique,
         onPoolExhaustion: TeamPoolExhaustionPolicy = .fail,
         excludeControlPlaneAgents: Bool = true) {
        self.strategy = strategy
        self.onPoolExhaustion = onPoolExhaustion
        self.excludeControlPlaneAgents = excludeControlPlaneAgents
    }
}

/// A Councis preset describes team composition and model routing, but contains
/// no endpoint URL, API key, credential reference, or other secret material.
struct TeamPreset: Codable, Sendable {
    var schemaVersion: Int
    var name: String
    var mode: String?
    var main: TeamAgentDefinition
    var judge: TeamAgentDefinition
    var workerModelPool: [TeamAgentDefinition]
    var modelAssignment: TeamModelAssignment
    var providers: [TeamProviderMetadata]
    var source: TeamPresetSource

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case name
        case mode
        case main
        case judge
        case workerModelPool
        case modelAssignment
        case providers

        // v0.1 council compatibility
        case candidates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        name = try container.decode(String.self, forKey: .name)
        mode = try container.decodeIfPresent(String.self, forKey: .mode)

        if let decodedMain = try container.decodeIfPresent(TeamAgentDefinition.self, forKey: .main) {
            main = decodedMain
            judge = try container.decode(TeamAgentDefinition.self, forKey: .judge)
            workerModelPool = try container.decodeIfPresent(
                [TeamAgentDefinition].self, forKey: .workerModelPool) ?? []
            modelAssignment = try container.decodeIfPresent(
                TeamModelAssignment.self, forKey: .modelAssignment) ?? TeamModelAssignment()
            source = .team
        } else {
            let candidates = try container.decode([TeamAgentDefinition].self, forKey: .candidates)
            guard let first = candidates.first else {
                throw DecodingError.dataCorruptedError(
                    forKey: .candidates, in: container,
                    debugDescription: "legacy council preset must contain at least one candidate")
            }
            main = first
            judge = try container.decode(TeamAgentDefinition.self, forKey: .judge)
            workerModelPool = Array(candidates.dropFirst())
            modelAssignment = try container.decodeIfPresent(
                TeamModelAssignment.self, forKey: .modelAssignment)
                ?? TeamModelAssignment(strategy: .unique)
            source = .legacyCouncil
        }

        providers = try container.decodeIfPresent([TeamProviderMetadata].self, forKey: .providers)
            ?? Self.inferredProviderMetadata(main: main, judge: judge, workers: workerModelPool)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(mode, forKey: .mode)
        try container.encode(main, forKey: .main)
        try container.encode(judge, forKey: .judge)
        try container.encode(workerModelPool, forKey: .workerModelPool)
        try container.encode(modelAssignment, forKey: .modelAssignment)
        try container.encode(providers, forKey: .providers)
    }

    func validated(for requestedMode: Mode, config: CLIConfig) throws -> TeamPreset {
        if let mode, let presetMode = Mode.parse(mode), presetMode != requestedMode {
            throw IntatisError.config(
                "preset '\(name)' is for \(presetMode.rawValue), not \(requestedMode.rawValue)")
        }
        let definitions = [main, judge] + workerModelPool
        for definition in definitions {
            guard !definition.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw IntatisError.config("preset '\(name)' contains an empty model id")
            }
            _ = try config.resolveProviderID(definition.providerID)
        }
        if modelAssignment.strategy == .unique {
            var seen = Set<String>()
            for definition in definitions {
                let resolvedProvider = try config.resolveProviderID(definition.providerID)
                let identity = "\(resolvedProvider)/\(definition.model)"
                guard seen.insert(identity).inserted else {
                    throw IntatisError.config(
                        "preset '\(name)' reuses \(identity); unique model assignment requires a different provider/model pair for every data-plane role")
                }
            }
        }
        guard modelAssignment.excludeControlPlaneAgents else {
            throw IntatisError.config(
                "preset '\(name)' must exclude control-plane agents from data-plane model uniqueness")
        }
        return self
    }

    var workerPoolSummary: String {
        workerModelPool.map(\.identity).joined(separator: ", ")
    }

    func resolvedBinding(for definition: TeamAgentDefinition,
                         config: CLIConfig) throws -> AgentModelBinding {
        try AgentModelBinding(
            validatingProviderID: config.resolveProviderID(definition.providerID),
            modelID: ModelID(rawValue: definition.model))
    }

    func workerBinding(for token: String?,
                       occupied: Set<AgentModelBinding>,
                       config: CLIConfig) throws -> AgentModelBinding {
        let available = try workerModelPool.map { try resolvedBinding(for: $0, config: config) }
        if let token, !token.isEmpty {
            let exact = available.filter {
                "\($0.providerID)/\($0.modelID.rawValue)" == token || $0.modelID.rawValue == token
            }
            guard exact.count == 1, let binding = exact.first else {
                throw IntatisError.config(
                    "worker binding '\(token)' is absent or ambiguous; choose one of \(available.map { "\($0.providerID)/\($0.modelID.rawValue)" }.joined(separator: ", "))")
            }
            if modelAssignment.strategy == .unique, occupied.contains(binding) {
                throw IntatisError.config("worker binding '\(token)' is already in use")
            }
            return binding
        }
        if let binding = available.first(where: {
            modelAssignment.strategy != .unique || !occupied.contains($0)
        }) {
            return binding
        }
        throw IntatisError.config(
            modelAssignment.onPoolExhaustion == .fail
                ? "worker model pool is exhausted"
                : "worker model pool is exhausted; provide an explicit provider/model binding")
    }

    func runtimeModelAssignmentPolicy(config: CLIConfig) throws -> ModelAssignmentPolicy {
        guard modelAssignment.strategy == .unique else {
            throw IntatisError.config(
                "preset '\(name)' uses legacy-compatible model reuse; migrate it to unique assignment before running Cowork")
        }
        let mainBinding = try resolvedBinding(for: main, config: config)
        let judgeBinding = try resolvedBinding(for: judge, config: config)
        let pool = try workerModelPool.map { definition in
            ModelPoolEntry(
                binding: try resolvedBinding(for: definition, config: config),
                capabilities: [.chat, .toolCalling])
        }
        return ModelAssignmentPolicy(
            workerPool: pool,
            allowedBindings: [mainBinding, judgeBinding],
            fixedAgentBindings: [
                FixedAgentModelBinding(
                    agentID: Orchestrator.mainAgentID,
                    binding: mainBinding),
                FixedAgentModelBinding(
                    agentID: Orchestrator.taskReviewerID,
                    binding: judgeBinding),
            ],
            uniquePerActiveAgent: true,
            inheritParentModel: false,
            onExhausted: modelAssignment.onPoolExhaustion == .fail ? .reject : .askUser)
    }

    private static func inferredProviderMetadata(
        main: TeamAgentDefinition,
        judge: TeamAgentDefinition,
        workers: [TeamAgentDefinition]
    ) -> [TeamProviderMetadata] {
        var seen = Set<String>()
        return ([main, judge] + workers).compactMap { definition in
            guard seen.insert(definition.providerID).inserted else { return nil }
            return TeamProviderMetadata(
                id: definition.providerID,
                displayName: nil,
                configHint: "Configure endpoint and credentials in ~/.councis/config.json")
        }
    }
}

func loadTeamPreset(named name: String, mode: Mode, config: CLIConfig) throws -> TeamPreset {
    let safeName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !safeName.isEmpty,
          safeName.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil else {
        throw IntatisError.config("invalid preset name: \(name)")
    }
    let fileManager = FileManager.default
    let local = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        .appendingPathComponent(".councis/presets/\(safeName).json")
    let home = fileManager.homeDirectoryForCurrentUser
        .appendingPathComponent(".councis/presets/\(safeName).json")
    let url: URL
    if fileManager.fileExists(atPath: local.path) {
        url = local
    } else if fileManager.fileExists(atPath: home.path) {
        url = home
    } else {
        throw IntatisError.config("missing team preset: \(local.path)")
    }
    do {
        let preset = try JSONDecoder().decode(TeamPreset.self, from: Data(contentsOf: url))
        return try preset.validated(for: mode, config: config)
    } catch let error as IntatisError {
        throw error
    } catch {
        throw IntatisError.config("invalid team preset '\(safeName)': \(error.localizedDescription)")
    }
}
