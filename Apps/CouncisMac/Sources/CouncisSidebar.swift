#if canImport(SwiftUI)
import SwiftUI

struct CouncisSidebar: View {
    @Binding var selection: CouncisSection
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Councis")
                    .font(CouncisType.brand(28))
                    .foregroundStyle(CouncisTheme.primaryText(scheme))
                Text("Mac")
                    .font(CouncisType.caption(12, .semibold))
                    .foregroundStyle(CouncisTheme.secondaryText(scheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 18)

            VStack(spacing: 6) {
                ForEach(CouncisSection.allCases) { item in
                    Button {
                        selection = item
                    } label: {
                        CouncisSidebarRow(item: item, selected: selection == item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)

            Spacer(minLength: 0)
        }
        .background {
            Rectangle()
                .fill(CouncisTheme.glassSurface(scheme).opacity(scheme == .dark ? 0.20 : 0.30))
                .background(.thinMaterial)
        }
    }
}

private struct CouncisSidebarRow: View {
    let item: CouncisSection
    let selected: Bool
    @Environment(\.colorScheme) private var scheme
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.symbolName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(selected ? CouncisTheme.accentDeep : CouncisTheme.secondaryText(scheme))
                .frame(width: 20)

            Text(item.title)
                .font(CouncisType.body(13, selected ? .semibold : .medium))
                .foregroundStyle(selected ? CouncisTheme.primaryText(scheme) : CouncisTheme.secondaryText(scheme))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background { rowBackground }
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(CouncisTheme.accentBlue.opacity(scheme == .dark ? 0.34 : 0.36), lineWidth: 1)
                .opacity(selected ? 1 : (hovering ? 0.45 : 0))
        }
        .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .onHover { hovering = $0 }
    }

    @ViewBuilder private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(selected ? AnyShapeStyle(selectedFill)
                           : AnyShapeStyle(CouncisTheme.glassSurface(scheme).opacity(scheme == .dark ? 0.14 : 0.26)))
            .opacity(selected || hovering ? 1 : 0)
    }

    private var selectedFill: LinearGradient {
        LinearGradient(
            colors: [
                CouncisTheme.accentPale.opacity(scheme == .dark ? 0.16 : 0.88),
                CouncisTheme.accentHighlight.opacity(scheme == .dark ? 0.20 : 0.24)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
#endif
