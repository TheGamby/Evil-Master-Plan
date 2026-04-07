import SwiftUI

struct ProjectRowCard: View {
    let project: Project
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.projectColor(project.colorToken))
                .frame(width: 12, height: 64)

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(project.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(project.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    StatusBadge(status: project.status)
                    PriorityBadge(priority: project.priority)
                    TagChip(title: "\(project.steps.count) steps")
                }

                HStack {
                    Text(project.progress, format: .percent.precision(.fractionLength(0)))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if let dueDate = project.resolvedDueDate {
                        Text(dueDate, format: .dateTime.day().month(.abbreviated))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(isSelected ? .regularMaterial : .thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isSelected ? AppTheme.accent.opacity(0.65) : .white.opacity(0.05), lineWidth: 1)
        )
    }
}
