#if canImport(SwiftUI)
import Foundation
import SwiftUI
import CouncisCore
import CouncisProtocol
import CouncisConversation

private func councisLocalizedAgentState(_ state: String) -> String {
    switch state {
    case AgentState.idle.rawValue:
        return CouncisLocalization.string("Idle")
    case AgentState.thinking.rawValue:
        return CouncisLocalization.string("Thinking")
    case AgentState.tool.rawValue:
        return CouncisLocalization.string("Tool")
    case AgentState.blocked.rawValue:
        return CouncisLocalization.string("Blocked")
    default:
        return state
    }
}

/// Presentational Code thread (v0.2). All data + callbacks are injected, so the
/// kernel-driving view model lives in the app, not here (keeps SharedUI free of
/// Tools/Permission/AgentKernel dependencies).
public struct CodeShell: View {
    private let displayedItems: [CodeItem]
    private let threadErrors: [CouncisThreadErrorEntry]
    private let presentationScope: CouncisThreadPresentationScope
    private let sessionTitle: String
    private let thinkingPhaseID: String
    private let pending: PendingPermission?
    private let permissionNotice: PermissionResolutionNotice?
    private let latestTurnStats: TurnStatsSnapshot?
    private let isWorking: Bool
    private let workspaceName: String
    private let agentState: String
    private let threadStyle: CouncisThreadStyle
    private let onShowSessions: (() -> Void)?
    private let onNewSession: (() -> Void)?
    private let composerAccessory: AnyView?
    private let composerTrailingAction:
        CouncisThreadComposerSecondaryAction?
    private let headerActions: [CouncisThreadHeaderAction]
    @Binding private var input: String
    private let onSend: () -> Void
    private let onCancelCurrent: (() -> Void)?
    private let onResolve: (PermissionResponseAction) -> Void
    @Binding private var showsInspector: Bool
    @StateObject private var scrollCoordinator = CouncisThreadScrollCoordinator()
    @State private var historySelection: CouncisThreadHistorySelection?

    public init(items: [CodeItem],
                presentationScope: CouncisThreadPresentationScope,
                sessionTitle: String = CouncisLocalization.string("Code"),
                thinkingScopeID: String = "code",
                pending: PendingPermission?,
                permissionNotice: PermissionResolutionNotice? = nil,
                latestTurnStats: TurnStatsSnapshot? = nil,
                isWorking: Bool,
                workspaceName: String,
                agentState: String,
                errorTexts: [String] = [],
                threadStyle: CouncisThreadStyle = .standard(.light),
                splitLayout: CouncisSplitColumnLayout = .workspace,
                onShowSessions: (() -> Void)? = nil,
                onNewSession: (() -> Void)? = nil,
                composerAccessory: AnyView? = nil,
                composerTrailingAction:
                    CouncisThreadComposerSecondaryAction? = nil,
                headerActions: [CouncisThreadHeaderAction] = [],
                showsInspector: Binding<Bool>,
                input: Binding<String>,
                onSend: @escaping () -> Void,
                onCancelCurrent: (() -> Void)? = nil,
                onResolve: @escaping (PermissionResponseAction) -> Void) {
        self.displayedItems = CouncisThreadErrorPresentation.transcriptItems(
            CouncisExecutionTracePresentation.displayedItems(items))
        self.threadErrors = CouncisThreadErrorPresentation.errors(
            items: items,
            errorTexts: errorTexts)
        self.presentationScope = presentationScope
        self.sessionTitle = sessionTitle
        self.thinkingPhaseID = "\(thinkingScopeID):\(items.last?.id ?? "initial")"
        self.pending = pending
        self.permissionNotice = permissionNotice
        self.latestTurnStats = latestTurnStats
        self.isWorking = isWorking
        self.workspaceName = workspaceName
        self.agentState = agentState
        self.threadStyle = threadStyle
        self.onShowSessions = onShowSessions
        self.onNewSession = onNewSession
        self.composerAccessory = composerAccessory
        self.composerTrailingAction = composerTrailingAction
        self.headerActions = headerActions
        self._showsInspector = showsInspector
        self._input = input
        self.onSend = onSend
        self.onCancelCurrent = onCancelCurrent
        self.onResolve = onResolve
        _ = splitLayout
    }

    private var permissionBlocksComposer: Bool {
        guard let pending else { return false }
        return pending.state == .livePending || pending.state == .resolving
    }

    public var body: some View {
        GeometryReader { proxy in
            content(rawWidth: proxy.size.width)
        }
    }

