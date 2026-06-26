#if canImport(SwiftUI)
import SwiftUI

struct CouncilRunWorkspace: View {
    @Binding var run: CouncilRunViewState
    let placeholder: String

    var body: some View {
        HStack(spacing: 0) {
            CouncilRunMain(run: $run, placeholder: placeholder)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().opacity(0.45)

            CouncilRunInspector(run: run)
                .frame(width: 320)
        }
    }
}

private struct CouncilRunMain: View {
    @Binding var run: CouncilRunViewState
    let placeholder: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            CouncisPageHeader(title: run.mode.title, subtitle: subtitle)
                .padding(.horizontal, 30)
                .padding(.top, 26)
                .padding(.bottom, 12)

            HStack(spacing: 8) {
                StatusChip(text: run.candidateSummary)
                StatusChip(text: "judge \(run.judge.status)")
                if run.isMock {
                    StatusChip(text: "mock")
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    PromptCard(prompt: run.prompt)

                    if run.mode == .work {
                        WorkContextCard(run: run)
                    }

                    FinalAnswerCard(answer: run.finalAnswer)
                }
                .frame(maxWidth: 860, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 30)
                .padding(.vertical, 16)
            }
            .scrollContentBackground(.hidden)

            CouncilComposer(placeholder: placeholder) { text in
                run = CouncilMockState.updatedRun(from: run, prompt: text)
            }
            .frame(maxWidth: 860)
            .padding(.horizontal, 30)
            .padding(.top, 10)
            .padding(.bottom, 22)
        }
        .foregroundStyle(CouncisTheme.primaryText(scheme))
    }

    private var subtitle: String {
        "Engine: Council | Preset: \(run.mode.presetTitle) | Judge: \(run.judge.model)"
    }
}

struct CouncisPageHeader: View {
    let title: String
    let subtitle: String?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(CouncisType.brand(30))
                .foregroundStyle(CouncisTheme.primaryText(scheme))
            if let subtitle {
                Text(subtitle)
                    .font(CouncisType.caption(12, .medium))
                    .foregroundStyle(CouncisTheme.secondaryText(scheme))
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StatusChip: View {
    let text: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Text(text)
            .font(CouncisType.mono(11, .medium))
            .foregroundStyle(CouncisTheme.accentDeep)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                Capsule(style: .continuous)
                    .fill(CouncisTheme.accentPale.opacity(scheme == .dark ? 0.14 : 0.78))
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(CouncisTheme.accentBlue.opacity(scheme == .dark ? 0.28 : 0.26), lineWidth: 1)
            }
    }
}

private struct PromptCard: View {
    let prompt: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prompt")
                .font(CouncisType.caption(11, .semibold))
                .foregroundStyle(CouncisTheme.secondaryText(scheme))
            Text(prompt)
                .font(CouncisType.chat(15))
                .foregroundStyle(CouncisTheme.primaryText(scheme))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .councisGlassCard(cornerRadius: 18)
    }
}

private struct FinalAnswerCard: View {
    let answer: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Final answer")
                    .font(CouncisType.section(17))
                    .foregroundStyle(CouncisTheme.primaryText(scheme))
                Spacer(minLength: 0)
                Text("judge synthesis")
                    .font(CouncisType.mono(11, .medium))
                    .foregroundStyle(CouncisTheme.secondaryText(scheme))
            }

            Text(answer)
                .font(CouncisType.chat(15))
                .foregroundStyle(CouncisTheme.primaryText(scheme))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .councisGlassCard(cornerRadius: 20, fillOpacity: 0.64, strokeOpacity: 0.54)
    }
}

private struct WorkContextCard: View {
    let run: CouncilRunViewState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Workspace context")
                .font(CouncisType.caption(11, .semibold))
                .foregroundStyle(CouncisTheme.secondaryText(scheme))

            if let workspacePath = run.workspacePath {
                Text(workspacePath)
                    .font(CouncisType.mono(12))
                    .foregroundStyle(CouncisTheme.primaryText(scheme))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            VStack(alignment: .leading, spacing: 5) {
                ForEach(run.files.prefix(4), id: \.self) { file in
                    Text(file)
                        .font(CouncisType.mono(12))
                        .foregroundStyle(CouncisTheme.secondaryText(scheme))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .councisGlassCard(cornerRadius: 18, fillOpacity: 0.48, shadowOpacity: 0.04)
    }
}
#endif
