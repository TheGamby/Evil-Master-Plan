import SwiftUI
import SwiftData

struct GanttView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigationModel.self) private var navigation
    @Query private var projects: [Project]
    @Query private var dependencies: [Dependency]
    @Query private var preferences: [VisualizationPreferences]
    @State private var selectedEntryID: UUID?
    @State private var showsOnlyBlockedItems = false
    @State private var showsArchivedProjects = false
    @State private var mutationError: String?
    @State private var pendingDeletionReference: PlanningItemReference?

    var body: some View {
        GeometryReader { proxy in
            let isWideLayout = proxy.size.width > 1220
            let snapshot = makeSnapshot()
            let geometry = TimelineGeometry(scale: currentPreferences?.timelineScale ?? .week)
            let selectedInspector = snapshot.inspector(for: selectedEntryID)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    GanttControlsPanel(
                        summary: snapshot.summary,
                        timelineScale: timelineScaleBinding,
                        showCompletedItems: showCompletedItemsBinding,
                        showHighPriorityOnly: highPriorityOnlyBinding,
                        showsOnlyBlockedItems: $showsOnlyBlockedItems,
                        showsArchivedProjects: $showsArchivedProjects
                    )

                    if isWideLayout {
                        HStack(alignment: .top, spacing: 20) {
                            GanttTimelinePanel(
                                snapshot: snapshot,
                                geometry: geometry,
                                selectedEntryID: $selectedEntryID
                            )
                            .frame(maxWidth: .infinity)

                            PlanningInspectorView(
                                inspector: selectedInspector,
                                openProjectsAction: openInProjects,
                                setStatusAction: setStatus,
                                setPriorityAction: setPriority,
                                scheduleTodayAction: scheduleToday,
                                shiftScheduleAction: shiftSchedule,
                                clearScheduleAction: clearSchedule,
                                archiveProjectAction: archiveProject,
                                restoreProjectAction: restoreProject,
                                deleteEntryAction: requestDelete,
                                removeDependencyAction: removeDependency,
                                isProjectArchived: isProjectArchived
                            )
                            .frame(width: 340)
                        }
                    } else {
                        GanttTimelinePanel(
                            snapshot: snapshot,
                            geometry: geometry,
                            selectedEntryID: $selectedEntryID
                        )

                        PlanningInspectorView(
                            inspector: selectedInspector,
                            openProjectsAction: openInProjects,
                            setStatusAction: setStatus,
                            setPriorityAction: setPriority,
                            scheduleTodayAction: scheduleToday,
                            shiftScheduleAction: shiftSchedule,
                            clearScheduleAction: clearSchedule,
                            archiveProjectAction: archiveProject,
                            restoreProjectAction: restoreProject,
                            deleteEntryAction: requestDelete,
                            removeDependencyAction: removeDependency,
                            isProjectArchived: isProjectArchived
                        )
                    }
                }
                .padding(24)
            }
            .onAppear {
                syncSelection(with: snapshot)
            }
            .onChange(of: snapshot.entries.map(\.id)) { _, _ in
                syncSelection(with: snapshot)
            }
        }
        .navigationTitle("Gantt")
        .alert("Timeline Update Failed", isPresented: mutationErrorBinding) {
            Button("OK", role: .cancel) {
                mutationError = nil
            }
        } message: {
            Text(mutationError ?? "Unknown error")
        }
        .alert("Delete Permanently?", isPresented: pendingDeletionBinding) {
            Button("Delete", role: .destructive, action: deleteRequestedEntry)
            Button("Cancel", role: .cancel) {
                pendingDeletionReference = nil
            }
        } message: {
            Text("Deleting this item also removes linked dependencies. If it came from Inbox conversion, the inbox item returns to reviewing.")
        }
    }

    private var currentPreferences: VisualizationPreferences? {
        preferences.first
    }

    private func makeSnapshot() -> PlanningTimelineSnapshot {
        PlanningTimelineBuilder.snapshot(
            projects: projects,
            dependencies: dependencies,
            filter: PlanningFilterState(
                showsCompletedItems: currentPreferences?.showsCompletedItems ?? true,
                showsOnlyHighPriorityProjects: currentPreferences?.showsOnlyHighPriorityProjects ?? false,
                showsOnlyBlockedItems: showsOnlyBlockedItems,
                showsOnlyLinkedItems: false,
                showsArchivedProjects: showsArchivedProjects
            ),
            scale: currentPreferences?.timelineScale ?? .week,
            projectSortCriterion: currentPreferences?.projectSortCriterion ?? .updatedAt
        )
    }

    private func syncSelection(with snapshot: PlanningTimelineSnapshot) {
        if let selectedEntryID, snapshot.entries.contains(where: { $0.id == selectedEntryID }) {
            return
        }

        selectedEntryID = snapshot.entries.first(where: { $0.kind == .project && $0.isBlocked })?.id
            ?? snapshot.entries.first(where: { $0.kind == .milestone && $0.status.isOpen })?.id
            ?? snapshot.entries.first?.id
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
            get: { pendingDeletionReference != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeletionReference = nil
                }
            }
        )
    }

    private var timelineScaleBinding: Binding<TimelineScale> {
        Binding(
            get: { currentPreferences?.timelineScale ?? .week },
            set: { currentPreferences?.timelineScale = $0 }
        )
    }

    private var showCompletedItemsBinding: Binding<Bool> {
        Binding(
            get: { currentPreferences?.showsCompletedItems ?? true },
            set: { currentPreferences?.showsCompletedItems = $0 }
        )
    }

    private var highPriorityOnlyBinding: Binding<Bool> {
        Binding(
            get: { currentPreferences?.showsOnlyHighPriorityProjects ?? false },
            set: { currentPreferences?.showsOnlyHighPriorityProjects = $0 }
        )
    }

    private func openInProjects(_ inspector: PlanningInspectorContext) {
        switch inspector.sourceReference.kind {
        case .project:
            navigation.openProject(inspector.projectID)
        case .step:
            navigation.openProject(inspector.projectID, stepID: inspector.entryID)
        }
    }

    private func setStatus(_ inspector: PlanningInspectorContext, _ status: ProjectStatus) {
        switch inspector.sourceReference.kind {
        case .project:
            project(for: inspector.projectID)?.setStatus(status)
        case .step:
            step(for: inspector.entryID)?.setStatus(status)
        }
        persistContext()
    }

    private func setPriority(_ inspector: PlanningInspectorContext, _ priority: PriorityLevel) {
        switch inspector.sourceReference.kind {
        case .project:
            project(for: inspector.projectID)?.setPriority(priority)
        case .step:
            step(for: inspector.entryID)?.setPriority(priority)
        }
        persistContext()
    }

    private func scheduleToday(_ inspector: PlanningInspectorContext) {
        switch inspector.sourceReference.kind {
        case .project:
            if let project = project(for: inspector.projectID) {
                PlanningMutationWorkflow.scheduleProjectFromToday(project)
            }
        case .step:
            if let step = step(for: inspector.entryID) {
                PlanningMutationWorkflow.scheduleStepFromToday(step)
            }
        }
        persistContext()
    }

    private func shiftSchedule(_ inspector: PlanningInspectorContext, _ dayOffset: Int) {
        switch inspector.sourceReference.kind {
        case .project:
            if let project = project(for: inspector.projectID) {
                PlanningMutationWorkflow.shiftSchedule(project, byDays: dayOffset)
            }
        case .step:
            if let step = step(for: inspector.entryID) {
                PlanningMutationWorkflow.shiftSchedule(step, byDays: dayOffset)
            }
        }
        persistContext()
    }

    private func clearSchedule(_ inspector: PlanningInspectorContext) {
        switch inspector.sourceReference.kind {
        case .project:
            if let project = project(for: inspector.projectID) {
                PlanningMutationWorkflow.clearSchedule(project)
            }
        case .step:
            if let step = step(for: inspector.entryID) {
                PlanningMutationWorkflow.clearSchedule(step)
            }
        }
        persistContext()
    }

    private func archiveProject(_ inspector: PlanningInspectorContext) {
        project(for: inspector.projectID)?.archive()
        persistContext()
    }

    private func restoreProject(_ inspector: PlanningInspectorContext) {
        project(for: inspector.projectID)?.restoreFromArchive()
        showsArchivedProjects = true
        persistContext()
    }

    private func requestDelete(_ inspector: PlanningInspectorContext) {
        pendingDeletionReference = inspector.sourceReference
    }

    private func deleteRequestedEntry() {
        guard let reference = pendingDeletionReference else {
            return
        }

        do {
            switch reference.kind {
            case .project:
                if let project = project(for: reference.id) {
                    try PlanningMutationWorkflow.deleteProject(project, in: modelContext)
                }
            case .step:
                if let step = step(for: reference.id) {
                    try PlanningMutationWorkflow.deleteStep(step, in: modelContext)
                }
            }

            pendingDeletionReference = nil
            selectedEntryID = nil
            try modelContext.saveIfNeeded()
        } catch {
            mutationError = error.localizedDescription
        }
    }

    private func removeDependency(_ dependency: PlanningInspectorDependency) {
        guard let storedDependency = dependencies.first(where: { $0.id == dependency.id }) else {
            return
        }

        do {
            try PlanningMutationWorkflow.deleteDependency(storedDependency, in: modelContext)
            try modelContext.saveIfNeeded()
        } catch {
            mutationError = error.localizedDescription
        }
    }

    private func isProjectArchived(_ inspector: PlanningInspectorContext) -> Bool {
        project(for: inspector.projectID)?.isArchived == true
    }

    private func project(for id: UUID) -> Project? {
        projects.first { $0.id == id }
    }

    private func step(for id: UUID) -> ProjectStep? {
        projects
            .flatMap(\.steps)
            .first { $0.id == id }
    }

    private func persistContext() {
        do {
            try modelContext.saveIfNeeded()
        } catch {
            mutationError = error.localizedDescription
        }
    }
}