    private func content(rawWidth: CGFloat) -> some View {
        let inspectorLayout = CouncisWorkspaceInspectorLayoutPolicy.resolve(
            availableWidth: rawWidth,
            isRequested: showsInspector,
            activationWidth: 940,
            minimumThreadWidth: 620,
            minimumInspectorWidth: 260,
            idealInspectorWidth: 292,
            maximumInspectorWidth: 360)

        return HStack(spacing: 0) {
            threadColumn(
                layout: CouncisThreadContentLayout(
                    rawWidth: inspectorLayout.threadWidth),
                inspectorIsAvailable: rawWidth >= 940)
                .frame(width: inspectorLayout.threadWidth)
                .frame(maxHeight: .infinity)
            if inspectorLayout.isVisible {
                Divider()
                CodeInspectorView(
                    workspaceName: workspaceName,
                    agentState: agentState,
                    itemCount: displayedItems.count,
                    pending: pending,
                    errors: threadErrors,
                    style: threadStyle)
                    .frame(width: inspectorLayout.inspectorWidth)
                    .frame(maxHeight: .infinity)
                    .background(.bar)
                    .accessibilityIdentifier("code.inspector")
            }
        }
    }

    private func threadColumn(
        layout: CouncisThreadContentLayout,
        inspectorIsAvailable: Bool
    ) -> some View {
        VStack(spacing: 0) {
            header(
                layout: layout,
                inspectorIsAvailable: inspectorIsAvailable)
            thread(layout: layout)
            permissionArea(layout: layout)
            composerArea(layout: layout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func header(
        layout: CouncisThreadContentLayout,
        inspectorIsAvailable: Bool
    ) -> some View {
        CouncisWorkspaceThreadHeader(
            title: sessionTitle,
            subtitle: nil,
            style: threadStyle,
            actions: headerActions + [inspectorAction(
                isAvailable: inspectorIsAvailable)])
        .frame(maxWidth: layout.contentMaxWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, layout.horizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    private func inspectorAction(
        isAvailable: Bool
    ) -> CouncisThreadHeaderAction {
        let title = showsInspector && isAvailable
            ? CouncisLocalization.string("Hide Inspector")
            : CouncisLocalization.string("Show Inspector")
        return CouncisThreadHeaderAction(
            title: title,
            systemImage: "sidebar.right",
            isDisabled: !isAvailable,
            isIconOnly: true,
            help: title,
            accessibilityIdentifier: "code.inspector.toggle") {
                guard isAvailable else { return }
                showsInspector.toggle()
            }
    }

    @ViewBuilder private func thread(layout: CouncisThreadContentLayout) -> some View {
        if displayedItems.isEmpty && !showsThinkingIndicator {
            CodeEmptyThreadView(style: threadStyle)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, layout.horizontalPadding)
        } else {
            let historyWindow = threadHistoryWindow
            let pageScope = threadPresentationScope
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if historyWindow.hasEarlier || historyWindow.hasLater {
                            CouncisThreadHistoryPager(
                                lowerBound: historyWindow.lowerBound,
                                upperBound: historyWindow.upperBound,
                                totalCount: historyWindow.totalCount,
                                hasEarlier: historyWindow.hasEarlier,
                                hasLater: historyWindow.hasLater,
                                accessibilityPrefix: "code.history",
                                onEarlier: {
                                    selectHistoryWindow(
                                        historyWindow.earlierRequestedUpperBound)
                                },
                                onNewer: {
                                    selectHistoryWindow(
                                        historyWindow.newerRequestedUpperBound)
                                },
                                onLatest: {
                                    selectHistoryWindow(nil)
                                })
                        }
                        ForEach(historyWindow.items) { item in
                            CodeItemRow(item: item, style: threadStyle, layout: layout)
                                .id(item.id)
                        }
                        if showsVisibleThinkingIndicator {
                            CouncisThreadThinkingRow(
                                layout: layout,
                                style: threadStyle,
                                phaseID: thinkingPhaseID)
                                .id("councis-code-thinking-\(thinkingPhaseID)")
                        }
                        Color.clear
                            .frame(height: 1)
                            .padding(.bottom, 16)
                            .id(CouncisThreadBottomAnchorID(scope: pageScope))
                            .onScrollVisibilityChange(threshold: 0.99) {
                                isVisible in
                                scrollCoordinator
                                    .enqueueBottomAnchorVisibility(
                                        isVisible,
                                        scope: pageScope)
                            }
                    }
                    .environment(
                        \.councisMessageViewportAdmission,
                        scrollCoordinator.effectiveViewportAdmission(
                            for: pageScope,
                            defersUntilInitialRestore:
                                defersRichUntilInitialRestore))
                    .environment(
                        \.councisThreadScrollCoordinator,
                        scrollCoordinator)
                    .environment(
                        \.councisThreadRichSettleSource,
                        scrollCoordinator.effectiveRichSettleSource(
                            for: pageScope))
                    .frame(width: layout.contentWidth)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, layout.horizontalPadding)
                    .padding(.top, 16)
                }
                .scrollContentBackground(.hidden)
                .overlay(alignment: .bottomTrailing) {
                    if historyWindow.hasLater
                        || scrollCoordinator.followState == .detachedByUser {
                        CouncisJumpToLatestButton(
                            accessibilityIdentifier: "code.jump-to-latest"
                        ) {
                            if historyWindow.hasLater {
                                selectHistoryWindow(nil)
                            } else {
                                scrollCoordinator.jumpToLatest(
                                    scope: pageScope,
                                    perform: scrollPerformer(proxy))
                            }
                        }
                    }
                }
                .onAppear {
                    scrollCoordinator.activate(
                        scope: pageScope,
                        defersRichUntilInitialRestore:
                            defersRichUntilInitialRestore)
                    requestScroll(
                        proxy,
                        reason: .initialRestore,
                        scope: pageScope)
                }
                .onChange(of: itemScrollSignature) { _, _ in
                    guard historyWindow.isLatest else { return }
                    requestScroll(
                        proxy,
                        reason: scrollReason,
                        scope: pageScope)
                }
                .onChange(of: layout.contentWidth) { _, _ in
                    scrollCoordinator.openWidthSettleEpoch(
                        scope: pageScope,
                        width: layout.contentWidth,
                        perform: scrollPerformer(proxy))
                }
                .onScrollGeometryChange(
                    for: CouncisThreadScrollGeometry.self
                ) { geometry in
                    CouncisThreadScrollGeometry.measure(
                        contentOffsetY: geometry.contentOffset.y,
                        containerHeight: geometry.containerSize.height,
                        bottomInset: geometry.contentInsets.bottom,
                        contentHeight: geometry.contentSize.height)
                } action: { _, current in
                    scrollCoordinator.enqueueGeometryObservation(
                        current.isAtBottom,
                        contentHeight: current.contentHeight,
                        scope: pageScope)
                }
                .onScrollPhaseChange { _, newPhase in
                    switch newPhase {
                    case .tracking, .interacting, .decelerating:
                        scrollCoordinator.userInteractionDidBegin(
                            scope: pageScope)
                    case .idle:
                        scrollCoordinator.userInteractionDidEnd(
                            scope: pageScope)
                    case .animating:
                        break
                    }
                }
                .onDisappear {
                    scrollCoordinator.deactivate(scope: pageScope)
                }
            }
            .id(pageScope)
        }
    }

