import SwiftUI
import SwiftData

struct GanttView: View {
    @Query private var projects: [Project]
    @Query private var preferences: [ViewPreferences]

    private let dayWidth: CGFloat = 34
    private let labelWidth: CGFloat = 220

    private var projection: GanttProjection {
        PlanningProjectionFactory.gantt(
            projects: projects,
            showCompletedItems: preferences.first?.showCompletedItems ?? true
        )
    }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 18) {
                PanelCard(title: "Timeline", subtitle: "Projects and steps are rendered from the same shared dates used elsewhere.") {
                    Toggle("Show completed items", isOn: showCompletedItemsBinding)
                }

                VStack(spacing: 0) {
                    timelineHeader
                    Divider().overlay(.white.opacity(0.08))
                    ForEach(projection.rows) { row in
                        GanttRowView(
                            row: row,
                            timelineStart: projection.timelineStart,
                            dayWidth: dayWidth,
                            labelWidth: labelWidth
                        )
                        Divider().overlay(.white.opacity(0.05))
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.92))
                )
            }
            .padding(24)
        }
        .navigationTitle("Gantt")
    }

    private var timelineHeader: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: labelWidth, height: 48)

            ForEach(0..<projection.dayCount, id: \.self) { dayOffset in
                let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: projection.timelineStart) ?? projection.timelineStart
                Text(date, format: .dateTime.day().month(.abbreviated))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: dayWidth, height: 48)
            }
        }
    }

    private var showCompletedItemsBinding: Binding<Bool> {
        Binding(
            get: { preferences.first?.showCompletedItems ?? true },
            set: { preferences.first?.showCompletedItems = $0 }
        )
    }
}

private struct GanttRowView: View {
    let row: GanttRowProjection
    let timelineStart: Date
    let dayWidth: CGFloat
    let labelWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 12) {
                Circle()
                    .fill(AppTheme.projectColor(row.colorToken))
                    .frame(width: row.indentLevel == 0 ? 12 : 8, height: row.indentLevel == 0 ? 12 : 8)
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.title)
                        .font(row.indentLevel == 0 ? .headline : .subheadline.weight(.medium))
                    Text(row.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, CGFloat(row.indentLevel) * 18)
            .frame(width: labelWidth, alignment: .leading)
            .padding(.vertical, 12)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.white.opacity(0.04))
                    .frame(width: barWidth, height: row.kind == .milestone ? 18 : 24)
                    .offset(x: barX)

                if row.kind == .milestone {
                    Diamond()
                        .fill(AppTheme.projectColor(row.colorToken))
                        .frame(width: 18, height: 18)
                        .offset(x: barX + max(barWidth - 9, 0))
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.projectColor(row.colorToken))
                        .frame(width: max(barWidth * row.progress, 12), height: 24)
                        .offset(x: barX)
                }
            }
            .frame(width: barWidth + barX + 40, alignment: .leading)
            .padding(.vertical, 14)
        }
    }

    private var startOffset: Int {
        Calendar.current.dateComponents([.day], from: timelineStart, to: row.startDate).day ?? 0
    }

    private var durationDays: Int {
        let value = Calendar.current.dateComponents([.day], from: row.startDate, to: row.endDate).day ?? 0
        return max(value + 1, 1)
    }

    private var barX: CGFloat {
        CGFloat(startOffset) * dayWidth
    }

    private var barWidth: CGFloat {
        CGFloat(durationDays) * dayWidth
    }
}

private struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.closeSubpath()
        }
    }
}

#Preview {
    NavigationStack {
        GanttView()
    }
    .modelContainer(PreviewContainer.shared)
}