private struct GanttControlsPanel: View {
    @Environment(\.appTheme) private var theme
    let summary: PlanningTimelineSummary
    let timelineScale: Binding<TimelineScale>
    let showCompletedItems: Binding<Bool>
    let showHighPriorityOnly: Binding<Bool>
    @Binding var showsOnlyBlockedItems: Bool
    @Binding var showsArchivedProjects: Bool

    var body: some View {
        PanelCard(
            title: "Timeline Planning Surface",
            subtitle: "Projects are containers, steps are planable units, milestones are step-based markers, and dependencies drive blocker visibility."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    MetricCard(
                        title: "Projects",
                        value: "\(summary.visibleProjectCount)",
                        systemImage: "square.stack.3d.up.fill",
                        tint: theme.projectColor(.cobalt)
                    )
                    MetricCard(
                        title: "Visible Items",
                        value: "\(summary.visibleEntryCount)",
                        systemImage: "calendar",
                        tint: theme.accent
                    )
                    MetricCard(
                        title: "Blocked Items",
                        value: "\(summary.blockedEntryCount)",
                        systemImage: "exclamationmark.triangle.fill",
                        tint: theme.statusColor(.blocked)
                    )
                    MetricCard(
                        title: "Derived Dates",
                        value: "\(summary.derivedScheduleCount)",
                        systemImage: "wand.and.stars",
                        tint: theme.priorityColor(.medium)
                    )
                }

                HStack(spacing: 14) {
                    Picker("Scale", selection: timelineScale) {
                        ForEach(TimelineScale.allCases) { scale in
                            Text(scale.title).tag(scale)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Show completed", isOn: showCompletedItems)
                    Toggle("High-priority only", isOn: showHighPriorityOnly)
                    Toggle("Blocked only", isOn: $showsOnlyBlockedItems)
                    Toggle("Show archived", isOn: $showsArchivedProjects)
                }
            }
        }
    }
}