    private var showsThinkingIndicator: Bool {
        CouncisThreadActivity.isAwaitingModelOutput(
            items: displayedItems,
            isWorking: isWorking,
            permissionBlocksResponse: permissionBlocksComposer)
    }

    private var defersRichUntilInitialRestore: Bool {
        CouncisThreadRichEntryPolicy.defersUntilInitialRestore(
            richRowCount: threadHistoryWindow.items.count)
    }

    private var threadHistoryWindow: CouncisThreadHistoryWindow<CodeItem> {
        .resolve(
            allItems: displayedItems,
            requestedUpperBound: requestedHistoryWindowUpperBound)
    }

    private var requestedHistoryWindowUpperBound: Int? {
        historySelection?.upperBound(for: presentationScope)
    }

    private var threadPresentationScope: CouncisThreadPresentationScope {
        presentationScope.historyWindowScope(
            requestedUpperBound: requestedHistoryWindowUpperBound)
    }

    private func selectHistoryWindow(_ requestedUpperBound: Int?) {
        historySelection = CouncisThreadHistorySelection(
            scope: presentationScope,
            requestedUpperBound: requestedUpperBound)
    }

    private var showsVisibleThinkingIndicator: Bool {
        threadHistoryWindow.isLatest && showsThinkingIndicator
    }

    private var itemScrollSignature: CouncisThreadScrollSignature {
        let historyWindow = threadHistoryWindow
        let last = historyWindow.items.last
        return CouncisThreadScrollSignature(
            visibleItemCount: historyWindow.items.count,
            lastItemID: last?.id,
            lastBodyUTF8Count: last?.body.utf8.count ?? 0,
            lastItemComplete: last?.complete ?? false,
            isWorking: historyWindow.isLatest && isWorking,
            showsThinkingIndicator: showsVisibleThinkingIndicator)
    }

    private var scrollReason: CouncisThreadScrollReason {
        let historyWindow = threadHistoryWindow
        guard let last = historyWindow.items.last else {
            return .liveUpdate
        }
        let visibleIsWorking = historyWindow.isLatest && isWorking
        return last.complete && !visibleIsWorking
            ? .completion
            : .liveUpdate
    }

