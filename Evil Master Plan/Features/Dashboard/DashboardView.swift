import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query private var projects: [Project]
    @Query(sort: [SortDescriptor(\IdeaInboxItem.createdAt, order: .reverse)]) private var inboxItems: [IdeaInboxItem]

    private var snapshot: DashboardSnapshot {
        PlanningProjectionFactory.dashboard(projects: projects, inboxItems: inboxItems)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PanelCard(
                    title: "Mission Control",
                    subtitle: "A calm overview of what is moving, what is blocked, and what needs attention next."
                ) {
                    Text("The app is structured around one shared planning model. Bubble, Gantt, and dependency views are all reading the same projects, steps, and links.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 16)], spacing: 16) {
                    MetricCard(
                        title: "Active Projects",
                        value: "\(snapshot.activeProjectCount)",
                        systemImage: "bolt.fill",
                        tint: AppTheme.statusColor(.active)
                    )
                    MetricCard(
                        title: "Blocked",
                        value: "\(snapshot.blockedProjectCount)",
                        systemImage: "exclamationmark.triangle.fill",
                        tint: AppTheme.statusColor(.blocked)
                    )
                    MetricCard(
                        title: "Open Inbox",
                        value: "\(snapshot.inboxCount)",
                        systemImage: "tray.and.arrow.down.fill",
                        tint: AppTheme.projectColor(.cobalt)
                    )
                    MetricCard(
                        title: "Milestones",
                        value: "\(snapshot.milestoneCount)",
                        systemImage: "flag.checkered.2.crossed",
                        tint: AppTheme.projectColor(.rose)
                    )
                }

                PanelCard(title: "Focus Soon", subtitle: "Next due items sorted by urgency and date.") {
                    if snapshot.focusItems.isEmpty {
                        EmptyStateView(
                            title: "No Near-Term Commitments",
                            message: "Add due dates to project steps to populate the focus lane.",
                            systemImage: "calendar.badge.clock"
                        )
                    } else {
                        VStack(spacing: 14) {
                            ForEach(snapshot.focusItems) { item in
                                HStack(alignment: .top, spacing: 14) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title)
                                            .font(.headline)
                                        Text(item.subtitle)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 8) {
                                        PriorityBadge(priority: item.priority)
                                        Text(item.dueDate, format: .dateTime.day().month(.abbreviated))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(16)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }
                        }
                    }
                }

                PanelCard(title: "Recently Touched", subtitle: "Projects with visible recent motion.") {
                    VStack(spacing: 14) {
                        ForEach(projects.sorted(using: SortDescriptor(\.updatedAt, order: .reverse)).prefix(3)) { project in
                            HStack(alignment: .top, spacing: 14) {
                                Circle()
                                    .fill(AppTheme.projectColor(project.colorToken))
                                    .frame(width: 14, height: 14)
                                    .padding(.top, 4)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(project.title)
                                        .font(.headline)
                                    Text(project.summary)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer()

                                StatusBadge(status: project.status)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Dashboard")
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
    .modelContainer(PreviewContainer.shared)
}
