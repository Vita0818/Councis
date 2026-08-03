import Foundation
import IntatisCore
import IntatisProtocol

/// Product surface policy for one Cowork runtime. Chat and Work share the same
/// scheduler, message bus, task graph, permission engine, and AgentLoop; only
/// their durable capability/workspace leases differ.
public enum CoworkSurfaceProfile: String, Codable, Equatable, Sendable {
    /// Intatis compatibility behavior used by callers that have not selected a
    /// product surface explicitly.
    case legacy
    /// Text-team mode. Agents may coordinate, but no Agent receives filesystem,
    /// shell, Git, browser, media, or document capabilities.
    case chat
    /// Workspace-team mode. Side effects remain gated by PermissionEngine and
    /// durable execution tickets.
    case work

    func capabilityLease(coordinator: Bool,
                         reviewer: Bool,
                         taskID: TaskID? = nil,
                         delegationBudget: DelegationBudget = DelegationBudget(maxTasks: 8, maxDepth: 1)) -> CapabilityLease {
        if reviewer {
            switch self {
            case .chat:
                return CapabilityLease(
                    taskID: taskID,
                    tools: [],
                    communication: .none,
                    delegation: .none,
                    expiresAtTaskCompletion: taskID != nil)
            case .legacy, .work:
                return .taskReviewer(taskID: taskID)
            }
        }

        switch self {
        case .legacy, .work:
            return coordinator
                ? .coordinator(taskID: taskID, budget: delegationBudget)
                : .worker(taskID: taskID)
        case .chat:
            if coordinator {
                return CapabilityLease(
                    taskID: taskID,
                    tools: [
                        .sendMessage,
                        .requestInformation,
                        .replyMessage,
                        .requestDelegation,
                        .delegateTask,
                        .attachWorkspace,
                    ],
                    communication: .anyAgentInThread,
                    delegation: .granted(delegationBudget),
                    expiresAtTaskCompletion: taskID != nil)
            }
            return CapabilityLease(
                taskID: taskID,
                tools: [.replyMessage, .requestDelegation],
                communication: .replyOnly,
                delegation: .requestOnly,
                expiresAtTaskCompletion: taskID != nil)
        }
    }

    func workspaceAccess(coordinator: Bool, reviewer: Bool) -> WorkspaceAccess {
        if reviewer || self == .chat { return .readOnly }
        return coordinator ? .readWrite : .readOnly
    }
}
