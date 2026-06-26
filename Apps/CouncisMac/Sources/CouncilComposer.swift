#if canImport(SwiftUI)
import SwiftUI

struct CouncilComposer: View {
    let placeholder: String
    let onSend: (String) -> Void
    @Environment(\.colorScheme) private var scheme
    @FocusState private var focused: Bool
    @State private var input = ""

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(placeholder, text: $input, axis: .vertical)
                .textFieldStyle(.plain)
                .font(CouncisType.chat(15))
                .foregroundStyle(CouncisTheme.primaryText(scheme))
                .lineLimit(1...6)
                .focused($focused)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .councisGlassCapsule()
                .onSubmit(send)

            Button(action: send) {
                ZStack {
                    Circle()
                        .fill(canSend
                              ? AnyShapeStyle(CouncisTheme.accentGradient)
                              : AnyShapeStyle(CouncisTheme.glassSurface(scheme).opacity(0.52)))
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(canSend ? .white : CouncisTheme.tertiaryText(scheme))
                }
                .frame(width: 40, height: 40)
                .shadow(color: CouncisTheme.accentBlue.opacity(canSend && scheme == .light ? 0.22 : 0),
                        radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""
        onSend(text)
    }
}
#endif
