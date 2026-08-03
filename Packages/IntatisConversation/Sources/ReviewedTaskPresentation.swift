import Foundation
import IntatisCore
import IntatisProtocol

/// A deterministic presentation boundary for runtimes that require every root
/// task to pass the durable task-review gate.
///
/// Raw assistant-message output remains in the append-only log for agent
/// context and audit, but it is never a user-visible answer. Internal
/// collaboration tool content is hidden as well; ordinary tool, permission,
/// patch, and artifact audit may remain visible. The only answer this
/// projection releases is a root `task_completed` whose exact task attempt
/// already has a persisted approving `task_review_settled` event. Folding a
/// historical log and consuming the same events live therefore produce the
/// same result.
public struct MandatoryReviewPresentationGate: Equatable, Sendable {
    private struct TaskAttempt: Hashable, Sendable {
        var taskID: TaskID
        var attempt: Int?
    }

    private var approvedAttempts: Set<TaskAttempt> = []
    private var deliveredAttempts: Set<TaskAttempt> = []
    private var toolVisibilityByCallID: [String: Bool] = [:]

    /// These tools carry agent-to-agent content or internal task contracts in
    /// their raw arguments/results. The durable tool events remain available
    /// for audit and agent context, but the strict product thread must not
    /// reveal the same content through a tool-event side channel after hiding
    /// the semantic communication/task events.
    private static let internalContentToolNames: Set<String> = [
        "ask_agent",
        "delegate_task",
        "reply_message",
        "request_delegation",
        "request_information",
        "send_message",
    ]

    /// Known product tools whose args/results are deliberately visible as an
    /// operational audit trail. Unknown names fail closed. Keep this list in
    /// sync with the shipped IntatisTools and coordinator descriptors when a
    /// new tool is intentionally added to the strict product surface.
    private static let operationalAuditToolNames: Set<String> = [
        "apply_patch",
        "browser_back", "browser_click", "browser_diagnostics",
        "browser_download", "browser_downloads", "browser_forward",
        "browser_handoff", "browser_history", "browser_navigate",
        "browser_press_key", "browser_profile_delete", "browser_profiles",
        "browser_reload", "browser_screenshot", "browser_scroll",
        "browser_search", "browser_select_option", "browser_snapshot",
        "browser_submit", "browser_type", "browser_upload_file", "browser_wait",
        "compile_latex", "edit_pdf_pages", "generate_image",
        "git_apply_patch", "git_apply_patch_check", "git_branch", "git_commit",
        "git_create_branch", "git_diff", "git_diff_base", "git_diff_staged",
        "git_fetch", "git_info", "git_pull_ff", "git_push", "git_recent_commits",
        "git_remotes", "git_revert_patch", "git_stage", "git_stage_patch",
        "git_status", "git_switch", "git_unstage", "git_unstage_patch",
        "git_worktree_create", "git_worktree_list", "git_worktree_remove",
        "list_agents", "list_files", "read_file", "read_pdf",
        "reconstruct_document_image", "remove_agent", "run_shell", "search_text",
        "spawn_agent", "web_fetch", "write_file",
    ]

    public init() {}

    public mutating func apply(
        _ envelope: Envelope
    ) -> MandatoryReviewPresentationDecision {
        switch envelope.event {
        case .taskReviewSettled(let payload):
            let key = TaskAttempt(taskID: payload.rootTaskID, attempt: payload.rootAttempt)
            if payload.error == nil, payload.verdict?.decision == .approve {
                approvedAttempts.insert(key)
            } else {
                approvedAttempts.remove(key)
            }
            return .hide

        case .taskReviewExhausted(let payload):
            let key = TaskAttempt(taskID: payload.rootTaskID, attempt: payload.rootAttempt)
            approvedAttempts.remove(key)
            return .hide

        case .taskCompleted(let payload):
            let key = TaskAttempt(taskID: payload.taskID, attempt: payload.attempt)
            guard approvedAttempts.contains(key),
                  deliveredAttempts.insert(key).inserted else {
                return .hide
            }
            return .deliver(payload)

        case .taskFailed(let payload):
            approvedAttempts.remove(TaskAttempt(taskID: payload.taskID, attempt: payload.attempt))
            return .show

        case .taskCancelled(let payload):
            approvedAttempts.remove(TaskAttempt(taskID: payload.taskID, attempt: payload.attempt))
            return .show

        case .userMessage(let payload):
            return payload.presentation == .userVisible ? .show : .hide

        // Model text is execution evidence, not presentation. This includes
        // every Main draft/revision and the Judge's raw JSON before mediation.
        case .messageDelta, .messageCompleted:
            return .hide

        case .toolCall(let payload):
            // A duplicate in-flight id makes later results ambiguous. Once a
            // collision is observed, keep the id hidden until its result is
            // consumed instead of allowing a visible call to overwrite a
            // hidden collaboration classification.
            if toolVisibilityByCallID[payload.toolCallId] != nil {
                toolVisibilityByCallID[payload.toolCallId] = false
                return .hide
            }
            let visible = Self.operationalAuditToolNames.contains(payload.name)
                && !Self.internalContentToolNames.contains(payload.name)
            toolVisibilityByCallID[payload.toolCallId] = visible
            return visible ? .show : .hide

        case .toolResult(let payload):
            // An orphan result has no trustworthy tool classification, so the
            // strict projection fails closed instead of exposing its body.
            guard let visible = toolVisibilityByCallID.removeValue(forKey: payload.toolCallId) else {
                return .hide
            }
            return visible ? .show : .hide

        // Agent communication and task contracts are internal data-plane
        // records. Their content may contain worker inputs, review evidence, or
        // an unmediated Judge verdict, so the strict product thread hides them.
        case .agentMessage, .agentToAgentMessage,
             .informationRequested, .informationReplied,
             .delegationRequested, .delegationApproved, .delegationRejected,
             .taskDelegated, .taskCreated, .taskAssigned, .taskQueued,
             .taskStarted, .taskRejected, .taskReviewRequested:
            return .hide

        case .toolExecutionPrepared, .toolExecutionSettled,
             .permissionRequest, .permissionResolved, .patchProposed, .agentStatus,
             .agentAttached, .agentAttachRequested, .agentDetached,
             .agentSpawnRequested, .agentSpawned, .agentModelBound,
             .agentMessageConsumed, .permissionReview,
             .permissionReviewRequested, .permissionReviewSettled,
             .workspaceLeaseRequested, .workspaceLeaseGranted,
             .workspaceLeaseDenied, .workspaceLeaseRevoked,
             .capabilityLeaseCreated, .capabilityLeaseRevoked,
             .artifactAdded, .artifactProgress, .turnStats, .error:
            return .show
        }
    }
}

public enum MandatoryReviewPresentationDecision: Equatable, Sendable {
    case show
    case hide
    case deliver(TaskCompletedPayload)
}
