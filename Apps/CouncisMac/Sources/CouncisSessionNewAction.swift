import SwiftUI
import IntatisCore
import IntatisSharedUI

/// Product-owned menu action for Councis's existing two-choice New control.
/// It is UI composition state, not a Runtime or Intatis protocol wrapper.
struct CouncisSessionNewAction {
    let title: String
    let systemImage: String
    let action: () -> Void
}

/// Councis keeps its established two-choice New menu while using Intatis's
/// shared session row model, typography, and native glass implementation.
struct CouncisSessionHistoryList: View {
    let title: String
    let newTitle: String
    let emptyTitle: String
    let items: [IntatisSessionHistoryItem]
    let style: IntatisThreadStyle
    var isNewDisabled = false
    var newActions: [CouncisSessionNewAction] = []
    let onNew: () -> Void
    let onSelect: (SessionID) -> Void
    var onRename: ((SessionID) -> Void)?
    var onDelete: ((SessionID) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Text(title)
                    .font(IntatisTypography.system(
                        size: 12,
                        weight: .semibold))
                    .foregroundStyle(style.secondaryText)
                    .lineLimit(1)
                Spacer(minLength: 0)
                newControl
            }

            if items.isEmpty {
                Text(emptyTitle)
                    .font(IntatisTypography.system(
                        size: 12,
                        weight: .medium))
                    .foregroundStyle(style.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    LazyVStack(spacing: 5) {
                        ForEach(items) { item in
                            Button {
                                onSelect(item.id)
                            } label: {
                                CouncisSessionHistoryRow(
                                    item: item,
                                    style: style)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(
                                "sidebar.session.\(item.id.rawValue)")
                            .contextMenu {
                                if let onRename {
                                    Button {
                                        onRename(item.id)
                                    } label: {
                                        Label(
                                            "Rename…",
                                            systemImage: "pencil")
                                    }
                                }
                                if let onDelete {
                                    if onRename != nil { Divider() }
                                    Button(role: .destructive) {
                                        onDelete(item.id)
                                    } label: {
                                        Label(
                                            "Delete…",
                                            systemImage: "trash")
                                    }
                                    .disabled(item.isDeleteDisabled)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }
                .scrollIndicators(.automatic)
            }
        }
    }

    @ViewBuilder private var newControl: some View {
        if newActions.isEmpty {
            Button(action: onNew) { newControlLabel }
                .controlSize(.small)
                .buttonBorderShape(.circle)
                .intatisGlassButton()
                .disabled(isNewDisabled)
                .help(newTitle)
                .accessibilityLabel(newTitle)
                .accessibilityIdentifier("sidebar.session.new")
        } else {
            Menu {
                ForEach(newActions.indices, id: \.self) { index in
                    let item = newActions[index]
                    Button(action: item.action) {
                        Label(item.title, systemImage: item.systemImage)
                    }
                }
            } label: {
                newControlLabel
            }
            .menuIndicator(.hidden)
            .controlSize(.small)
            .buttonBorderShape(.circle)
            .intatisGlassButton()
            .disabled(isNewDisabled)
            .help(newTitle)
            .accessibilityLabel(newTitle)
            .accessibilityIdentifier("sidebar.session.new")
        }
    }

    private var newControlLabel: some View {
        Label(newTitle, systemImage: "plus")
            .labelStyle(.iconOnly)
            .font(IntatisTypography.system(
                size: 12,
                weight: .semibold))
            .frame(width: 24, height: 24)
    }
}

private struct CouncisSessionHistoryRow: View {
    let item: IntatisSessionHistoryItem
    let style: IntatisThreadStyle

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: item.systemImage)
                .font(IntatisTypography.system(
                    size: 12,
                    weight: .medium))
                .foregroundStyle(
                    item.isSelected ? style.accent : style.tertiaryText)
                .frame(width: 16, height: 16)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(IntatisTypography.system(
                        size: 12,
                        weight: item.isSelected ? .semibold : .medium))
                    .foregroundStyle(
                        item.isSelected
                            ? style.primaryText
                            : style.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !item.detail.isEmpty {
                    Text(item.detail)
                        .font(IntatisTypography.system(
                            size: 11,
                            weight: .regular))
                        .foregroundStyle(style.tertiaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    item.isSelected
                        ? style.accent.opacity(0.42)
                        : Color.clear,
                    lineWidth: 1)
        }
        .contentShape(
            RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