    private func requestScroll(
        _ proxy: ScrollViewProxy,
        reason: CouncisThreadScrollReason,
        scope: CouncisThreadPresentationScope
    ) {
        scrollCoordinator.request(
            scope: scope,
            reason: reason,
            perform: scrollPerformer(proxy))
    }

    private func scrollPerformer(
        _ proxy: ScrollViewProxy
    ) -> @MainActor (CouncisThreadScrollRequest) -> Void {
        { request in
            let anchorID = CouncisThreadBottomAnchorID(scope: request.scope)
            proxy.scrollTo(anchorID, anchor: .bottom)
        }
    }

    @ViewBuilder private func permissionArea(layout: CouncisThreadContentLayout) -> some View {
        if let pending {
            PermissionCard(permission: pending, onResolve: onResolve)
                .frame(maxWidth: layout.contentMaxWidth, alignment: .leading)
                .padding(.horizontal, layout.horizontalPadding)
        } else if let permissionNotice {
            PermissionResolutionNoticeView(notice: permissionNotice)
                .frame(maxWidth: layout.contentMaxWidth, alignment: .leading)
                .padding(.horizontal, layout.horizontalPadding)
        }
    }

    private func composerArea(layout: CouncisThreadContentLayout) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CouncisThreadComposer(
                placeholder: CouncisLocalization.string("Message Coder..."),
                input: $input,
                canSend: !isWorking
                    && !permissionBlocksComposer
                    && composerTrailingAction?.blocksSubmission != true
                    && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                isInputDisabled: isWorking || permissionBlocksComposer,
                style: threadStyle,
                leadingAccessory: composerAccessory,
                trailingAction: composerTrailingAction,
                stopAction: isWorking
                    ? onCancelCurrent.map { onCancelCurrent in
                        CouncisThreadComposerSecondaryAction(
                            systemImage: "stop.fill",
                            help: CouncisLocalization.string("Stop"),
                            action: onCancelCurrent)
                    }
                    : nil,
                accessory: {
                    CouncisComposerUsageStrip(
                        stats: latestTurnStats,
                        style: threadStyle)
                },
                onSend: {
                    selectHistoryWindow(nil)
                    onSend()
                })
        }
        .frame(maxWidth: layout.contentMaxWidth)
        .padding(.horizontal, layout.horizontalPadding)
        .padding(.top, 10)
        .padding(.bottom, 22)
    }
}

struct CodeItemRow: View {
    let item: CodeItem
    let style: CouncisThreadStyle
    let layout: CouncisThreadContentLayout
    let onRetrySubmission: ((SubmissionID) -> Void)?

    init(item: CodeItem,
         style: CouncisThreadStyle = .standard(.light),
         layout: CouncisThreadContentLayout = CouncisThreadContentLayout(rawWidth: 900),
         onRetrySubmission: ((SubmissionID) -> Void)? = nil) {
        self.item = item
        self.style = style
        self.layout = layout
        self.onRetrySubmission = onRetrySubmission
    }

    var body: some View {
        switch item.kind {
        case .user:
            bubble(
                title: nil,
                body: item.body,
                isUser: true,
                tags: item.tags)
        case .agent:
            bubble(title: item.title, body: item.body.isEmpty && !item.complete ? "…" : item.body,
                   isUser: false)
        case .toolCall:
            if item.isFailure || item.recoveryAdvice != nil {
                EmptyView()
            } else {
                card(
                    icon: "wrench.and.screwdriver",
                    title: CouncisLocalization.format("tool · %@", item.title),
                    body: item.body,
                    tint: .blue)
            }
        case .toolResult:
            if item.isFailure || item.recoveryAdvice != nil {
                EmptyView()
            } else {
                card(
                    icon: "arrow.turn.down.right",
                    title: item.title,
                    body: item.body,
                    tint: .gray)
            }
        case .patch:
            if item.isFailure || item.recoveryAdvice != nil {
                EmptyView()
            } else {
                card(
                    icon: "doc.badge.gearshape",
                    title: CouncisLocalization.format(
                        "patch · %@",
                        item.files.joined(separator: ", ")),
                    body: item.body,
                    tint: .purple)
            }
        case .note:
            if item.isFailure || item.recoveryAdvice != nil {
                EmptyView()
            } else {
                Text(item.body).font(.caption).foregroundStyle(.secondary)
            }
        case .error:
            EmptyView()
        case .agentToAgent:
            bubble(
                title: item.title,
                body: item.body.isEmpty && !item.complete ? "…" : item.body,
                isUser: false)
        }
    }

    private func bubble(title: String?, body: String, isUser: Bool, tags: [String] = []) -> some View {
        CouncisThreadBubbleRow(
            isTrailing: isUser,
            fillsAvailableWidth: !isUser,
            rowWidth: layout.contentWidth,
            maxWidth: layout.messageMaxWidth,
            gutter: layout.messageGutter) {
                bubbleContent(title: title, body: body, isUser: isUser, tags: tags)
            }
    }

