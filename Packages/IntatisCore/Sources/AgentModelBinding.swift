import Foundation

/// Stable provider/model identity for an agent.
///
/// The provider identifier names a configured provider endpoint; credentials
/// remain in the provider configuration and are never stored in this value.
public struct AgentModelBinding: Codable, Equatable, Hashable, Sendable {
    /// Sentinel used only by the source-compatible `Agent(model:)` initializer.
    /// Provider routing intentionally rejects it unless a migration layer first
    /// resolves the legacy agent to a real configured provider.
    public static let unresolvedLegacyProviderID = "__legacy_unresolved__"

    public let providerID: String
    public let modelID: ModelID

    /// Non-throwing construction for identifiers already validated by a trusted
    /// configuration boundary. Invalid values are programmer errors.
    public init(providerID: String, modelID: ModelID) {
        let normalizedProviderID = providerID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedModelID = modelID.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        precondition(!normalizedProviderID.isEmpty, "agent model binding provider ID must not be empty")
        precondition(!normalizedModelID.isEmpty, "agent model binding model ID must not be empty")
        self.providerID = normalizedProviderID
        self.modelID = ModelID(rawValue: normalizedModelID)
    }

    /// Validates and normalizes user/config supplied identifiers.
    public init(validatingProviderID providerID: String, modelID: ModelID) throws {
        let normalizedProviderID = providerID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedProviderID.isEmpty else {
            throw IntatisError.config("agent model binding provider ID must not be empty")
        }
        let normalizedModelID = modelID.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedModelID.isEmpty else {
            throw IntatisError.config("agent model binding model ID must not be empty")
        }
        self.providerID = normalizedProviderID
        self.modelID = ModelID(rawValue: normalizedModelID)
    }

    /// Explicitly named alias for trusted call sites that want to document the
    /// validation boundary.
    public init(trustedProviderID providerID: String, modelID: ModelID) {
        self.init(providerID: providerID, modelID: modelID)
    }

    public var isResolved: Bool {
        providerID != Self.unresolvedLegacyProviderID
    }

    /// Revalidates a binding received from an in-memory compatibility boundary.
    public func validated() throws -> AgentModelBinding {
        try AgentModelBinding(validatingProviderID: providerID, modelID: modelID)
    }

    private enum CodingKeys: String, CodingKey {
        case providerID
        case modelID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            validatingProviderID: container.decode(String.self, forKey: .providerID),
            modelID: container.decode(ModelID.self, forKey: .modelID))
    }
}
