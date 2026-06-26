#if canImport(SwiftUI)
import SwiftUI

struct CouncisRootView: View {
    @Environment(\.colorScheme) private var scheme
    @SceneStorage("councis.selectedSection") private var selectedSectionRaw = CouncisSection.chat.rawValue
    @State private var chatRun: CouncilRunViewState
    @State private var workRun: CouncilRunViewState

    init() {
        _chatRun = State(initialValue: CouncilMockState.chatRun)
        _workRun = State(initialValue: CouncilMockState.workRun(
            workspacePath: FileManager.default.currentDirectoryPath
        ))
    }

    private var selectedSection: CouncisSection {
        CouncisSection(rawValue: selectedSectionRaw) ?? .chat
    }

    private var selectedSectionBinding: Binding<CouncisSection> {
        Binding(
            get: { selectedSection },
            set: { selectedSectionRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationSplitView {
            CouncisSidebar(selection: selectedSectionBinding)
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 260)
        } detail: {
            ZStack {
                CouncisTheme.pageBackground(scheme).ignoresSafeArea()
                detail
            }
        }
        .navigationTitle("")
        .frame(minWidth: 1040, minHeight: 680)
    }

    @ViewBuilder private var detail: some View {
        switch selectedSection {
        case .chat:
            CouncilRunWorkspace(run: $chatRun, placeholder: "Ask")
        case .work:
            CouncilRunWorkspace(run: $workRun, placeholder: "Ask with workspace")
        case .runs:
            CouncisPlaceholderView(title: "Runs", message: "No run selected.")
        case .presets:
            CouncisPlaceholderView(title: "Presets", message: "Elite Chat\nElite Work")
        }
    }
}

private struct CouncisPlaceholderView: View {
    let title: String
    let message: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CouncisPageHeader(title: title, subtitle: nil)

            Text(message)
                .font(CouncisType.body(14))
                .foregroundStyle(CouncisTheme.secondaryText(scheme))
                .textSelection(.enabled)
                .padding(18)
                .frame(maxWidth: 560, alignment: .leading)
                .councisGlassCard(cornerRadius: 18)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 30)
        .padding(.top, 26)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
#endif
