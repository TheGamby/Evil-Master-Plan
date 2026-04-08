import SwiftUI

struct StatusBadge: View {
    @Environment(\.appTheme) private var theme
    let status: ProjectStatus

    var body: some View {
        Label(status.title, systemImage: iconName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(theme.statusColor(status))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.statusColor(status).opacity(0.18), in: Capsule())
    }

    private var iconName: String {
        switch status {
        case .idea:
            "lightbulb"
        case .active:
            "bolt.fill"
        case .paused:
            "pause.fill"
        case .blocked:
            "exclamationmark.triangle.fill"
        case .done:
            "checkmark.circle.fill"
        }
    }
}

struct PriorityBadge: View {
    @Environment(\.appTheme) private var theme
    let priority: PriorityLevel

    var body: some View {
        Text(priority.title)
            .font(.caption.weight(.bold))
            .foregroundStyle(theme.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.priorityColor(priority).opacity(0.24), in: Capsule())
    }
}

struct TagChip: View {
    @Environment(\.appTheme) private var theme
    let title: String

    var body: some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(theme.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.insetBackground, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(theme.subtleStroke, lineWidth: 1)
            )
    }
}

struct InboxStateBadge: View {
    @Environment(\.appTheme) private var theme
    let state: IdeaInboxState

    var body: some View {
        Text(state.title)
            .font(.caption.weight(.bold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(backgroundColor, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(foregroundColor.opacity(0.18), lineWidth: 1)
            )
    }

    private var foregroundColor: Color {
        switch state {
        case .open:
            theme.accent
        case .reviewing:
            theme.projectColor(.cyan)
        case .converted:
            theme.statusColor(.done)
        case .archived:
            theme.secondaryText
        }
    }

    private var backgroundColor: Color {
        switch state {
        case .open:
            theme.accent.opacity(0.14)
        case .reviewing:
            theme.projectColor(.cyan).opacity(0.12)
        case .converted:
            theme.statusColor(.done).opacity(0.14)
        case .archived:
            theme.secondaryText.opacity(0.08)
        }
    }
}

struct InboxConversionBadge: View {
    @Environment(\.appTheme) private var theme
    let target: IdeaInboxConversionTarget

    var body: some View {
        Text(target.title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(theme.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.priorityColor(.medium).opacity(0.16), in: Capsule())
    }
}

struct ArchiveBadge: View {
    @Environment(\.appTheme) private var theme
    let title: String

    init(title: String = "Archived") {
        self.title = title
    }

    var body: some View {
        Label(title, systemImage: "archivebox.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(theme.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.secondaryText.opacity(0.1), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(theme.subtleStroke, lineWidth: 1)
            )
    }
}
