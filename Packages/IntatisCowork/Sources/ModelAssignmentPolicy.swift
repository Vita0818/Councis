import Foundation
import IntatisCore
import IntatisProviders

/// What to do when every compatible model in the worker pool is already bound
/// to an active (or admission-pending) agent.
public enum ModelPoolExhaustionPolicy: String, Codable, Equatable, Sendable {
    case askUser = "ask_user"
    case reject
}

/// A model that Councis may assign to a newly created worker. Capabilities are
/// preset metadata; endpoint existence is validated independently by the
/// provider registry before the agent can run.
public struct ModelPoolEntry: Codable, Equatable, Sendable {
    public var binding: AgentModelBinding
    public var capabilities: [Capability]

    public init(binding: AgentModelBinding,
                capabilities: [Capability] = [.chat, .toolCalling]) {
        self.binding = binding
        self.capabilities = capabilities
    }

    public func supports(_ required: [Capability]) -> Bool {
        required.allSatisfy { capability in
            capabilities.contains { $0.rawValue == capability.rawValue }
        }
    }
}

/// One reserved data-plane identity whose provider/model binding is fixed by
/// the product profile. This prevents a valid binding from being reassigned to
/// another role during admission or event-log restore.
public struct FixedAgentModelBinding: Codable, Equatable, Sendable {
    public var agentID: AgentID
    public var binding: AgentModelBinding

    public init(agentID: AgentID, binding: AgentModelBinding) {
        self.agentID = agentID
        self.binding = binding
    }
}

public enum ModelAssignmentSource: String, Codable, Equatable, Sendable {
    case explicit
    case pool
    case legacyParent = "legacy_parent"
}

public struct ResolvedModelAssignment: Equatable, Sendable {
    public var binding: AgentModelBinding
    public var source: ModelAssignmentSource

    public init(binding: AgentModelBinding, source: ModelAssignmentSource) {
        self.binding = binding
        self.source = source
    }
}

public enum ModelAssignmentError: Error, Equatable, Sendable, LocalizedError {
    case partialBinding
    case bindingNotAllowed(AgentModelBinding)
    case bindingAlreadyInUse(AgentModelBinding)
    case fixedBindingMismatch(agent: AgentID,
                              expected: AgentModelBinding,
                              actual: AgentModelBinding)
    case bindingReservedForAgent(AgentModelBinding, AgentID)
    case missingCapability(AgentModelBinding, Capability)
    case poolExhausted(ModelPoolExhaustionPolicy)
    case parentBindingUnavailable

    public var errorDescription: String? {
        switch self {
        case .partialBinding:
            return "provider and model must be supplied together"
        case .bindingNotAllowed(let binding):
            return "model binding '\(binding.providerID)/\(binding.modelID.rawValue)' is not allowed by this team preset"
        case .bindingAlreadyInUse(let binding):
            return "model binding '\(binding.providerID)/\(binding.modelID.rawValue)' is already used by an active agent"
        case .fixedBindingMismatch(let agent, let expected, let actual):
            return "agent '@\(agent.rawValue)' is fixed to '\(expected.providerID)/\(expected.modelID.rawValue)', not '\(actual.providerID)/\(actual.modelID.rawValue)'"
        case .bindingReservedForAgent(let binding, let owner):
            return "model binding '\(binding.providerID)/\(binding.modelID.rawValue)' is reserved for @\(owner.rawValue)"
        case .missingCapability(let binding, let capability):
            return "model binding '\(binding.providerID)/\(binding.modelID.rawValue)' does not declare capability '\(capability.rawValue)'"
        case .poolExhausted(.askUser):
            return "no unused compatible worker model remains; ask the user to choose or expand the model pool"
        case .poolExhausted(.reject):
            return "no unused compatible worker model remains"
        case .parentBindingUnavailable:
            return "legacy parent-model inheritance was requested without a parent binding"
        }
    }
}

/// Deterministic model assignment for one Cowork session. This value contains
/// only non-secret policy metadata. Reservation and active-agent state remains
/// actor-isolated inside `Orchestrator`.
public struct ModelAssignmentPolicy: Codable, Equatable, Sendable {
    public var workerPool: [ModelPoolEntry]
    public var allowedBindings: [AgentModelBinding]
    /// Optional for backward-compatible decoding of policies persisted before
    /// reserved role bindings were introduced.
    public var fixedAgentBindings: [FixedAgentModelBinding]?
    public var uniquePerActiveAgent: Bool
    public var inheritParentModel: Bool
    public var onExhausted: ModelPoolExhaustionPolicy