    @ViewBuilder private func bubbleContent(title: String?,
                                            body: String,
                                            isUser: Bool,
                                            tags: [String]) -> some View {
        if isUser {
            bubbleBody(title: title, body: body, isUser: isUser, tags: tags)
                .padding(.horizontal, 15)
                .padding(.vertical, 11)
                .councisLiquidGlass(cornerRadius: 16)
        } else {
            bubbleBody(title: title, body: body, isUser: false, tags: tags)
                .padding(.vertical, 8)
        }
    }

    private func bubbleBody(title: String?,
                            body: String,
                            isUser: Bool,
                            tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if title != nil || !tags.isEmpty {
                HStack(spacing: 6) {
                    if let title {
                        Text(displayTitle(title))
                            .font(.caption2.bold())
                            .foregroundStyle(
                                isUser ? style.accent : style.tertiaryText)
                    }
                    if !isUser, let timestamp = item.timestamp {
                        Text(CouncisMessageTimestampPresentation.string(for: timestamp))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(style.tertiaryText)
                    }
                    ForEach(tags, id: \.self) { tag in
                        tagBadge(tag)
                    }
                }
            }
            if isUser {
                if !body.isEmpty {
                    Text(body)
                        .font(.system(size: 15))
                        .foregroundStyle(style.primaryText)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !item.attachments.isEmpty {
                    Label(
                        item.attachments.count == 1
                            ? CouncisLocalization.format(
                                "%lld attachment",
                                Int64(item.attachments.count))
                            : CouncisLocalization.format(
                                "%lld attachments",
                                Int64(item.attachments.count)),
                        systemImage: "paperclip")
                        .font(.caption)
                        .foregroundStyle(style.secondaryText)
                }
            } else {
                CouncisMessageContentView(
                    messageID: item.id,
                    rawText: item.body,
                    isComplete: item.complete,
                    policy: .richText,
                    style: style)
            }
            if isUser,
               let submissionID = item.submissionID,
               let submissionStatus = item.submissionStatus,
               submissionStatus != .failed,
               item.submissionFailure == nil {
                submissionStatusView(
                    id: submissionID,
                    status: submissionStatus,
                    failure: item.submissionFailure)
            }
        }
    }

    private func displayTitle(_ title: String) -> String {
        title == "Agent" ? "Councis" : title
    }

    private func submissionStatusView(
        id: SubmissionID,
        status: SubmissionStatus,
        failure: SubmissionFailure?
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: submissionStatusIcon(status))
                .foregroundStyle(status == .failed || status == .cancelled
                    ? style.error
                    : style.secondaryText)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(submissionStatusLabel(status))
                    .font(.caption2.bold())
                    .foregroundStyle(status == .failed || status == .cancelled
                        ? style.error
                        : style.secondaryText)
                if let failure {
                    Text(failure.message)
                        .font(.caption2)
                        .foregroundStyle(style.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 4)
            if failure?.retryable == true, let onRetrySubmission {
                Button("Retry") { onRetrySubmission(id) }
                    .buttonStyle(.borderless)
                    .font(.caption.bold())
                    .accessibilityIdentifier("submission.\(id.rawValue).retry")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("submission.\(id.rawValue).status")
    }

    private func submissionStatusLabel(_ status: SubmissionStatus) -> String {
        switch status {
        case .queued: return CouncisLocalization.string("Queued locally")
        case .running: return CouncisLocalization.string("Running")
        case .completed: return CouncisLocalization.string("Completed")
        case .failed: return CouncisLocalization.string("Needs attention")
        case .cancelled: return CouncisLocalization.string("Cancelled")
        }
    }

    private func submissionStatusIcon(_ status: SubmissionStatus) -> String {
        switch status {
        case .queued: return "clock"
        case .running: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }

    private func card(icon: String, title: String, body: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon).font(.caption.bold()).foregroundStyle(tint)
            Text(body).font(.system(.caption, design: .monospaced))
                .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(11)
        .councisContentSurface(cornerRadius: 8)
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(tint.opacity(0.25)))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .frame(maxWidth: min(layout.contentMaxWidth, 740), alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tagBadge(_ tag: String) -> some View {
        Text(tag.uppercased())
            .font(.caption2.bold())
            .foregroundStyle(style.accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay { Capsule().stroke(style.stroke, lineWidth: 1) }
    }
}

private struct CodeEmptyThreadView: View {
    let style: CouncisThreadStyle

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(style.accent)
                .frame(width: 76, height: 76)
            Spacer()
        }
        .multilineTextAlignment(.center)
    }
}

private struct PermissionReviewSurfaceModifier: ViewModifier {
    let isEnabled: Bool
    let cornerRadius: CGFloat

