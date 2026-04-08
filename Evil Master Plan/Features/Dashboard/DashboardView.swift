import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigationModel.self) private var navigation
    @Query private var projects: [Project]
    @Query private var dependencies: [Dependency]
    @Query(sort: [SortDescriptor(\IdeaInboxItem.updatedAt, order: .reverse)]) private var inboxItems: [IdeaInboxItem]
    @State private var mutationError: String?
    @State private var pendingDeletionReference: PlanningItemReference?
    @State private var pendingInboxDeletionID: UUID?

    private var snapshot: FocusSnapshot {
        FocusProjectionFactory.snapshot(
            projects: projects,
            dependencies: dependencies,
            inboxItems: inboxItems
        )
    }

    private var firstInboxItemID: UUID? {
        guard let destination = snapshot.sections
            .first(where: { $0.kind == .inbox })?
            .items
            .first?
            .destination,
            case .inbox(let itemID) = destination
        else {
            return nil
        }

        return itemID
    }

    private var pendingDeletionItemTitle: String {
        if let pendingInboxDeletionID, let item = inboxItems.first(where: { $0.id == pendingInboxDeletionID }) {
            return item.title
        }

        guard let pendingDeletionReference else {
            return "this item"
        }

        switch pendingDeletionReference.kind {
        case .project:
            return projects.first(where: { $0.id == pendingDeletionReference.id })?.title ?? "this project"
        case .step:
            return projects.flatMap(\.steps).first(where: { $0.id == pendingDeletionReference.id })?.title ?? "this step"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PanelCard(
                    title: "Focus Cockpit",
                    subtitle: "The start screen is now a working surface: triage the inbox, spot blockers, pick the next step, and jump straight into concrete edits."
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Bubble, Gantt, Dependencies, Projects, and Focus all read the same projects, steps, and dependency rules. This screen only curates what matters right now.")
                            .font(.body)
                            .foregroundStyle(theme.secondaryText)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                            QuickActionButton(
                                title: "Review Inbox",
                                systemImage: "tray.and.arrow.down.fill",
                                tint: theme.projectColor(.cobalt)
                            ) {
                                navigation.openInbox(firstInboxItemID)
                            }

                            QuickActionButton(
                                title: "Open Projects",
                                systemImage: "square.stack.3d.up.fill",
                                tint: theme.projectColor(.ember)
                            ) {
                                navigation.selection = .projects
                            }

                            QuickActionButton(
                                title: "Plan Timeline",
                                systemImage: "chart.bar.xaxis",
                                tint: theme.projectColor(.lime)
                            ) {
                                navigation.selection = .gantt
                            }
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 16)], spacing: 16) {
                    MetricCard(
                        title: "Active Projects",
                        value: "\(snapshot.activeProjectCount)",
                        systemImage: "bolt.fill",
                        tint: theme.statusColor(.active)
                    )
                    MetricCard(
                        title: "Blocked Items",
                        value: "\(snapshot.blockedItemCount)",
                        systemImage: "exclamationmark.triangle.fill",
                        tint: theme.statusColor(.blocked)
                    )
                    MetricCard(
                        title: "Inbox Triage",
                        value: "\(snapshot.triageCount)",
                        systemImage: "tray.and.arrow.down.fill",
                        tint: theme.projectColor(.cobalt)
                    )
                    MetricCard(
                        title: "Soon Milestones",
                        value: "\(snapshot.soonMilestoneCount)",
                        systemImage: "flag.checkered.2.crossed",
                        tint: theme.projectColor(.rose)
                    )
                }

                ForEach(snapshot.sections) { section in
                    PanelCard(title: section.title, subtitle: section.subtitle) {
                        if section.items.isEmpty {
                            EmptyStateView(
                                title: section.kind.emptyTitle,
                                message: section.kind.emptyMessage,
                                systemImage: emptyStateIcon(for: section.kind)
                            )
                        } else {
                            VStack(spacing: 14) {
                                ForEach(section.items) { candidate in
                                    FocusCandidateCard(candidate: candidate) {
                                        navigation.openDestination(candidate.destination)
                                    }
                                    .contextMenu {
                                        focusContextMenu(for: candidate)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Focus")
        .alert("Focus Update Failed", isPresented: mutationErrorBinding) {
            Button("OK", role: .cancel) {
                mutationError = nil
            }
        } message: {
            Text(mutationError ?? "Unknown error")
        }
        .alert("Delete Permanently?", isPresented: pendingDeletionBinding) {
            Button("Delete", role: .destructive, action: deletePendingItem)
            Button("Cancel", role: .cancel) {
                pendingDeletionReference = nil
                pendingInboxDeletionID = nil
            }
        } message: {
            Text("Deleting \(pendingDeletionItemTitle) also removes linked dependencies or returns converted inbox references to reviewing where relevant.")
        }
    }

    @ViewBuilder
    private func focusContextMenu(for candidate: FocusCandidate) -> some View {
        Button("Open") {
            navigation.openDestination(candidate.destination)
        }

        switch candidate.destination {
        case .project(let projectID):
            if let project = project(for: projectID) {
                ForEach(ProjectStatus.allCases) { status in
                    Button("Mark \(status.title)") {
                        project.setStatus(status)
                        persistContext()
                    }
                }

                Divider()

                Button("Raise Priority") {
                    PlanningMutationWorkflow.nudgePriority(for: project, by: 1)
                    persistContext()
                }

                Button("Lower Priority") {
                    PlanningMutationWorkflow.nudgePriority(for: project, by: -1)
                    persistContext()
                }

                Divider()

                Button("Schedule Today") {
                    PlanningMutationWorkflow.scheduleProjectFromToday(project)
                    persistContext()
                }

                Button("Push Back 1 Week") {
                    PlanningMutationWorkflow.shiftSchedule(project, byDays: 7)
                    persistContext()
                }

                if project.isArchived {
                    Button("Restore Project") {
                        project.restoreFromArchive()
                        persistContext()
                    }
                } else {
                    Button("Archive Project") {
                        project.archive()
                        persistContext()
                    }
                }

                Button("Delete Permanently", role: .destructive) {
                    pendingDeletionReference = PlanningItemReference(kind: .project, id: project.id)
                }
            }

        case .step(_, let stepID):
            if let step = step(for: stepID) {
                ForEach(ProjectStatus.allCases) { status in
                    Button("Mark \(status.title)") {
                        step.setStatus(status)
                        persistContext()
                    }
                }

                Divider()

                Button("Raise Priority") {
                    PlanningMutationWorkflow.nudgePriority(for: step, by: 1)
                    persistContext()
                }

                Button("Lower Priority") {
                    PlanningMutationWorkflow.nudgePriority(for: step, by: -1)
                    persistContext()
                }

                Divider()

                Button("Schedule Today") {
                    PlanningMutationWorkflow.scheduleStepFromToday(step)
                    persistContext()
                }

                Button("Push Back 1 Week") {
                    PlanningMutationWorkflow.shiftSchedule(step, byDays: 7)
                    persistContext()
                }

                Button("Delete Permanently", role: .destructive) {
                    pendingDeletionReference = PlanningItemReference(kind: .step, id: step.id)
                }
            }

        case .inbox(let itemID):
            if let item = inboxItem(for: itemID) {
                if item.state == .open {
                    Button("Start Review") {
                        item.markReviewing()
                        persistContext()
                    }
                }

                if item.state == .archived {
                    Button("Return to Triage") {
                        item.reopen()
                        persistContext()
                    }
                } else {
                    Button("Archive") {
                        item.archive()
                        persistContext()
                    }
                }

                Button("Delete Permanently", role: .destructive) {
                    pendingInboxDeletionID = item.id
                }
            }
        }
    }

    private var mutationErrorBinding: Binding<Bool> {
        Binding(
            get: { mutationError != nil },
            set: { isPresented in
                if !isPresented {
                    mutationError = nil
                }
            }
        )
    }

    private var pendingDeletionBinding: Binding<Bool> {
        Binding(
            get: { pendingDeletionReference != nil || pendingInboxDeletionID != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeletionReference = nil
                    pendingInboxDeletionID = nil
                }
            }
        )
    }

    private func deletePendingItem() {
        do {
            if let pendingInboxDeletionID, let item = inboxItem(for: pendingInboxDeletionID) {
                PlanningMutationWorkflow.deleteInboxItem(item, in: modelContext)
            } else if let pendingDeletionReference {
                switch pendingDeletionReference.kind {
                case .project:
                    if let project = project(for: pendingDeletionReference.id) {
                        try PlanningMutationWorkflow.deleteProject(project, in: modelContext)
                    }
                case .step:
                    if let step = step(for: pendingDeletionReference.id) {
                        try PlanningMutationWorkflow.deleteStep(step, in: modelContext)
                    }
                }
            }

            pendingDeletionReference = nil
            pendingInboxDeletionID = nil
            try modelContext.saveIfNeeded()
        } catch {
            mutationError = error.localizedDescription
        }
    }

    private func persistContext() {
        do {
            try modelContext.saveIfNeeded()
        } catch {
            mutationError = error.localizedDescription
        }
    }

    private func project(for id: UUID) -> Project? {
        projects.first { $0.id == id }
    }

    private func step(for id: UUID) -> ProjectStep? {
        projects.flatMap(\.steps).first { $0.id == id }
    }

    private func inboxItem(for id: UUID) -> IdeaInboxItem? {
        inboxItems.first { $0.id == id }
    }

    private func emptyStateIcon(for kind: FocusSectionKind) -> String {
        switch kind {
        case .nowImportant:
            "scope"
        case .blocked:
            "checkmark.circle"
        case .nextSteps:
            "point.bottomleft.forward.to.point.topright.scurvepath"
        case .inbox:
            "tray"
        case .milestones:
            "calendar.badge.clock"
        }
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
    .modelContainer(PreviewContainer.shared)
}
