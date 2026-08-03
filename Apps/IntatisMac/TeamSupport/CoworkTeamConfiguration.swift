import Foundation
import IntatisCore
import IntatisCowork

public enum CoworkTeamConfigurationError: Error, Equatable, Sendable, LocalizedError {
    case insufficientUniqueBindings(configured: Int)
    case preferredMainUnavailable(AgentModelBinding)
    case mainAndJudgeMustDiffer
    case configuredBindingUnavailable(role: String, binding: AgentModelBinding)

    public var errorDescription: String? {
        switch self {
        case .insufficientUniqueBindings(let configured):
            return "Councis Cowork requires at least 2 unique provider/model bindings for @main and @judge; Provider Settings currently expose \(configured)."
        case .preferredMainUnavailable(let binding):
            return "The selected @main binding '\(Self.describe(binding))' is not available in Provider Settings."
        case .mainAndJudgeMustDiffer:
            return "Councis requires @main and @judge to use different provider/model bindings."
        case .configuredBindingUnavailable(let role, let binding):
            return "The fixed \(role) binding '\(Self.describe(binding))' is no longer available in Provider Settings."
        }
    }

    private static func describe(_ binding: AgentModelBinding) -> String {
        "\(binding.providerID)/\(binding.modelID.rawValue)"
    }
}

/// Immutable non-secret team bindings persisted with a Councis Cowork project.
/// The permission-review control plane is deliberately absent: it may reuse
/// `mainBinding` without consuming a data-plane uniqueness slot.
public struct CoworkTeamConfiguration: Codable, Equatable, Sendable {
    public static let mainAgentID = Orchestrator.mainAgentID
    public static let judgeAgentID = Orchestrator.taskReviewerID

    public var mainBinding: AgentModelBinding
    public var judgeBinding: AgentModelBinding
    public var workerModelPool: [AgentModelBinding]

    public init(mainBinding: AgentModelBinding,
                judgeBinding: AgentModelBinding,
                workerModelPool: [AgentModelBinding] = []) throws {
        guard mainBinding != judgeBinding else {
            throw CoworkTeamConfigurationError.mainAndJudgeMustDiffer
        }
        self.mainBinding = mainBinding
        self.judgeBinding = judgeBinding
        self.workerModelPool = Self.uniqueBindings(
            workerModelPool.filter { $0 != mainBinding && $0 != judgeBinding })
    }

    /// Deterministically fixes @main to the selected binding, prefers a judge
    /// with a different model id, and assigns every remaining binding to the
    /// worker pool in catalog order.
    public static func derive(availableBindings rawBindings: [AgentModelBinding],
                              preferredMain: AgentModelBinding) throws -> CoworkTeamConfiguration {
        let available = uniqueBindings(rawBindings.filter(\.isResolved))
        guard available.count >= 2 else {
            throw CoworkTeamConfigurationError.insufficientUniqueBindings(configured: available.count)
        }
        guard available.contains(preferredMain) else {
            throw CoworkTeamConfigurationError.preferredMainUnavailable(preferredMain)
        }
        let judge = available.first {
            $0 != preferredMain && $0.modelID != preferredMain.modelID
        } ?? available.first { $0 != preferredMain }
        guard let judge else {
            throw CoworkTeamConfigurationError.insufficientUniqueBindings(configured: available.count)
        }
        return try CoworkTeamConfiguration(
            mainBinding: preferredMain,
            judgeBinding: judge,
            workerModelPool: available.filter { $0 != preferredMain && $0 != judge })
    }

    /// Keeps persisted team roles fixed while ensuring their provider/model
    /// entries still exist in the current provider catalog.
    public func validated(availableBindings rawBindings: [AgentModelBinding]) throws -> CoworkTeamConfiguration {
        let available = Self.uniqueBindings(rawBindings.filter(\.isResolved))
        guard available.count >= 2 else {
            throw CoworkTeamConfigurationError.insufficientUniqueBindings(configured: available.count)
        }
        let normalized = try CoworkTeamConfiguration(
            mainBinding: mainBinding,
            judgeBinding: judgeBinding,
            workerModelPool: workerModelPool)
        let availableSet = Set(available)
        for (role, binding) in [("@main", normalized.mainBinding), ("@judge", normalized.judgeBinding)] {
            guard availableSet.contains(binding) else {
                throw CoworkTeamConfigurationError.configuredBindingUnavailable(
                    role: role,
                    binding: binding)
            }
        }
        for binding in normalized.workerModelPool where !availableSet.contains(binding) {
            throw CoworkTeamConfigurationError.configuredBindingUnavailable(
                role: "worker-pool",
                binding: binding)
        }
        return normalized
    }

    public var allBindings: [AgentModelBinding] {
        [mainBinding, judgeBinding] + workerModelPool
    }

    public var strictModelAssignmentPolicy: ModelAssignmentPolicy {
        ModelAssignmentPolicy(
            workerPool: workerModelPool.map { ModelPoolEntry(binding: $0) },
            allowedBindings: [mainBinding, judgeBinding],
            fixedAgentBindings: [
                FixedAgentModelBinding(
                    agentID: Self.mainAgentID,
                    binding: mainBinding),
                FixedAgentModelBinding(
                    agentID: Self.judgeAgentID,
                    binding: judgeBinding),
            ],
            uniquePerActiveAgent: true,
            inheritParentModel: false,
            onExhausted: .reject)
    }

    private static func uniqueBindings(_ bindings: [AgentModelBinding]) -> [AgentModelBinding] {
        var seen = Set<AgentModelBinding>()
        return bindings.filter { seen.insert($0).inserted }
    }
}
