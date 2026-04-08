import SwiftUI

struct BubbleInspectorView: View {
    @Environment(\.appTheme) private var theme
    let inspector: BubbleInspectorContext?
    let focusedProjectID: UUID?
    let focusAction: (UUID) -> Void
    let clearSelectionAction: () -> Void
    let openProjectsAction: ((BubbleInspectorContext) -> Void)?
    let setStatusAction: ((BubbleInspectorContext, ProjectStatus) -> Void)?
    let setPriorityAction: ((BubbleInspectorContext, PriorityLevel) -> Void)?
    let scheduleTodayAction: ((BubbleInspectorContext) -> Void)?
    let shiftScheduleAction: ((BubbleInspectorContext, Int) -> Void)?
    let clearScheduleAction: ((BubbleInspectorContext) -> Void)?
    let archiveProjectAction: ((BubbleInspectorContext) -> Void)?
    let restoreProjectAction: ((BubbleInspectorContext) -> Void)?
    let deleteSelectionAction: ((BubbleInspectorContext) -> Void)?
    let isProjectArchived: ((BubbleInspectorContext) -> Bool)?

    init(
        inspector: BubbleInspectorContext?,
        focusedProjectID: UUID?,
        focusAction: @escaping (UUID) -> Void,
        clearSelectionAction: @escaping () -> Void,
        openProjectsAction: ((BubbleInspectorContext) -> Void)? = nil,
        setStatusAction: ((BubbleInspectorContext, ProjectStatus) -> Void)? = nil,
        setPriorityAction: ((BubbleInspectorContext, PriorityLevel) -> Void)? = nil,
        scheduleTodayAction: ((BubbleInspectorContext) -> Void)? = nil,
        shiftScheduleAction: ((BubbleInspectorContext, Int) -> Void)? = nil,
        clearScheduleAction: ((BubbleInspectorContext) -> Void)? = nil,
        archiveProjectAction: ((BubbleInspectorContext) -> Void)? = nil,
        restoreProjectAction: ((BubbleInspectorContext) -> Void)? = nil,
        deleteSelectionAction: ((BubbleInspectorContext) -> Void)? = nil,
        isProjectArchived: ((BubbleInspectorContext) -> Bool)? = nil
    ) {
        self.inspector = inspector
        self.focusedProjectID = focusedProjectID
        self.focusAction = focusAction
        self.clearSelectionAction = clearSelectionAction
        self.openProjectsAction = openProjectsAction
        self.setStatusAction = setStatusAction
        self.setPriorityAction = setPriorityAction
        self.scheduleTodayAction = scheduleTodayAction
        self.shiftScheduleAction = shiftScheduleAction
        self.clearScheduleAction = clearScheduleAction
        self.archiveProjectAction = archiveProjectAction
        self.restoreProjectAction = restoreProjectAction
        self.deleteSelectionAction = deleteSelectionAction
        self.isProjectArchived = isProjectArchived
    }

    var body: some View {
        PanelCard(
            title: "Selection Inspector",
            subtitle: "Use the selected node to understand blockers, links, milestones, and whether a project deserves focused attention."
        ) {
            if let inspector {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(inspector.title)
                            .font(.title3.weight(.semibold))

                        Text(inspector.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)

                        HStack(spacing: 8) {
                            StatusBadge(status: inspector.status)
                            PriorityBadge(priority: inspector.priority)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        ProgressView(value: inspector.progress) {
                            Text("Progress")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.secondaryText)
                        } currentValueLabel: {
                            Text(inspector.progress, format: .percent.precision(.fractionLength(0)))
                                .font(.caption.weight(.bold))
                        }

                        if let dueDate = inspector.dueDate {
                            Label {
                                Text(dueDate, format: .dateTime.day().month(.abbreviated))
                            } icon: {
                                Image(systemName: "calendar")
                            }
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                        }
                    }

                    HStack(spacing: 12) {
                        MetricCard(
                            title: inspector.kind == .project ? "Open Steps" : "Project Open Steps",
                            value: "\(inspector.openStepCount)",
                            systemImage: "list.bullet.rectangle",
                            tint: theme.projectColor(.cobalt)
                        )
                        MetricCard(
                            title: "Dependencies",
                            value: "\(inspector.dependencyCount)",
                            systemImage: "arrow.triangle.branch",
                            tint: theme.accent
                        )
                    }

                    if inspector.isBlocked || inspector.blockedStepCount > 0 {
                        Label(
                            "\(inspector.blockedStepCount) blocked step\(inspector.blockedStepCount == 1 ? "" : "s") in \(inspector.projectTitle)",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.statusColor(.blocked))
                    }

                    if !inspector.upcomingMilestones.isEmpty {
                        BubbleInspectorSection(title: "Upcoming Milestones") {
                            ForEach(inspector.upcomingMilestones) { milestone in
                                HStack {
                                    Text(milestone.title)
                                    Spacer()
                                    if let dueDate = milestone.dueDate {
                                        Text(dueDate, format: .dateTime.day().month(.abbreviated))
                                            .foregroundStyle(theme.secondaryText)
                                    }
                                }
                                .font(.subheadline)
                            }
                        }
                    }

                    if !inspector.incomingDependencies.isEmpty {
                        BubbleInspectorSection(title: "Incoming Links") {
                            ForEach(inspector.incomingDependencies) { dependency in
                                BubbleInspectorDependencyRow(dependency: dependency)
                            }
                        }
                    }

                    if !inspector.outgoingDependencies.isEmpty {
                        BubbleInspectorSection(title: "Outgoing Links") {
                            ForEach(inspector.outgoingDependencies) { dependency in
                                BubbleInspectorDependencyRow(dependency: dependency)
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        Button(
                            focusedProjectID == inspector.projectID ? "Release Focus" : "Focus Project",
                            action: { focusAction(inspector.projectID) }
                        )
                        .buttonStyle(.borderedProminent)
                        .tint(theme.accent)

                        Button("Clear Selection", action: clearSelectionAction)
                            .buttonStyle(.bordered)
                    }

                    if showsQuickActions {
                        quickActionStrip(for: inspector)
                    }
                }
            } else {
                EmptyStateView(
                    title: "Nothing Selected",
                    message: "Choose a bubble to inspect its priority, blocker state, open steps, milestones, and dependency context.",
                    systemImage: "point.3.connected.trianglepath.dotted"
                )
            }
        }
    }