private struct GanttTimelinePanel: View {
    @Environment(\.appTheme) private var theme
    let snapshot: PlanningTimelineSnapshot
    let geometry: TimelineGeometry
    @Binding var selectedEntryID: UUID?

    var body: some View {
        PanelCard(
            title: "Project Timeline",
            subtitle: "Bars and milestones come from shared planning entries. Estimated items are explicitly marked instead of pretending to be fully scheduled."
        ) {
            if snapshot.entries.isEmpty {
                EmptyStateView(
                    title: "No Timeline Items Match The Current Filters",
                    message: "Adjust the planning filters or add dated steps and milestones to bring the schedule back into view.",
                    systemImage: "calendar.badge.exclamationmark"
                )
            } else {
                ScrollView([.horizontal, .vertical]) {
                    VStack(spacing: 0) {
                        PlanningTimelineHeaderView(snapshot: snapshot, geometry: geometry)
                        Divider().overlay(theme.subtleStroke)

                        ForEach(snapshot.entries) { entry in
                            PlanningTimelineRowView(
                                entry: entry,
                                snapshot: snapshot,
                                geometry: geometry,
                                isSelected: selectedEntryID == entry.id
                            )
                            .onTapGesture {
                                selectedEntryID = entry.id
                            }

                            Divider().overlay(theme.subtleStroke.opacity(0.8))
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        GanttView()
    }
    .modelContainer(PreviewContainer.shared)
}
