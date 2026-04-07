import SwiftUI

struct StatusBadge: View {
    let status: ProjectStatus

    var body: some View {
        Label(status.title, systemImage: iconName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.statusColor(status))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppTheme.statusColor(status).opacity(0.18), in: Capsule())
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
    let priority: PriorityLevel

    var body: some View {
        Text(priority.title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppTheme.priorityColor(priority).opacity(0.24), in: Capsule())
    }
}

struct TagChip: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
    }
}