    @ViewBuilder func body(content: Content) -> some View {
        if isEnabled {
            content.councisSubtleContentSurface(cornerRadius: cornerRadius)
        } else {
            content
        }
    }
}

public enum PermissionReviewCardStyle: Equatable, Sendable {
    case standard
    case compactRail
}

public struct PermissionResolutionNoticeView: View {
    let notice: PermissionResolutionNotice
    private let embedsSurface: Bool
    private let presentationStyle: PermissionReviewCardStyle

    public init(notice: PermissionResolutionNotice,
                embedsSurface: Bool = true,
                presentationStyle: PermissionReviewCardStyle = .standard) {
        self.notice = notice
        self.embedsSurface = embedsSurface
        self.presentationStyle = presentationStyle
    }

    @ViewBuilder public var body: some View {
        Group {
            switch presentationStyle {
            case .standard:
                standardContent
            case .compactRail:
                compactRailContent
            }
        }
        .modifier(PermissionReviewSurfaceModifier(
            isEnabled: embedsSurface,
            cornerRadius: presentationStyle == .compactRail ? 14 : 10))
        .accessibilityIdentifier("permission.resolution")
    }

    private var standardContent: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: statusIcon)
                .font(.caption)
                .foregroundStyle(statusColor)
                .padding(.top, 1)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.medium))
                Text(notice.reason)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .frame(maxWidth: 620, alignment: .leading)
    }

    private var compactRailContent: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: statusIcon)
                .font(.body.weight(.semibold))
                .foregroundStyle(statusColor)
                .accessibilityHidden(true)
            Text(title)
                .font(.body.weight(.semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .help(notice.reason)
        .accessibilityHint(notice.reason)
    }

    private var statusIcon: String {
        notice.decision == .allow
            ? "checkmark.circle.fill"
            : "xmark.circle.fill"
    }

    private var statusColor: Color {
        notice.decision == .allow ? .green : .orange
    }

    private var title: String {
        if notice.decision == .allow {
            return CouncisLocalization.format("%@ approved", notice.tool)
        }
        if notice.action == .cancelTurn {
            return CouncisLocalization.string("Turn cancelled")
        }
        switch notice.failureSource {
        case .userDenied:
            return CouncisLocalization.format("%@ call declined", notice.tool)
        case .userCancelled, .turnCancelled:
            return CouncisLocalization.string("Turn cancelled")
        case .policyDenied:
            return CouncisLocalization.format("%@ call denied by policy", notice.tool)
        case .reviewerTimedOut:
            return CouncisLocalization.string("Automatic review timed out")
        case .reviewerFailed:
            return CouncisLocalization.string("Automatic review failed")
        case .sandboxDenied:
            return CouncisLocalization.format("Sandbox denied %@", notice.tool)
        case .runtimeFailed:
            return CouncisLocalization.format("%@ runtime failed", notice.tool)
        case nil:
            return CouncisLocalization.format("%@ denied", notice.tool)
        }
    }
}

struct PermissionReviewDetail: Equatable, Identifiable {
    let id: String
    let systemImage: String
    let text: String
}

enum PermissionReviewPresentation {
    /// Builds a small, secret-safe review summary from the structured
    /// authorization snapshot. Raw JSON arguments are deliberately excluded.
    static func details(
        for request: PermissionRequestPayload
    ) -> [PermissionReviewDetail] {
        if let preview = request.context?.authorization?.actionPreview {
            let previewDetails: [PermissionReviewDetail] = preview.fields.keys
                .sorted()
                .compactMap { key -> PermissionReviewDetail? in
                guard let value = preview.fields[key], !value.isEmpty else {
                    return nil
                }
                return PermissionReviewDetail(
                    id: "preview.\(key)",
                    systemImage: "info.circle",
                    text: "\(humanized(key)): \(value)")
            }
            if !previewDetails.isEmpty {
                return previewDetails
            }
        }

        let intent = request.context?.intent
            ?? request.context?.authorization?.intent
        var details: [PermissionReviewDetail] = []
        if let action = intent?.action, !action.isEmpty {
            details.append(PermissionReviewDetail(
                id: "action",
                systemImage: "bolt",
                text: action))
        }

        let resources = intent?.resources.map(\.value).filter { !$0.isEmpty }
            ?? []
        if !resources.isEmpty {
            details.append(PermissionReviewDetail(
                id: "resources",
                systemImage: "scope",
                text: resources.joined(separator: ", ")))
        } else if let paths = request.context?.touchedPaths,
                  !paths.isEmpty {
            details.append(PermissionReviewDetail(
                id: "paths",
                systemImage: "folder",
                text: paths.joined(separator: ", ")))
        }
        return details
    }