    @ViewBuilder
    private func quickActionStrip(for inspector: BubbleInspectorContext) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 10) {
                if let openProjectsAction {
                    Button("Open In Projects") {
                        openProjectsAction(inspector)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)
                }

                if let deleteSelectionAction {
                    Button("Delete Permanently", role: .destructive) {
                        deleteSelectionAction(inspector)
                    }
                    .buttonStyle(.bordered)
                }
            }

            HStack(spacing: 10) {
                if let setStatusAction {
                    CompactActionMenu(title: "Status", systemImage: "flag.fill", tint: theme.accent) {
                        ForEach(ProjectStatus.allCases) { status in
                            Button(status.title) {
                                setStatusAction(inspector, status)
                            }
                        }
                    }
                }

                if let setPriorityAction {
                    CompactActionMenu(title: "Priority", systemImage: "exclamationmark.circle") {
                        ForEach(PriorityLevel.allCases) { priority in
                            Button(priority.title) {
                                setPriorityAction(inspector, priority)
                            }
                        }
                    }
                }

                if scheduleTodayAction != nil || shiftScheduleAction != nil || clearScheduleAction != nil {
                    CompactActionMenu(title: "Schedule", systemImage: "calendar") {
                        if let scheduleTodayAction {
                            Button("Schedule Today") {
                                scheduleTodayAction(inspector)
                            }
                        }

                        if let shiftScheduleAction {
                            Button("Bring Forward 1 Week") {
                                shiftScheduleAction(inspector, -7)
                            }

                            Button("Push Back 1 Week") {
                                shiftScheduleAction(inspector, 7)
                            }
                        }

                        if let clearScheduleAction {
                            Button("Clear Dates") {
                                clearScheduleAction(inspector)
                            }
                        }
                    }
                }
            }

            if inspector.kind == .project {
                HStack(spacing: 12) {
                    if let isProjectArchived, isProjectArchived(inspector), let restoreProjectAction {
                        Button("Restore Project") {
                            restoreProjectAction(inspector)
                        }
                        .buttonStyle(.bordered)
                    } else if let archiveProjectAction {
                        Button("Archive Project") {
                            archiveProjectAction(inspector)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private var showsQuickActions: Bool {
        openProjectsAction != nil ||
        setStatusAction != nil ||
        setPriorityAction != nil ||
        scheduleTodayAction != nil ||
        shiftScheduleAction != nil ||
        clearScheduleAction != nil ||
        archiveProjectAction != nil ||
        restoreProjectAction != nil ||
        deleteSelectionAction != nil
    }
}

private struct BubbleInspectorSection<Content: View>: View {
    @Environment(\.appTheme) private var theme
    let title: String
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
            content
        }
    }
}

private struct BubbleInspectorDependencyRow: View {
    @Environment(\.appTheme) private var theme
    let dependency: BubbleInspectorDependency

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(dependency.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(dependency.type.title)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }

            Text(dependency.subtitle)
                .font(.caption)
                .foregroundStyle(theme.secondaryText)

            if !dependency.note.isEmpty {
                Text(dependency.note)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(12)
        .appInsetCard(stroke: theme.subtleStroke)
    }
}
