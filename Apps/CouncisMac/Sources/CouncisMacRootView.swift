//
//  CouncisMacRootView.swift
//  CouncisMac
//
//  macOS workbench shell: mode + session history live in the sidebar, the center
//  stays focused on the thread, and Code/Cowork reserve the right side for status.
//

#if canImport(SwiftUI)
import SwiftUI
import CouncisCore
import CouncisConversation
import CouncisSharedUI

enum CouncisNavItem: String, CaseIterable, Identifiable, Hashable {
    case chat, code, cowork

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chat: return CouncisLocalization.string("Chat")
        case .code: return CouncisLocalization.string("Code")
        case .cowork: return CouncisLocalization.string("Cowork")
        }
    }

    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .cowork: return "person.2"
        }
    }

    var sessionKind: SessionKind {
        switch self {
        case .chat: return .chat
        case .code: return .code
        case .cowork: return .cowork
        }
    }

    var newSessionTitle: String {
        switch self {
        case .chat: return CouncisLocalization.string("New chat")
        case .code: return CouncisLocalization.string("New code session")
        case .cowork: return CouncisLocalization.string("New cowork session")
        }
    }

    var emptyHistoryTitle: String {
        switch self {
        case .chat: return CouncisLocalization.string("No chat sessions yet.")
        case .code: return CouncisLocalization.string("No code sessions yet.")
        case .cowork: return CouncisLocalization.string("No cowork sessions yet.")
        }
    }
}

private struct SessionActionTarget: Identifiable {
    let sessionID: SessionID
    let kind: SessionKind
    let title: String

    var id: String { "\(kind.rawValue):\(sessionID.rawValue)" }
}

struct CouncisMacRootView: View {
    @EnvironmentObject var env: AppEnvironment
    @ObservedObject private var runtimeManager: AppSessionRuntimeManager
    @Environment(\.colorScheme) private var scheme
    @State private var selection: CouncisNavItem = .cowork
    @State private var isSettings = false
    @State private var didInit = false
    @State private var recentChatSessions: [AppSessionSummary] = []
    @State private var recentCodeSessions: [AppSessionSummary] = []
    @State private var recentCoworkSessions: [AppSessionSummary] = []
    @State private var codeVM: CodeViewModel?
    @State private var coworkVM: CoworkViewModel?
    @State private var showsCodeInspector = true
    @State private var showsCoworkInspector = true
    @State private var coworkTransitionID: UUID?
    @State private var codeSessionError: String?
    @State private var coworkSessionError: String?
    @State private var renameTarget: SessionActionTarget?
    @State private var deleteTarget: SessionActionTarget?
    @State private var sessionActionError: String?
    @State private var runtimeStatuses: [
        AppSessionRuntimeKey: AppSessionRuntimePresentationStatus
    ]

    init(runtimeManager: AppSessionRuntimeManager) {
        _runtimeManager = ObservedObject(wrappedValue: runtimeManager)
        _runtimeStatuses = State(initialValue: runtimeManager.runtimeStatusSnapshot())
    }

    private var items: [CouncisNavItem] {
        PlatformProfile.current.supports(.cowork) ? [.cowork] : []
    }