    static func compactSummary(
        for request: PermissionRequestPayload
    ) -> String {
        let reason = request.reason.trimmingCharacters(
            in: .whitespacesAndNewlines)
        if !reason.isEmpty {
            return reason
        }
        return details(for: request).first?.text ?? request.tool
    }

    private static func humanized(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }
}

public struct PermissionCard: View {
    let permission: PendingPermission
    let onResolve: (PermissionResponseAction) -> Void
    private let embedsSurface: Bool
    private let presentationStyle: PermissionReviewCardStyle
    @State private var showsDetails = false

    public init(permission: PendingPermission,
                embedsSurface: Bool = true,
                presentationStyle: PermissionReviewCardStyle = .standard,
                onResolve: @escaping (PermissionResponseAction) -> Void) {
        self.permission = permission
        self.embedsSurface = embedsSurface
        self.presentationStyle = presentationStyle
        self.onResolve = onResolve
    }

    private var request: PermissionRequestPayload { permission.request }
    private var reviewDetails: [PermissionReviewDetail] {
        PermissionReviewPresentation.details(for: request)
    }
    private var proposedDiff: String? { Self.diff(from: request.args) }
    private var hasDetails: Bool {
        !reviewDetails.isEmpty || proposedDiff != nil
    }

    @ViewBuilder public var body: some View {
        Group {
            switch presentationStyle {
            case .standard:
                standardContent
            case .compactRail:
                compactRailContent
            }
        }
        .modifier(PermissionReviewSurfaceModifier(
            isEnabled: embedsSurface,
            cornerRadius: presentationStyle == .compactRail ? 18 : 14))
        .onChange(of: request.requestId) { _, _ in
            showsDetails = false
        }
    }

    private var standardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock.shield")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(riskColor)
                    .frame(width: 18)
                    .padding(.top, 1)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(CouncisLocalization.string("Permission needed"))
                            .font(.callout.weight(.semibold))
                        Text(riskLabel)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(riskColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(riskColor.opacity(0.10), in: Capsule())
                    }
                    Text(request.tool)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Text(request.reason)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            if hasDetails {
                DisclosureGroup(
                    isExpanded: $showsDetails,
                    content: {
                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(reviewDetails) { detail in
                                Label {
                                    Text(detail.text)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                } icon: {
                                    Image(systemName: detail.systemImage)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            if let proposedDiff {
                                ScrollView {
                                    Text(proposedDiff)
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                        .frame(
                                            maxWidth: .infinity,
                                            alignment: .leading)
                                }
                                .frame(maxHeight: 150)
                                .padding(8)
                                .councisSubtleContentSurface(cornerRadius: 7)
                            }
                        }
                        .padding(.top, 6)
                        .padding(.leading, 4)
                    },
                    label: {
                        Text(CouncisLocalization.string("Details"))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                )
                .tint(.secondary)
                .accessibilityIdentifier("permission.details")
            }

            permissionFooter
        }
        .padding(13)
        .frame(maxWidth: 720, alignment: .leading)
    }

