import Foundation
import IntatisCore
import IntatisProtocol
import IntatisConversation
import IntatisAgentKernel

func out(_ s: String) { try? FileHandle.standardOutput.write(contentsOf: Data(s.utf8)) }
func errOut(_ s: String) { try? FileHandle.standardError.write(contentsOf: Data(s.utf8)) }

private func truncate(_ s: String, _ n: Int) -> String {
    s.count > n ? String(s.prefix(n)) + "…" : s
}

/// First line only, hard-capped — for collapsed one-liners.
private func oneLine(_ s: String, _ n: Int) -> String {
    let first = s.split(separator: "\n", omittingEmptySubsequences: false).first.map(String.init) ?? ""
    return first.count > n ? String(first.prefix(n)) + "…" : first
}

/// Collapsed tool / terminal output: first line, plus a "(+N 行)" hint if multiline.
private func summary(_ s: String) -> String {
    let lines = s.split(separator: "\n", omittingEmptySubsequences: false)
    let head = oneLine(s, 72)
    let extra = lines.count - 1
    return extra > 0 ? "\(head)  (+\(extra) 行，/verbose 看全部)" : head
}

private func isFailureObservation(_ s: String) -> Bool {
    let lower = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return lower.hasPrefix("tool error:")
        || lower.hasPrefix("permission denied:")
        || lower.hasPrefix("unknown tool:")
        || lower.hasPrefix("invalid tool input:")
}

/// Shared, mutable render verbosity. Collapsed by default; `/verbose` flips it.
final class RenderOptions: @unchecked Sendable {
    private let lock = NSLock()
    private var _verbose: Bool
    init(verbose: Bool = false) { _verbose = verbose }
    var verbose: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _verbose }
        set { lock.lock(); _verbose = newValue; lock.unlock() }
    }
}