    var body: some View {
        NavigationSplitView {
            CouncisSidebar(
                items: items,
                selection: $selection,
                isSettings: $isSettings,
                historyItems: historyItems,
                historyTitle: CouncisLocalization.string("Recent"),
                emptyHistoryTitle: selection.emptyHistoryTitle,
                newSessionTitle: selection.newSessionTitle,
                isNewDisabled: newSessionDisabled,
                newActions: selection == .cowork
                    ? coworkNewActions
                    : [],
                onNewSession: startNewSelectedSession,
                onSelectSession: resumeSelectedSession,
                onRenameSession: beginRenameSession,
                onDeleteSession: beginDeleteSession)
                .navigationSplitViewColumnWidth(
                    min: CouncisSplitColumnLayout.chatInspector.sidebarMin,
                    ideal: 236)
        } detail: {
            ZStack {
                CouncisSystemCanvas().ignoresSafeArea()
                detail
            }
        }
        .navigationTitle("")
        .mcpInteractionHost(env.mcp.interactionCenter)
        .task {
            guard !didInit else { return }
            didInit = true
            refreshAllSessions()
            if env.needsAPIKey { isSettings = true }
        }
        .onChange(of: selection) { _ in refreshAllSessions() }
        .onChange(of: env.chatSessionID.rawValue) { _ in refreshChatSessions() }
        .onReceive(runtimeManager.runtimeRemoved) { key in
            handleRemovedRuntime(key)
        }
        .onReceive(runtimeManager.sessionDisplayNameChanged) { change in
            handleSessionDisplayNameChange(change)
        }
        .onReceive(runtimeManager.sessionActivitySettled) { settlement in
            refreshSessions(kind: settlement.key.kind)
        }
        .onReceive(runtimeManager.sessionRuntimeStatusChanged) { change in
            if let status = change.status {
                runtimeStatuses[change.key] = status
            } else {
                runtimeStatuses.removeValue(forKey: change.key)
            }
        }
        .sheet(item: $renameTarget) { target in
            SessionRenameSheet(initialName: target.title) { newName in
                try await renameSession(target, to: newName)
            }
        }
        .alert("Delete Session?", isPresented: deleteAlertPresented, presenting: deleteTarget) { target in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteSession(target)
            }
        } message: { target in
            Text(CouncisLocalization.format(
                "\"%@\" and its Councis event history and artifacts will be permanently deleted. Files in the linked workspace will not be changed.",
                target.title))
        }
        .alert("Session Action Failed", isPresented: sessionErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(sessionActionError ?? CouncisLocalization.string("The session action failed."))
        }
    }

    @ViewBuilder private var detail: some View {
        if isSettings {
            CouncisSettingsPanel()
        } else {
            switch selection {
            case .chat:
                CouncisChatScreen(
                    env: env,
                    sessionTitle: sessionTitle(
                        kind: .chat,
                        sessionID: env.chatSessionID))
            case .code:
                codeDetail
            case .cowork:
                coworkDetail
            }
        }
    }

    @ViewBuilder private var codeDetail: some View {
        if let vm = codeVM {
            let presentationScope = CouncisThreadPresentationScope(
                kind: .code,
                sessionID: vm.sessionID)
            CodeSessionView(
                vm: vm,
                sessionTitle: sessionTitle(kind: .code, sessionID: vm.sessionID),
                catalog: env.providerCatalog,
                mcpProjectSettingsHost:
                    env.mcpProjectSettingsHost(for: vm),
                mcpContentHost:
                    env.mcpConversationContentHost(
                        for: vm),
                onSelectModel: env.selectProviderModel(providerID:modelID:variantID:),
                onShowSessions: showCodeSessions,
                onNewSession: startNewCodeSession,
                showsInspector: $showsCodeInspector)
                .id(presentationScope)
        } else {
            WorkspaceSessionHome(
                title: CouncisLocalization.string("Code"),
                subtitle: CouncisLocalization.string("Local workspace agent session"),
                icon: "folder.badge.plus",
                primaryTitle: CouncisLocalization.string("Choose Workspace"),
                primarySystemImage: "folder",
                primaryShortcut: "o",
                error: codeSessionError,
                sessionsTitle: CouncisLocalization.string("Recent Code Sessions"),
                sessions: [],
                workspacePath: { WorkspaceAccess.workspacePath(for: $0) },
                onPrimary: startNewCodeSession,
                onResume: { resumeCodeSession($0.id) })
        }
    }

    @ViewBuilder private var coworkDetail: some View {
        if let vm = coworkVM {
            let presentationScope = CouncisThreadPresentationScope(
                kind: .cowork,
                sessionID: vm.sessionID)
            CoworkSessionView(
                vm: vm,
                sessionTitle: sessionTitle(kind: .cowork, sessionID: vm.sessionID),
                catalog: env.providerCatalog,
                mcpProjectSettingsHost:
                    env.mcpProjectSettingsHost(for: vm),
                mcpContentHost:
                    env.mcpConversationContentHost(
                        for: vm),
                onShowSessions: showCoworkSessions,
                onNewSession: startNewCoworkSession,
                onSessionDidBecomeReady: refreshCoworkSessions,
                showsInspector: $showsCoworkInspector)
                .id(presentationScope)
        } else {
            WorkspaceSessionHome(
                title: CouncisLocalization.string("Cowork"),
                subtitle: CouncisLocalization.string("Multi-agent workspace session"),
                icon: "person.2",
                primaryTitle: CouncisLocalization.string("New Cowork Session"),
                primarySystemImage: "plus",
                primaryShortcut: "n",
                primaryActions: coworkNewActions,
                error: coworkSessionError,
                sessionsTitle: CouncisLocalization.string("Recent Cowork Sessions"),
                sessions: [],
                workspacePath: { _ in String?.none },
                onPrimary: startNewCoworkSession,
                onResume: { resumeCoworkSession($0.id) })
        }
    }

    private var historyItems: [CouncisSessionHistoryItem] {
        switch selection {
        case .chat:
            return recentChatSessions.map {
                historyItem($0, icon: selection.icon, selected: $0.id == env.chatSessionID)
            }
        case .code:
            return recentCodeSessions.map {
                historyItem($0, icon: selection.icon, selected: $0.id == codeVM?.sessionID)
            }
        case .cowork:
            return recentCoworkSessions.map {
                historyItem($0, icon: selection.icon, selected: $0.id == coworkVM?.sessionID)
            }
        }
    }

    private var newSessionDisabled: Bool {
        guard env.runtimeManager.acceptsNewRuntimes else { return true }
        switch selection {
        case .chat, .code:
            return false
        case .cowork:
            return coworkTransitionID != nil
        }
    }

    private var coworkNewActions: [CouncisSessionNewAction] {
        [
            CouncisSessionNewAction(
                title: CouncisLocalization.string("Choose Folder…"),
                systemImage: "folder",
                action: startNewCoworkSessionChoosingFolder),
            CouncisSessionNewAction(
                title: CouncisLocalization.string("No Folder"),
                systemImage: "square.dashed",
                action: startNewCoworkSession),
        ]
    }

    private func historyItem(_ session: AppSessionSummary,
                             icon: String,
                             selected: Bool) -> CouncisSessionHistoryItem {
        CouncisSessionHistoryItem(
            id: session.id,
            title: session.displayName ?? session.id.rawValue,
            detail: "",
            systemImage: icon,
            isSelected: selected,
            isDeleteDisabled: isDeleteDisabled(session))
    }

    private func isDeleteDisabled(_ session: AppSessionSummary) -> Bool {
        guard runtimeManager.state == .running else { return true }
        let key = AppSessionRuntimeKey(kind: session.kind, sessionID: session.id)
        return runtimeStatuses[key]?.blocksDeletion == true
            || runtimeManager.isBusy(kind: session.kind, sessionID: session.id)
    }

    private func refreshAllSessions() {
        refreshChatSessions()
        refreshCodeSessions()
        refreshCoworkSessions()
    }

    private func refreshChatSessions() {
        recentChatSessions = env.recentChatSessions()
    }

    private func refreshCodeSessions() {
        recentCodeSessions = env.recentCodeSessions()
    }

    private func refreshCoworkSessions() {
        recentCoworkSessions = env.recentCoworkSessions()
    }

    private func refreshSessions(kind: SessionKind) {
        switch kind {
        case .chat:
            refreshChatSessions()
        case .code:
            refreshCodeSessions()
        case .cowork:
            refreshCoworkSessions()
        }
    }

    private func handleRemovedRuntime(_ key: AppSessionRuntimeKey) {
        switch key.kind {
        case .chat:
            env.handleRemovedChatRuntime(sessionID: key.sessionID)
        case .code:
            if codeVM?.sessionID == key.sessionID {
                codeVM = nil
            }
        case .cowork:
            if coworkVM?.sessionID == key.sessionID {
                coworkVM = nil
            }
        }
        refreshAllSessions()
    }

    private func handleSessionDisplayNameChange(_ change: AppSessionDisplayNameChange) {
        switch change.key.kind {
        case .chat:
            guard let updated = replacingDisplayName(
                in: recentChatSessions,
                with: change) else {
                refreshChatSessions()
                return
            }
            recentChatSessions = updated
        case .code:
            guard let updated = replacingDisplayName(
                in: recentCodeSessions,
                with: change) else {
                refreshCodeSessions()
                return
            }
            recentCodeSessions = updated
        case .cowork:
            guard let updated = replacingDisplayName(
                in: recentCoworkSessions,
                with: change) else {
                refreshCoworkSessions()
                return
            }
            recentCoworkSessions = updated
        }
    }

    private func replacingDisplayName(
        in sessions: [AppSessionSummary],
        with change: AppSessionDisplayNameChange
    ) -> [AppSessionSummary]? {
        guard let index = sessions.firstIndex(where: {
            $0.id == change.key.sessionID &&
                $0.kind.rawValue == change.key.kind.rawValue
        }) else {
            return nil
        }
        var updated = sessions
        let current = updated[index]
        updated[index] = AppSessionSummary(
            id: current.id,
            kind: current.kind,
            updatedAt: current.updatedAt,
            eventCount: current.eventCount,
            displayName: change.displayName)
        return updated
    }

    private func startNewSelectedSession() {
        isSettings = false
        switch selection {
        case .chat:
            env.startNewChatSession()
            refreshChatSessions()
        case .code:
            startNewCodeSession()
        case .cowork:
            startNewCoworkSession()
        }
    }

    private func resumeSelectedSession(_ sessionID: SessionID) {
        isSettings = false
        switch selection {
        case .chat:
            guard let session = recentChatSessions.first(where: { $0.id == sessionID }) else { return }
            env.resumeChatSession(session)
            refreshChatSessions()
        case .code:
            resumeCodeSession(sessionID)
        case .cowork:
            resumeCoworkSession(sessionID)
        }
    }

    private var deleteAlertPresented: Binding<Bool> {
        Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } })
    }

    private var sessionErrorPresented: Binding<Bool> {
        Binding(
            get: { sessionActionError != nil },
            set: { if !$0 { sessionActionError = nil } })
    }

    private func beginRenameSession(_ sessionID: SessionID) {
        guard let session = sessions(for: selection.sessionKind)
            .first(where: { $0.id == sessionID }) else { return }
        renameTarget = SessionActionTarget(
            sessionID: session.id,
            kind: session.kind,
            title: session.displayName ?? session.id.rawValue)
    }

    private func beginDeleteSession(_ sessionID: SessionID) {
        guard let session = sessions(for: selection.sessionKind)
            .first(where: { $0.id == sessionID }) else { return }
        deleteTarget = SessionActionTarget(
            sessionID: session.id,
            kind: session.kind,
            title: session.displayName ?? session.id.rawValue)
    }

    private func sessions(for kind: SessionKind) -> [AppSessionSummary] {
        switch kind {
        case .chat: return recentChatSessions
        case .code: return recentCodeSessions
        case .cowork: return recentCoworkSessions
        }
    }

    private func sessionTitle(kind: SessionKind, sessionID: SessionID) -> String {
        sessions(for: kind)
            .first(where: { $0.id == sessionID })
            .flatMap(\.displayName)
            ?? sessionID.rawValue
    }

    private func renameSession(_ target: SessionActionTarget, to newName: String) async throws {
        let log = try EventLog(
            session: target.sessionID,
            fileURL: AppConfig.sessionFile(target.sessionID))
        let update = try await SessionProjectionStore.renameDisplayName(
            in: log,
            kind: target.kind,
            displayName: newName,
            source: .userInterface)
        let projection = update.projection
        guard projection.sessionID == target.sessionID,
              projection.kind.rawValue == target.kind.rawValue,
              let displayName = projection.displayName,
              let settingsRevision = projection.settingsRevision else {
            throw SessionProjectionStoreError.verificationFailed
        }
        runtimeManager.publishSessionDisplayNameChange(AppSessionDisplayNameChange(
            key: AppSessionRuntimeKey(
                kind: projection.kind,
                sessionID: projection.sessionID),
            displayName: displayName,
            settingsRevision: settingsRevision,
            projectedThroughSeq: projection.projectedThroughSeq))
    }

    private func deleteSession(_ target: SessionActionTarget) {
        Task { @MainActor in
            do {
                switch target.kind {
                case .chat:
                    try await env.deleteChatSession(target.sessionID)
                case .code:
                    try await env.runtimeManager.removeSession(
                        kind: .code,
                        sessionID: target.sessionID,
                        reason: "Code session deleted by user"
                    ) {
                        try SessionHistoryStore.deleteSession(
                            root: AppConfig.appSupportDir(),
                            session: target.sessionID)
                        WorkspaceAccess.forget(session: target.sessionID)
                    }
                case .cowork:
                    try await env.runtimeManager.removeSession(
                        kind: .cowork,
                        sessionID: target.sessionID,
                        reason: "Cowork session deleted by user"
                    ) {
                        try SessionHistoryStore.deleteSession(
                            root: AppConfig.appSupportDir(),
                            session: target.sessionID)
                        CoworkProjectSettingsStore.remove(sessionID: target.sessionID)
                        WorkspaceAccess.forget(session: target.sessionID)
                    }
                }
                refreshAllSessions()
            } catch {
                sessionActionError = error.localizedDescription
            }
        }
    }

    private func startNewCodeSession() {
        guard let authorization = WorkspaceAccess.choose() else { return }
        selection = .code
        isSettings = false
        do {
            codeVM = try env.makeCodeViewModel(workspace: authorization)
            codeSessionError = nil
            refreshCodeSessions()
        } catch {
            codeSessionError = CouncisLocalization.format(
                "Could not start Code session: %@",
                error.localizedDescription)
        }
    }

    private func showCodeSessions() {
        codeVM = nil
        refreshCodeSessions()
    }

    private func resumeCodeSession(_ sessionID: SessionID) {
        let workspace: WorkspaceAccessLease
        do {
            if let restored = try WorkspaceAccess.restoredWorkspace(for: sessionID) {
                workspace = restored
            } else {
                guard let expectedPath = try WorkspaceAccess.workspacePathChecked(for: sessionID),
                      let selected = WorkspaceAccess.choose(
                        prompt: CouncisLocalization.string("Reauthorize Code Workspace")) else {
                    codeSessionError = CouncisLocalization.string(
                        "The original Code workspace identity is unavailable; this session was not rebound.")
                    return
                }
                let expected = URL(fileURLWithPath: expectedPath)
                    .standardizedFileURL
                    .resolvingSymlinksInPath()
                guard selected.canonicalURL == expected else {
                    selected.release()
                    codeSessionError = CouncisLocalization.format(
                        "Choose the original Code workspace at %@.",
                        expectedPath)
                    return
                }
                workspace = selected
            }
        } catch {
            codeSessionError = CouncisLocalization.format(
                "Code workspace access could not be read safely: %@",
                error.localizedDescription)
            return
        }
        selection = .code
        isSettings = false
        do {
            let runtime =
                try env.makeCodeViewModel(
                    session: sessionID,
                    workspace: workspace)
            codeVM = runtime
            Task { @MainActor [weak runtime] in
                await runtime?
                    .flushProjectionForPresentation()
            }
            codeSessionError = nil
            refreshCodeSessions()
        } catch {
            codeSessionError = CouncisLocalization.format(
                "Could not resume Code session: %@",
                error.localizedDescription)
        }
    }

    private func startNewCoworkSession() {
        startNewCoworkSession(primaryWorkspace: nil)
    }

    private func startNewCoworkSessionChoosingFolder() {
        guard let workspace = WorkspaceAccess.choose(
            prompt: CouncisLocalization.string(
                "Choose Cowork Workspace")) else {
            return
        }
        startNewCoworkSession(primaryWorkspace: workspace)
    }

    private func startNewCoworkSession(
        primaryWorkspace: WorkspaceAccessLease?
    ) {
        selection = .cowork
        isSettings = false
        let transitionID = UUID()
        coworkTransitionID = transitionID
        Task { @MainActor in
            guard coworkTransitionID == transitionID else {
                primaryWorkspace?.release()
                return
            }
            do {
                let runtime: CoworkViewModel
                if let primaryWorkspace {
                    runtime = try await env.makeCoworkViewModel(
                        primaryWorkspace: primaryWorkspace)
                } else {
                    runtime = try await env.makeCoworkViewModel()
                }
                guard coworkTransitionID == transitionID else { return }
                coworkVM = runtime
                coworkSessionError = nil
                refreshCoworkSessions()
            } catch {
                coworkSessionError = CouncisLocalization.format(
                    "Could not start Cowork session: %@",
                    error.localizedDescription)
            }
            if coworkTransitionID == transitionID {
                coworkTransitionID = nil
            }
        }
    }

    private func showCoworkSessions() {
        coworkTransitionID = nil
        coworkVM = nil
        refreshCoworkSessions()
    }

    private func resumeCoworkSession(_ sessionID: SessionID) {
        selection = .cowork
        isSettings = false
        let transitionID = UUID()
        coworkTransitionID = transitionID
        Task { @MainActor in
            guard coworkTransitionID == transitionID else { return }
            do {
                let runtime = try await env.makeCoworkViewModel(session: sessionID)
                guard coworkTransitionID == transitionID else { return }
                await runtime.flushProjectionForPresentation()
                guard coworkTransitionID == transitionID else { return }
                coworkVM = runtime
                coworkSessionError = nil
                refreshCoworkSessions()
            } catch {
                coworkSessionError = CouncisLocalization.format(
                    "Could not resume Cowork session: %@",
                    error.localizedDescription)
            }
            if coworkTransitionID == transitionID {
                coworkTransitionID = nil
            }
        }
    }
}