    private var compactRailContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock.shield")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(riskColor)
                    .frame(width: 20)
                    .padding(.top, 1)
                    .accessibilityLabel(
                        CouncisLocalization.format("%@ risk", riskLabel))
                VStack(alignment: .leading, spacing: 3) {
                    Text(CouncisLocalization.string("Permission Review"))
                        .font(.body.weight(.semibold))
                    Text(request.tool)
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(PermissionReviewPresentation.compactSummary(
                        for: request))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            compactRailFooter
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var compactRailFooter: some View {
        if permission.state.isActionable {
            ViewThatFits(in: .horizontal) {
                horizontalPermissionActions
                compactPermissionActions
            }
            .controlSize(.small)
        } else {
            permissionStatus
        }
    }

    private var permissionFooter: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                permissionStatus
                Spacer(minLength: 8)
                if permission.state.isActionable {
                    horizontalPermissionActions
                }
            }
            VStack(alignment: .leading, spacing: 9) {
                permissionStatus
                if permission.state.isActionable {
                    compactPermissionActions
                }
            }
        }
        .controlSize(.small)
    }

    @ViewBuilder private var permissionStatus: some View {
        if permission.state == .resolving {
            HStack(spacing: 7) {
                ProgressView()
                    .controlSize(.small)
                Text(request.effectiveApprovalMode == .automaticReviewer
                     ? CouncisLocalization.string("Automatic review in progress…")
                     : CouncisLocalization.string("Resolving…"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var horizontalPermissionActions: some View {
        HStack(spacing: 8) {
            cancelTurnButton
            declineCallButton
            approveCallButton
            if permitsRememberedApproval {
                rememberApprovalButton
            }
        }
    }

    private var compactPermissionActions: some View {
        VStack(alignment: .trailing, spacing: 7) {
            approveCallButton
                .frame(maxWidth: .infinity, alignment: .trailing)
            if permitsRememberedApproval {
                rememberApprovalButton
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            HStack(spacing: 8) {
                cancelTurnButton
                Spacer(minLength: 8)
                declineCallButton
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var cancelTurnButton: some View {
        Button("Cancel Turn") { onResolve(.cancelTurn) }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("permission.cancel-turn")
    }

    private var declineCallButton: some View {
        Button("Decline Call") { onResolve(.decline) }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("permission.decline-call")
    }

    private var approveCallButton: some View {
        Button(
            request.context?.authorization?.mcp == nil
                ? "Approve Call"
                : "Allow Call Once"
        ) {
            onResolve(.approve)
        }
        .councisGlassButton(prominent: true)
        .keyboardShortcut(.defaultAction)
        .accessibilityIdentifier("permission.approve-call")
    }

    private var rememberApprovalButton: some View {
        Button("Remember Exact Tool Approval") {
            onResolve(.approveAndRemember)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("permission.approve-and-remember")
    }

    private var permitsRememberedApproval: Bool {
        request.context?.authorization?.permitsMCPRememberedApproval == true
    }

    private var riskColor: Color {
        switch request.risk {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    private var riskLabel: String {
        switch request.risk {
        case .low: return CouncisLocalization.string("LOW")
        case .medium: return CouncisLocalization.string("MEDIUM")
        case .high: return CouncisLocalization.string("HIGH")
        }
    }

    private var statusText: String {
        switch permission.state {
        case .livePending:
            return CouncisLocalization.string("Waiting for your decision.")
        case .resolving:
            return request.effectiveApprovalMode == .automaticReviewer
                ? CouncisLocalization.string(
                    "The reserved permission reviewer is evaluating this call.")
                : CouncisLocalization.string("Applying your decision.")
        case .approved:
            return CouncisLocalization.string("Approved.")
        case .rejected:
            return CouncisLocalization.string("Rejected.")
        case .expired:
            return CouncisLocalization.string(
                "This approval channel expired. Rerun the task to continue.")
        case .needsRerun:
            return CouncisLocalization.string(
                "This request was restored from history. Rerun the task to continue.")
        }
    }

    public static func diff(from args: String) -> String? {
        struct A: Decodable { let diff: String? }
        return (try? JSONDecoder().decode(A.self, from: Data(args.utf8)))?.diff
    }
}

private struct CodeInspectorView: View {
    let workspaceName: String
    let agentState: String
    let itemCount: Int
    let pending: PendingPermission?
    let errors: [CouncisThreadErrorEntry]
    let style: CouncisThreadStyle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                inspectorHeader
                inspectorSection(CouncisLocalization.string("Plan")) {
                    inspectorRow(
                        CouncisLocalization.string("Current task"),
                        value: councisLocalizedAgentState(agentState))
                    inspectorRow(CouncisLocalization.string("Thread events"), value: "\(itemCount)")
                    if let pending {
                        inspectorRow(
                            CouncisLocalization.string("Permission"),
                            value: pending.request.tool)
                    } else {
                        inspectorRow(
                            CouncisLocalization.string("Permission"),
                            value: CouncisLocalization.string("none pending"))
                    }
                }
                inspectorSection(CouncisLocalization.string("Workspace")) {
                    inspectorRow(CouncisLocalization.string("Root"), value: workspaceName)
                    inspectorRow(
                        CouncisLocalization.string("Git"),
                        value: CouncisLocalization.string("status only"))
                    Text("Commit, branch, PR, CI, and review workflows are deferred.")
                        .font(.caption2)
                        .foregroundStyle(style.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !errors.isEmpty {
                    inspectorSection(CouncisLocalization.string("Error Information")) {
                        CouncisThreadErrorList(
                            errors: errors,
                            style: style,
                            onRetrySubmission: nil)
                    }
                    .accessibilityIdentifier("code.error.card")
                }
            }
            .padding(16)
        }
    }

    private var inspectorHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Inspector")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(style.primaryText)
            Text("Task and workspace status")
                .font(.caption)
                .foregroundStyle(style.secondaryText)
        }
    }

    private func inspectorSection<Content: View>(_ title: String,
                                                 @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.bold())
                .foregroundStyle(style.tertiaryText)
            content()
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .councisContentSurface(cornerRadius: 8)
    }

    private func inspectorRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(style.secondaryText)
            Spacer(minLength: 8)
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(style.primaryText)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
#endif
