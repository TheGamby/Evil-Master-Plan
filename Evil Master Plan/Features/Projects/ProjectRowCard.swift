import SwiftUI

struct ProjectRowCard: View {
    @Environment(\.appTheme) private var theme
    let project: Project
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.projectColor(project.colorToken))
                .frame(width: 12, height: 64)

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(project.title)
                        .font(.headline)
                        .foregroundStyle(theme.primaryText)
                    Text(project.summary)
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    StatusBadge(status: project.status)
                    PriorityBadge(priority: project.priority)
                    TagChip(title: "\(project.steps.count) steps")

                    if project.isArchived {
                        ArchiveBadge()
                    }
                }

                HStack {
                    Text(project.progress, format: .percent.precision(.fractionLength(0)))
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)

                    Spacer()

                    if let dueDate = project.resolvedDueDate {
                        Text(dueDate, format: .dateTime.day().month(.abbreviated))
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                    }
                }
            }

            Spacer()
        }
        .padding(16)
        .appInsetCard(selected: isSelected, stroke: isSelected ? theme.accent.opacity(0.65) : theme.subtleStroke)
    }
}
