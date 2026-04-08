import SwiftUI

struct PanelCard<Content: View>: View {
    @Environment(\.appTheme) private var theme
    let title: String
    let subtitle: String?
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                }
            }

            content
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(theme.panelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(theme.chromeStroke, lineWidth: 1)
        )
        .shadow(color: theme.shadow, radius: 18, x: 0, y: 10)
    }
}

struct MetricCard: View {
    @Environment(\.appTheme) private var theme
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2.weight(.bold))
                .foregroundStyle(tint)

            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(theme.primaryText)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(theme.insetBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(theme.subtleStroke, lineWidth: 1)
        )
    }
}

struct QuickActionButton: View {
    @Environment(\.appTheme) private var theme
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(tint.opacity(0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(tint.opacity(0.22), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct CompactActionMenu<Content: View>: View {
    @Environment(\.appTheme) private var theme
    let title: String
    let systemImage: String
    let tint: Color?
    @ViewBuilder let content: Content

    init(
        title: String,
        systemImage: String,
        tint: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        Menu {
            content
        } label: {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint ?? theme.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(theme.insetBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke((tint ?? theme.subtleStroke).opacity(tint == nil ? 1 : 0.35), lineWidth: 1)
                )
        }
        .menuStyle(.borderlessButton)
    }
}

struct FocusCandidateCard: View {
    @Environment(\.appTheme) private var theme
    let candidate: FocusCandidate
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: candidate.kind.systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(accentColor)
                        .frame(width: 26)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(candidate.title)
                            .font(.headline)
                            .foregroundStyle(theme.primaryText)

                        Text(candidate.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)

                        if !candidate.reason.isEmpty {
                            Text(candidate.reason)
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText)
                        }
                    }

                    Spacer(minLength: 8)

                    if let dueDate = candidate.dueDate {
                        Text(dueDate, format: .dateTime.day().month(.abbreviated))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.secondaryText)
                    }
                }

                if !candidate.detail.isEmpty {
                    Text(candidate.detail)
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if let status = candidate.status {
                        StatusBadge(status: status)
                    }

                    if let priority = candidate.priority {
                        PriorityBadge(priority: priority)
                    }

                    if candidate.isBlocked {
                        TagChip(title: "Blocked")
                    }
                }
            }
            .padding(16)
            .appInsetCard(stroke: accentColor.opacity(0.18))
        }
        .buttonStyle(.plain)
    }

    private var accentColor: Color {
        if candidate.isBlocked {
            return theme.statusColor(.blocked)
        }

        if let priority = candidate.priority {
            return theme.priorityColor(priority)
        }

        return theme.accent
    }
}

private struct AppInsetCardModifier: ViewModifier {
    @Environment(\.appTheme) private var theme
    let isSelected: Bool
    let stroke: Color?

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? theme.selectedInsetBackground : theme.insetBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(stroke ?? (isSelected ? theme.accent.opacity(0.45) : theme.subtleStroke), lineWidth: 1)
            )
    }
}

extension View {
    func appInsetCard(selected: Bool = false, stroke: Color? = nil) -> some View {
        modifier(AppInsetCardModifier(isSelected: selected, stroke: stroke))
    }
}
