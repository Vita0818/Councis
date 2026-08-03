import Foundation

/// Session-visible health for the reserved `@judge` identity.
///
/// The Judge remains a scheduler-backed data-plane agent, but its identity and
/// failure boundary are managed as a session service. In particular, a provider
/// call whose termination cannot be proven quarantines further Judge model work
/// until the process restarts.
public enum TaskReviewerLifecycleHealth: Equatable, Sendable {
    case disabled
    case healthy
    case degraded(String)
    case quarantined(String)
    case shuttingDown
}

enum TaskReviewerProviderActivityBegin: Equatable {
    case started(UUID)
    case unavailable(String)
}

enum TaskReviewerProviderActivityStatus: Equatable {
    case idle
    case active
    case quarantined(String)
}

/// Tracks the real provider-operation lifetime rather than only the outer
/// timeout race. Quarantine is intentionally sticky for the process lifetime:
/// a late, cancellation-ignoring provider cannot clear it.
final class TaskReviewerProviderActivity: @unchecked Sendable {
    private let lock = NSLock()
    private var activeToken: UUID?
    private var quarantineReason: String?

    func begin() -> TaskReviewerProviderActivityBegin {
        lock.lock()
        defer { lock.unlock() }
        if let quarantineReason {
            return .unavailable(quarantineReason)
        }
        guard activeToken == nil else {
            return .unavailable("another @judge provider operation is still active")
        }
        let token = UUID()
        activeToken = token
        return .started(token)
    }

    func finish(_ token: UUID) {
        lock.lock()
        defer { lock.unlock() }
        guard quarantineReason == nil, activeToken == token else { return }
        activeToken = nil
    }

    @discardableResult
    func quarantine(_ token: UUID, reason: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        if let quarantineReason {
            return quarantineReason
        }
        guard activeToken == token else {
            let normalized = reason.isEmpty
                ? "@judge provider termination could not be proven"
                : reason
            quarantineReason = normalized
            return normalized
        }
        let normalized = reason.isEmpty
            ? "@judge provider termination could not be proven"
            : reason
        quarantineReason = normalized
        return normalized
    }

    /// A replacement Orchestrator in the same process must not overlap a
    /// provider operation left behind by an earlier runtime instance.
    @discardableResult
    func quarantineUnprovenPreviousOperation() -> String? {
        lock.lock()
        defer { lock.unlock() }
        if let quarantineReason {
            return quarantineReason
        }
        guard activeToken != nil else { return nil }
        let reason = "a previous @judge provider operation is still active in this process"
        quarantineReason = reason
        return reason
    }

    func status() -> TaskReviewerProviderActivityStatus {
        lock.lock()
        defer { lock.unlock() }
        if let quarantineReason {
            return .quarantined(quarantineReason)
        }
        return activeToken == nil ? .idle : .active
    }
}

/// Shares the provider boundary across Orchestrator replacements for the same
/// EventLog session. A process restart is the deliberate recovery boundary.
final class TaskReviewerProviderActivityRegistry: @unchecked Sendable {
    static let shared = TaskReviewerProviderActivityRegistry()

    private let lock = NSLock()
    private var activities: [String: TaskReviewerProviderActivity] = [:]

    func activity(for coordinationKey: String) -> TaskReviewerProviderActivity {
        lock.lock()
        defer { lock.unlock() }
        if let activity = activities[coordinationKey] {
            return activity
        }
        let activity = TaskReviewerProviderActivity()
        activities[coordinationKey] = activity
        return activity
    }
}
