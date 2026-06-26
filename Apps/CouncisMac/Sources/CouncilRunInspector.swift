#if canImport(SwiftUI)
import SwiftUI

struct CouncilRunInspector: View {
    let run: CouncilRunViewState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                InspectorSection(title: "Candidates") {
                    VStack(spacing: 8) {
                        ForEach(run.candidates) { candidate in
                            CandidateRow(candidate: candidate)
                        }
                    }
                }

                InspectorSection(title: "Judge") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(run.judge.model)
                            .font(CouncisType.mono(12, .semibold))
                            .foregroundStyle(CouncisTheme.primaryText(scheme))
                            .textSelection(.enabled)

                        if let base = run.judge.base {
                            InspectorKeyValue(label: "base", value: base)
                        }
                        if !run.judge.patched.isEmpty {
                            InspectorKeyValue(label: "patched", value: run.judge.patched.joined(separator: ", "))
                        }
                    }
                }

                InspectorSection(title: "Audit") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(run.auditEvents, id: \.self) { event in
                            AuditRow(text: event)
                        }
                    }
                }

                if run.mode == .work {
                    InspectorSection(title: "Files") {
                        VStack(alignment: .leading, spacing: 9) {
                            if let workspacePath = run.workspacePath {
                                Text("Workspace")
                                    .font(CouncisType.caption(11, .semibold))
                                    .foregroundStyle(CouncisTheme.secondaryText(scheme))
                                Text(workspacePath)
                                    .font(CouncisType.mono(11))
                                    .foregroundStyle(CouncisTheme.primaryText(scheme))
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                                    .textSelection(.enabled)
                            }

                            Text("Context")
                                .font(CouncisType.caption(11, .semibold))
                                .foregroundStyle(CouncisTheme.secondaryText(scheme))
                                .padding(.top, 2)
                            ForEach(run.files, id: \.self) { file in
                                Text(file)
                                    .font(CouncisType.mono(11))
                                    .foregroundStyle(CouncisTheme.secondaryText(scheme))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 26)
            .padding(.bottom, 22)
        }
        .background {
            Rectangle()
                .fill(CouncisTheme.glassSurface(scheme).opacity(scheme == .dark ? 0.16 : 0.22))
                .background(.thinMaterial)
        }
    }
}

private struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(CouncisType.caption(11, .semibold))
                .foregroundStyle(CouncisTheme.secondaryText(scheme))
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .councisGlassCard(cornerRadius: 14, fillOpacity: 0.44, strokeOpacity: 0.40, shadowOpacity: 0.03)
    }
}

private struct CandidateRow: View {
    let candidate: CouncilCandidateViewState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(candidate.name)
                    .font(CouncisType.body(12, .semibold))
                    .foregroundStyle(CouncisTheme.primaryText(scheme))
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(candidate.status.rawValue)
                    .font(CouncisType.mono(11, .medium))
                    .foregroundStyle(statusColor)
            }

            HStack(spacing: 8) {
                Text(candidate.model)
                    .font(CouncisType.mono(11))
                    .foregroundStyle(CouncisTheme.secondaryText(scheme))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 4)
                if let latencyText = candidate.latencyText {
                    Text(latencyText)
                        .font(CouncisType.mono(11))
                        .foregroundStyle(CouncisTheme.tertiaryText(scheme))
                }
            }
        }
    }

    private var statusColor: Color {
        switch candidate.status {
        case .waiting:
            return CouncisTheme.tertiaryText(scheme)
        case .running:
            return CouncisTheme.accentBlue
        case .done:
            return .green
        case .failed:
            return .red
        }
    }
}

private struct InspectorKeyValue: View {
    let label: String
    let value: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(CouncisType.caption(11, .semibold))
                .foregroundStyle(CouncisTheme.tertiaryText(scheme))
            Text(value)
                .font(CouncisType.body(12))
                .foregroundStyle(CouncisTheme.primaryText(scheme))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }
}

private struct AuditRow: View {
    let text: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(CouncisTheme.accentBlue.opacity(0.55))
                .frame(width: 5, height: 5)
            Text(text)
                .font(CouncisType.body(12))
                .foregroundStyle(CouncisTheme.secondaryText(scheme))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }
}
#endif