private struct SessionRenameSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var errorText: String?
    @State private var isRenaming = false
    private let onRename: (String) async throws -> Void

    init(initialName: String,
         onRename: @escaping (String) async throws -> Void) {
        _name = State(initialValue: initialName)
        self.onRename = onRename
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canRename: Bool {
        !trimmedName.isEmpty && trimmedName.count <= 120
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename Session")
                .font(.councisHeadline)
            TextField("Session name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(rename)

            if let errorText {
                Text(errorText)
                    .font(.councisCaption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Cancel", action: dismiss.callAsFunction)
                Button("Rename", action: rename)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canRename || isRenaming)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func rename() {
        guard canRename else { return }
        isRenaming = true
        Task { @MainActor in
            do {
                try await onRename(trimmedName)
                dismiss()
            } catch {
                errorText = error.localizedDescription
                isRenaming = false
            }
        }
    }
}

// MARK: - Sidebar

struct CouncisSidebar: View {
    let items: [CouncisNavItem]
    @Binding var selection: CouncisNavItem
    @Binding var isSettings: Bool
    let historyItems: [CouncisSessionHistoryItem]
    let historyTitle: String
    let emptyHistoryTitle: String
    let newSessionTitle: String
    let isNewDisabled: Bool
    let newActions: [CouncisSessionNewAction]
    let onNewSession: () -> Void
    let onSelectSession: (SessionID) -> Void
    let onRenameSession: (SessionID) -> Void
    let onDeleteSession: (SessionID) -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleBlock
                .padding(.horizontal, 18)
                .padding(.top, 22)
                .padding(.bottom, 12)

            CouncisSessionHistoryList(
                title: historyTitle,
                newTitle: newSessionTitle,
                emptyTitle: emptyHistoryTitle,
                items: historyItems,
                style: .councisMac(scheme),
                isNewDisabled: isNewDisabled,
                newActions: newActions,
                onNew: onNewSession,
                onSelect: onSelectSession,
                onRename: onRenameSession,
                onDelete: onDeleteSession)
            .padding(.horizontal, 12)
            .frame(maxHeight: .infinity, alignment: .top)

            Button { isSettings = true } label: {
                CouncisSidebarSettingsRow(selected: isSettings)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 14)
            .accessibilityIdentifier("sidebar.settings")
        }
    }

    private var titleBlock: some View {
        Text("Councis")
            .font(CouncisType.brand(28))
            .foregroundStyle(CouncisTheme.deepText(scheme))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var modeNavigation: some View {
        VStack(spacing: 4) {
            ForEach(items) { item in
                let isSelected = selection == item && !isSettings
                Button {
                    selection = item
                    isSettings = false
                } label: {
                    CouncisSidebarModeRow(
                        title: item.title,
                        systemImage: item.icon,
                        selected: isSelected)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("sidebar.mode.\(item.rawValue)")
            }
        }
    }
}

private struct CouncisSidebarModeRow: View {
    let title: String
    let systemImage: String
    let selected: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if selected {
                content
                    .councisLiquidGlass(cornerRadius: 10, interactive: true)
            } else {
                content
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var content: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.councisFixed(size: 14, weight: .semibold))
                .foregroundStyle(selected
                    ? CouncisTheme.accent(scheme)
                    : CouncisTheme.softText(scheme))
                .frame(width: 22)
            Text(title)
                .font(CouncisType.body(14, selected ? .semibold : .medium))
                .foregroundStyle(selected
                    ? CouncisTheme.deepText(scheme)
                    : CouncisTheme.softText(scheme))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

private struct CouncisSidebarSettingsRow: View {
    let selected: Bool
    @Environment(\.colorScheme) private var scheme
    @State private var hover = false

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "gearshape")
                .font(.councisFixed(size: 13, weight: .medium))
                .foregroundStyle(selected ? CouncisTheme.accent(scheme) : CouncisTheme.softText(scheme))
                .frame(width: 20)
            Text(CouncisLocalization.string("Settings"))
                .font(CouncisType.body(13, selected ? .semibold : .medium))
                .foregroundStyle(selected ? CouncisTheme.deepText(scheme) : CouncisTheme.softText(scheme))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(selected ? CouncisTheme.selectedStroke(scheme) : CouncisTheme.separator(scheme),
                        lineWidth: 1)
                .opacity(selected ? 1 : (hover ? 0.4 : 0))
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { hover = $0 }
    }
}
#endif