/// One-shot commands keep the live renderer, but need a deterministic fence
/// before process exit. A sequence is acknowledged only after its stdout side
/// effects have completed, so waiting on the persisted terminal sequence cannot
/// truncate the answer or require timing sleeps.
actor EventRenderProgress {
    private var highestRenderedSequence = -1
    private var waiters: [(sequence: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func markRendered(_ sequence: Int) {
        highestRenderedSequence = max(highestRenderedSequence, sequence)
        var remaining: [(sequence: Int, continuation: CheckedContinuation<Void, Never>)] = []
        for waiter in waiters {
            if highestRenderedSequence >= waiter.sequence {
                waiter.continuation.resume()
            } else {
                remaining.append(waiter)
            }
        }
        waiters = remaining
    }

    func wait(until sequence: Int) async {
        guard highestRenderedSequence < sequence else { return }
        await withCheckedContinuation { continuation in
            waiters.append((sequence, continuation))
        }
    }
}

// Minimal ANSI helpers.
private let dim = "\u{001B}[2m", cyan = "\u{001B}[36m", yellow = "\u{001B}[33m"
private let magenta = "\u{001B}[35m", red = "\u{001B}[31m", reset = "\u{001B}[0m"

/// Streams events from the log to stdout as they arrive. It only writes stdout
/// (never reads stdin), so it runs concurrently with the input loop and the
/// permission prompt with no contention.
func renderLoop(_ log: EventLog, showAgentLabels: Bool = false, spinner: TurnSpinner? = nil,
                options: RenderOptions = RenderOptions(),
                progress: EventRenderProgress? = nil,
                mandatoryTaskReview: Bool = false) async {
    let stream = await log.stream(from: 0)
    var currentMessage = ""
    var reviewGate = MandatoryReviewPresentationGate()
    for await env in stream {
        let presentation: MandatoryReviewPresentationDecision
        if mandatoryTaskReview {
            presentation = reviewGate.apply(env)
        } else {
            presentation = .show
        }
        if case .hide = presentation {
            await progress?.markRendered(env.seq)
            continue
        }
        if case .deliver(let payload) = presentation {
            spinner?.stop()
            if showAgentLabels {
                out("\n\(cyan)● \(payload.agent.rawValue)\(reset)\n")
            }
            out(payload.result)
            if !payload.result.hasSuffix("\n") { out("\n") }
            await progress?.markRendered(env.seq)
            continue
        }
        // Keep the "Thinking…" line alive through the pre-output events
        // (user_message, agent_status); stop it only when real output arrives.
        switch env.event {
        case .userMessage, .agentStatus: break
        default: spinner?.stop()
        }
        switch env.event {
        case .messageDelta(let p):
            if showAgentLabels, let agent = p.agent, p.messageId.rawValue != currentMessage {
                out("\n\(cyan)● \(agent.rawValue)\(reset)\n")
                currentMessage = p.messageId.rawValue
            }
            out(p.textDelta)
        case .messageCompleted:
            out("\n")
        case .toolCall(let p):
            let args = options.verbose ? truncate(p.args, 800) : oneLine(p.args, 72)
            out("\n  \(cyan)· \(p.name)\(reset) \(dim)\(args)\(reset)\n")
        case .toolResult(let p):
            let color = isFailureObservation(p.observation) ? red : dim
            if options.verbose {
                out("  \(color)⎿\(reset) \(truncate(p.observation, 4000))\n")
            } else {
                out("  \(color)⎿ \(summary(p.observation))\(reset)\n")
            }
        case .permissionResolved(let p):
            out("  \(yellow)[\(p.decision.rawValue): \(p.tool) — \(p.reason)]\(reset)\n")
        case .permissionReview(let p):
            out("  \(yellow)[review \(p.decision.rawValue): \(p.tool) by \(p.reviewerModel) — \(p.reason)]\(reset)\n")
        case .patchProposed(let p):
            out("  \(magenta)± patch: \(p.files.joined(separator: ", "))\(reset)\n")
        case .agentToAgentMessage(let p):
            out("  \(cyan)↔ \(p.from.rawValue)→\(p.to.rawValue):\(reset) \(truncate(p.content, 300))\n")
        case .artifactAdded(let p):
            out("  📎 \(p.kind): \(p.path)\n")
        case .turnStats(let p):
            var parts: [String] = []
            if let total = p.totalMillis { parts.append(String(format: "%.1fs", Double(total) / 1000)) }
            if let ttft = p.ttftMillis { parts.append("ttft \(String(format: "%.2fs", Double(ttft) / 1000))") }
            if let tot = p.totalTokens {
                if let pin = p.promptTokens, let pout = p.completionTokens {
                    parts.append("\(tot) tok (\(pin) in / \(pout) out)")
                } else {
                    parts.append("\(tot) tok")
                }
            }
            if !parts.isEmpty { out("  \(dim)⎿ \(parts.joined(separator: " · "))\(reset)\n") }
        case .error(let p):
            out("  \(red)! \(p.message)\(reset)\n")
        default:
            break
        }
        await progress?.markRendered(env.seq)
    }
}

/// Terminal approval for `ask_user` decisions (Code mode).
struct TerminalResponder: PermissionResponder {
    func requestApproval(_ request: PermissionRequestPayload) async -> PermissionDecision {
        await TerminalPermissionPromptQueue.shared.requestApproval(request)
    }
}

/// `readLine()` is process-global and cannot safely serve two permission
/// continuations concurrently. The control-plane fallback is FIFO, and this
/// queue also protects direct manual approvals after `/default`.
private actor TerminalPermissionPromptQueue {
    static let shared = TerminalPermissionPromptQueue()

    func requestApproval(_ request: PermissionRequestPayload) -> PermissionDecision {
        out("\n  \(yellow)⚠ [\(request.requestId.rawValue)] \(request.tool) (\(request.risk.rawValue)) — \(request.reason)\(reset)\n  approve this request? [y/N] ")
        guard let line = readLine() else { return .deny }
        let answer = line.trimmingCharacters(in: .whitespaces).lowercased()
        return (answer == "y" || answer == "yes") ? .allow : .deny
    }
}
