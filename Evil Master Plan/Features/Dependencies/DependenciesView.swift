import SwiftUI
import SwiftData

struct DependenciesView: View {
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
            let isWideLayout = proxy.size.width > 1240
            let snapshot = makeSnapshot()
            let geometry = TimelineGeometry(scale: currentPreferences?.timelineScale ?? .week)
            let selectedInspector = snapshot.inspector(for: selectedEntryID)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    DependencyControlsPanel(
                        summary: snapshot.summary,
                        timelineScale: timelineScaleBinding,
                        showCompletedItems: showCompletedItemsBinding,
                        showHighPriorityOnly: highPriorityOnlyBinding,
                        showsOnlyBlockedItems: $showsOnlyBlockedItems,
                        showsArchivedProjects: $showsArchivedProjects
                    )

                    if isWideLayout {
                        HStack(alignment: .top, spacing: 20) {
                            DependencyTimelinePanel(
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
                        DependencyTimelinePanel(
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
        .navigationTitle("Dependencies")
        .alert("Dependency Update Failed", isPresented: mutationErrorBinding) {
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
            Text("Deleting this item also removes linked dependencies. Converted inbox targets pointing here go back to reviewing.")
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
                showsOnlyLinkedItems: true,
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

        selectedEntryID = snapshot.entries.first(where: \.hasIncompletePredecessors)?.id
            ?? snapshot.entries.first(where: { $0.predecessorCount > 0 || $0.successorCount > 0 })?.id
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

private struct DependencyControlsPanel: View {
    @Environment(\.appTheme) private var theme
    let summary: PlanningTimelineSummary
    let timelineScale: Binding<TimelineScale>
    let showCompletedItems: Binding<Bool>
    let showHighPriorityOnly: Binding<Bool>
    @Binding var showsOnlyBlockedItems: Bool
    @Binding var showsArchivedProjects: Bool

    var body: some View {
        PanelCard(
            title: "Dependency Timeline",
            subtitle: "This view uses the same planning entries as Gantt, but filters to linked items and emphasizes open predecessor chains."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    MetricCard(
                        title: "Linked Items",
                        value: "\(summary.visibleEntryCount)",
                        systemImage: "arrow.triangle.branch",
                        tint: theme.accent
                    )
                    MetricCard(
                        title: "Visible Links",
                        value: "\(summary.visibleDependencyCount)",
                        systemImage: "point.3.connected.trianglepath.dotted",
                        tint: theme.projectColor(.cobalt)
                    )
                    MetricCard(
                        title: "Blocked Items",
                        value: "\(summary.blockedEntryCount)",
                        systemImage: "hand.raised.fill",
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

private struct DependencyTimelinePanel: View {
    @Environment(\.appTheme) private var theme
    let snapshot: PlanningTimelineSnapshot
    let geometry: TimelineGeometry
    @Binding var selectedEntryID: UUID?

    var body: some View {
        PanelCard(
            title: "Arrow Timeline",
            subtitle: "Every path is a stored dependency between shared planning items. Red lines mark open predecessors; muted lines are already satisfied."
        ) {
            if snapshot.entries.isEmpty {
                EmptyStateView(
                    title: "No Dependency Chains To Show",
                    message: "Create dependencies between projects or steps to make sequence and blocker paths visible here.",
                    systemImage: "arrow.triangle.swap"
                )
            } else {
                ScrollView([.horizontal, .vertical]) {
                    ZStack(alignment: .topLeading) {
                        DependencyEdgesOverlay(snapshot: snapshot, geometry: geometry)

                        VStack(spacing: 0) {
                            PlanningTimelineHeaderView(snapshot: snapshot, geometry: geometry)
                            Divider().overlay(theme.subtleStroke)

                            ForEach(snapshot.entries) { entry in
                                PlanningTimelineRowView(
                                    entry: entry,
                                    snapshot: snapshot,
                                    geometry: geometry,
                                    isSelected: selectedEntryID == entry.id,
                                    showsDependencySignals: true
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
}

private struct DependencyEdgesOverlay: View {
    @Environment(\.appTheme) private var theme
    let snapshot: PlanningTimelineSnapshot
    let geometry: TimelineGeometry

    var body: some View {
        Canvas { context, _ in
            let rowIndex = Dictionary(uniqueKeysWithValues: snapshot.entries.enumerated().map { ($1.id, $0) })

            for edge in snapshot.edges {
                guard
                    let sourceIndex = rowIndex[edge.sourceEntryID],
                    let targetIndex = rowIndex[edge.targetEntryID],
                    let sourceEntry = snapshot.entries.first(where: { $0.id == edge.sourceEntryID }),
                    let targetEntry = snapshot.entries.first(where: { $0.id == edge.targetEntryID })
                else {
                    continue
                }

                let sourcePoint = CGPoint(
                    x: geometry.labelWidth + geometry.offset(for: sourceEntry.endDate, from: snapshot.timelineStart) + geometry.width(for: sourceEntry.startDate, end: sourceEntry.endDate, kind: sourceEntry.kind),
                    y: 48 + CGFloat(sourceIndex) * geometry.rowHeight + (geometry.rowHeight / 2)
                )

                let targetPoint = CGPoint(
                    x: geometry.labelWidth + geometry.offset(for: targetEntry.startDate, from: snapshot.timelineStart),
                    y: 48 + CGFloat(targetIndex) * geometry.rowHeight + (geometry.rowHeight / 2)
                )

                let midpointX = max(sourcePoint.x + 20, (sourcePoint.x + targetPoint.x) / 2)
                var path = Path()
                path.move(to: sourcePoint)
                path.addLine(to: CGPoint(x: midpointX, y: sourcePoint.y))
                path.addLine(to: CGPoint(x: midpointX, y: targetPoint.y))
                path.addLine(to: targetPoint)

                let color = edge.isBlocking ? theme.statusColor(.blocked) : theme.accent.opacity(0.45)
                let strokeStyle = StrokeStyle(
                    lineWidth: edge.isBlocking ? 2.5 : 1.6,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: edge.isBlocking ? [] : [6, 6]
                )

                context.stroke(path, with: .color(color), style: strokeStyle)

                var arrow = Path()
                arrow.move(to: targetPoint)
                arrow.addLine(to: CGPoint(x: targetPoint.x - 8, y: targetPoint.y - 5))
                arrow.move(to: targetPoint)
                arrow.addLine(to: CGPoint(x: targetPoint.x - 8, y: targetPoint.y + 5))
                context.stroke(arrow, with: .color(color), style: StrokeStyle(lineWidth: edge.isBlocking ? 2.2 : 1.4, lineCap: .round))
            }
        }
        .frame(
            width: geometry.labelWidth + geometry.trackWidth(for: snapshot),
            height: 48 + CGFloat(snapshot.entries.count) * geometry.rowHeight
        )
        .allowsHitTesting(false)
    }
}

#Preview {
    NavigationStack {
        DependenciesView()
    }
    .modelContainer(PreviewContainer.shared)
}
