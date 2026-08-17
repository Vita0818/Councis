#if canImport(SwiftUI)
import SwiftUI
import UniformTypeIdentifiers
import CouncisSharedUI

/// The macOS composer attachment control shared verbatim by Chat and Cowork.
/// Surface-specific code supplies only the current draft and its callbacks.
struct CouncisMacComposerAttachmentAccessory: View {
    let attachments: [CouncisComposerDraftAttachment]
    let accessibilityPrefix: String
    var isBusy = false
    var isDisabled = false
    let onAttach: () -> Void
    let onRemove: (CouncisComposerDraftAttachment.ID) -> Void

    var body: some View {
        HStack(
            alignment: .center,
            spacing: CouncisComposerControlMetrics.rowSpacing
        ) {
            Button(action: onAttach) {
                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .frame(
                            width: CouncisComposerControlMetrics.iconLabelExtent,
                            height: CouncisComposerControlMetrics.iconLabelExtent)
                } else {
                    Label(
                        CouncisLocalization.string("Attach files"),
                        systemImage: "paperclip")
                        .councisComposerIconLabel()
                }
            }
            .councisCompactIconButton()
            .help(CouncisLocalization.string("Attach files"))
            .accessibilityLabel(CouncisLocalization.string("Attach files"))
            .accessibilityIdentifier("\(accessibilityPrefix).composer.attach")
            .disabled(isDisabled || isBusy)

            if !attachments.isEmpty {
                Menu {
                    ForEach(attachments) { attachment in
                        Button(CouncisLocalization.format(
                            "Remove %@",
                            attachment.name)) {
                            onRemove(attachment.id)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(CouncisLocalization.format(
                            "%lld attached",
                            Int64(attachments.count)))
                            .font(CouncisTypography.body(13, .semibold))
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    .councisComposerSelectionLabel()
                }
                .councisComposerSelectionMenu()
                .accessibilityIdentifier(
                    "\(accessibilityPrefix).composer.attachments")
                .disabled(isDisabled || isBusy)
            }
        }
        .frame(
            minHeight: CouncisComposerControlMetrics.controlHeight,
            alignment: .center)
    }
}

private struct CouncisMacComposerAttachmentImportModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onImport: ([URL]) -> Void
    let onFailure: (Error) -> Void

    func body(content: Content) -> some View {
        content
            .fileImporter(
                isPresented: $isPresented,
                allowedContentTypes: [.data, .content],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    onImport(urls)
                case .failure(let error):
                    onFailure(error)
                }
            }
            .dropDestination(for: URL.self) { urls, _ in
                guard !urls.isEmpty else { return false }
                onImport(urls)
                return true
            }
    }
}

extension View {
    func councisComposerAttachmentImport(
        isPresented: Binding<Bool>,
        onImport: @escaping ([URL]) -> Void,
        onFailure: @escaping (Error) -> Void
    ) -> some View {
        modifier(CouncisMacComposerAttachmentImportModifier(
            isPresented: isPresented,
            onImport: onImport,
            onFailure: onFailure))
    }
}
#endif