    public init(workerPool: [ModelPoolEntry],
                allowedBindings: [AgentModelBinding] = [],
                fixedAgentBindings: [FixedAgentModelBinding] = [],
                uniquePerActiveAgent: Bool = true,
                inheritParentModel: Bool = false,
                onExhausted: ModelPoolExhaustionPolicy = .askUser) {
        self.workerPool = workerPool
        self.allowedBindings = allowedBindings
        self.fixedAgentBindings = fixedAgentBindings.isEmpty ? nil : fixedAgentBindings
        self.uniquePerActiveAgent = uniquePerActiveAgent
        self.inheritParentModel = inheritParentModel
        self.onExhausted = onExhausted
    }

    /// Compatibility behavior for plain Intatis sessions that have no Councis
    /// team preset. Councis sessions should always use the strict initializer.
    public static let legacy = ModelAssignmentPolicy(
        workerPool: [],
        uniquePerActiveAgent: false,
        inheritParentModel: true,
        onExhausted: .reject)

    public var isLegacy: Bool {
        workerPool.isEmpty && allowedBindings.isEmpty
            && (fixedAgentBindings?.isEmpty ?? true)
            && !uniquePerActiveAgent && inheritParentModel
    }

    public func resolve(providerID: String?,
                        modelID: String?,
                        parentBinding: AgentModelBinding?,
                        occupiedBindings: Set<AgentModelBinding>,
                        requiredCapabilities: [Capability] = [.toolCalling]) throws -> ResolvedModelAssignment {
        let provider = providerID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = modelID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasProvider = provider?.isEmpty == false
        let hasModel = model?.isEmpty == false

        guard hasProvider == hasModel else {
            throw ModelAssignmentError.partialBinding
        }

        if hasProvider, hasModel, let provider, let model {
            let binding = AgentModelBinding(
                providerID: provider,
                modelID: ModelID(rawValue: model))
            try validate(binding,
                         occupiedBindings: occupiedBindings,
                         requiredCapabilities: requiredCapabilities)
            return ResolvedModelAssignment(binding: binding, source: .explicit)
        }

        if inheritParentModel {
            guard let parentBinding else {
                throw ModelAssignmentError.parentBindingUnavailable
            }
            try validateUniqueness(parentBinding, occupiedBindings: occupiedBindings)
            return ResolvedModelAssignment(binding: parentBinding, source: .legacyParent)
        }

        for entry in workerPool where entry.supports(requiredCapabilities) {
            if uniquePerActiveAgent && occupiedBindings.contains(entry.binding) {
                continue
            }
            return ResolvedModelAssignment(binding: entry.binding, source: .pool)
        }
        throw ModelAssignmentError.poolExhausted(onExhausted)
    }

    public func validateFixedBinding(_ binding: AgentModelBinding,
                                     for agentID: AgentID,
                                     occupiedBindings: Set<AgentModelBinding>,
                                     requiredCapabilities: [Capability] = [.toolCalling]) throws {
        try validateReservedRole(binding, for: agentID)
        try validate(binding,
                     occupiedBindings: occupiedBindings,
                     requiredCapabilities: requiredCapabilities)
    }

    private func validateReservedRole(_ binding: AgentModelBinding,
                                      for agentID: AgentID) throws {
        let assignments = fixedAgentBindings ?? []
        if let fixed = assignments.first(where: { $0.agentID == agentID }) {
            guard fixed.binding == binding else {
                throw ModelAssignmentError.fixedBindingMismatch(
                    agent: agentID,
                    expected: fixed.binding,
                    actual: binding)
            }
            return
        }
        if let owner = assignments.first(where: { $0.binding == binding }) {
            throw ModelAssignmentError.bindingReservedForAgent(binding, owner.agentID)
        }
    }

    private func validate(_ binding: AgentModelBinding,
                          occupiedBindings: Set<AgentModelBinding>,
                          requiredCapabilities: [Capability]) throws {
        if !isLegacy {
            let entry = workerPool.first { $0.binding == binding }
            let explicitlyAllowed = allowedBindings.contains(binding)
            guard entry != nil || explicitlyAllowed else {
                throw ModelAssignmentError.bindingNotAllowed(binding)
            }
            if let entry {
                for capability in requiredCapabilities where !entry.supports([capability]) {
                    throw ModelAssignmentError.missingCapability(binding, capability)
                }
            }
        }
        try validateUniqueness(binding, occupiedBindings: occupiedBindings)
    }

    private func validateUniqueness(_ binding: AgentModelBinding,
                                    occupiedBindings: Set<AgentModelBinding>) throws {
        if uniquePerActiveAgent, occupiedBindings.contains(binding) {
            throw ModelAssignmentError.bindingAlreadyInUse(binding)
        }
    }
}
