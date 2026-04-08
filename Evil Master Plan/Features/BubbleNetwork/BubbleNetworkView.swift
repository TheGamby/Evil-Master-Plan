import SwiftUI
import SwiftData

struct BubbleNetworkView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigationModel.self) private var navigation
    @Query private var projects: [Project]
    @Query private var dependencies: [Dependency]
    @Query private var preferences: [VisualizationPreferences]
    @State private var primaryFilter: BubblePrimaryFilter = .all
    @State private var selectedNodeID: UUID?
    @State private var focusedProjectID: UUID?
    @State private var showsArchivedProjects = false
    @State private var mutationError: String?
    @State private var pendingDeletionReference: PlanningItemReference?

    var body: some View {
        GeometryReader { proxy in
            let isWideLayout = proxy.size.width > 1180
            let inspectorWidth: CGFloat = isWideLayout ? 340 : proxy.size.width - 48
            let scene = makeScene(for: proxy.size.width, inspectorWidth: inspectorWidth, isWideLayout: isWideLayout)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    controlsPanel(summary: scene.summary)

                    if isWideLayout {
                        HStack(alignment: .top, spacing: 20) {
                            canvasPanel(scene: scene, height: max(proxy.size.height - 140, 520))
                                .frame(maxWidth: .infinity)

                            BubbleInspectorView(
                                inspector: scene.inspector,
                                focusedProjectID: focusedProjectID,
                                focusAction: toggleFocus,
                                clearSelectionAction: { selectedNodeID = nil },
                                openProjectsAction: openInProjects,
                                setStatusAction: setStatus,
                                setPriorityAction: setPriority,
                                scheduleTodayAction: scheduleToday,
                                shiftScheduleAction: shiftSchedule,
                                clearScheduleAction: clearSchedule,
                                archiveProjectAction: archiveProject,
                                restoreProjectAction: restoreProject,
                                deleteSelectionAction: requestDelete,
                                isProjectArchived: isProjectArchived
                            )
                            .frame(width: inspectorWidth)
                        }
                    } else {
                        canvasPanel(scene: scene, height: max(proxy.size.height * 0.62, 460))

                        BubbleInspectorView(
                            inspector: scene.inspector,
                            focusedProjectID: focusedProjectID,
                            focusAction: toggleFocus,
                            clearSelectionAction: { selectedNodeID = nil },
                            openProjectsAction: openInProjects,
                            setStatusAction: setStatus,
                            setPriorityAction: setPriority,
                            scheduleTodayAction: scheduleToday,
                            shiftScheduleAction: shiftSchedule,
                            clearScheduleAction: clearSchedule,
                            archiveProjectAction: archiveProject,
                            restoreProjectAction: restoreProject,
                            deleteSelectionAction: requestDelete,
                            isProjectArchived: isProjectArchived
                        )
                    }
                }
                .padding(24)
            }
            .onAppear {
                syncSelection(with: scene)
            }
            .onChange(of: scene.graph.nodes.map(\.id)) { _, _ in
                syncSelection(with: scene)
            }
        }
        .navigationTitle("Bubble Network")
        .alert("Bubble Update Failed", isPresented: mutationErrorBinding) {
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
            Text("Deleting this selection also removes linked dependencies. Converted inbox targets pointing here go back to reviewing.")
        }
    }

    private var currentPreferences: VisualizationPreferences? {
        preferences.first
    }

    private func controlsPanel(summary: BubbleGraphSummary) -> some View {
        PanelCard(
            title: "Bubble Command Surface",
            subtitle: "Projects stay visible as the primary map. Focus expands one project into steps and milestones without exploding the whole network."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    MetricCard(
                        title: "Visible Projects",
                        value: "\(summary.visibleProjectCount)",
                        systemImage: "circle.grid.2x2.fill",
                        tint: theme.projectColor(.cobalt)
                    )
                    MetricCard(
                        title: "Blocked",
                        value: "\(summary.blockedProjectCount)",
                        systemImage: "exclamationmark.triangle.fill",
                        tint: theme.statusColor(.blocked)
                    )
                    MetricCard(
                        title: "Visible Links",
                        value: "\(summary.visibleConnectionCount)",
                        systemImage: "arrow.triangle.branch",
                        tint: theme.accent
                    )
                    MetricCard(
                        title: "Focused Steps",
                        value: "\(summary.focusedStepCount)",
                        systemImage: "flag.2.crossed.fill",
                        tint: theme.projectColor(.lime)
                    )
                }

                HStack(spacing: 14) {
                    Picker("Bubble Size", selection: bubbleSizingBinding) {
                        ForEach(BubbleSizingCriterion.allCases) { criterion in
                            Text(criterion.title).tag(criterion)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Grouping", selection: bubbleGroupingBinding) {
                        ForEach(BubbleGroupingMode.allCases) { grouping in
                            Text(grouping.title).tag(grouping)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Scope", selection: $primaryFilter) {
                        ForEach(BubblePrimaryFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                HStack(spacing: 16) {
                    Toggle("High-priority only", isOn: highPriorityOnlyBinding)
                    Toggle("Hide completed", isOn: hideCompletedBinding)
                    Toggle("Show archived", isOn: $showsArchivedProjects)
                }

                if let focusedProjectID, let focusedProject = projects.first(where: { $0.id == focusedProjectID }) {
                    HStack {
                        Label("Focused on \(focusedProject.title)", systemImage: "scope")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.accent)
                        Spacer()
                        Button("Release Focus") {
                            self.focusedProjectID = nil
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private func canvasPanel(scene: BubbleNetworkScene, height: CGFloat) -> some View {
        PanelCard(
            title: "Graph View",
            subtitle: "Bubble size is tied to real project metrics. Edges only render stored dependencies. Selection highlights context instead of generating a fake subnetwork."
        ) {
            if scene.graph.nodes.isEmpty {
                EmptyStateView(
                    title: "No Bubbles Match The Current Filters",
                    message: "Widen the filter scope or add active projects to bring the network back into view.",
                    systemImage: "circle.dotted.circle"
                )
            } else {
                BubbleGraphCanvasView(graph: scene.graph) { nodeID in
                    selectedNodeID = nodeID
                    if
                        let node = scene.graph.nodes.first(where: { $0.id == nodeID }),
                        node.kind != .project,
                        let projectID = node.clusterParentID
                    {
                        focusedProjectID = projectID
                    }
                }
                .frame(height: height)
            }
        }
    }

    private func makeScene(for totalWidth: CGFloat, inspectorWidth: CGFloat, isWideLayout: Bool) -> BubbleNetworkScene {
        BubbleGraphBuilder.scene(
            projects: projects,
            dependencies: dependencies,
            sizing: currentPreferences?.bubbleSizingCriterion ?? .priority,
            grouping: currentPreferences?.bubbleGroupingMode ?? .status,
            filter: BubbleFilterState(
                primaryFilter: primaryFilter,
                hidesCompletedProjects: !(currentPreferences?.showsCompletedItems ?? true),
                showsOnlyHighPriorityProjects: currentPreferences?.showsOnlyHighPriorityProjects ?? false,
                showsArchivedProjects: showsArchivedProjects
            ),
            focusedProjectID: focusedProjectID,
            selectedNodeID: selectedNodeID,
            viewportWidth: isWideLayout ? max(totalWidth - inspectorWidth - 88, 720) : max(totalWidth - 48, 720)
        )
    }

    private func toggleFocus(projectID: UUID) {
        focusedProjectID = focusedProjectID == projectID ? nil : projectID
        if selectedNodeID == nil {
            selectedNodeID = projectID
        }
    }

    private func syncSelection(with scene: BubbleNetworkScene) {
        if let focusedProjectID, !scene.graph.nodes.contains(where: { $0.id == focusedProjectID }) {
            self.focusedProjectID = nil
        }

        if let selectedNodeID, scene.graph.nodes.contains(where: { $0.id == selectedNodeID }) {
            return
        }

        selectedNodeID = scene.graph.nodes.first(where: { $0.kind == .project && $0.isBlocked })?.id
            ?? scene.graph.nodes.first(where: { $0.kind == .project && $0.priority.isHighPriority })?.id
            ?? scene.graph.nodes.first(where: { $0.kind == .project })?.id
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

    private var bubbleSizingBinding: Binding<BubbleSizingCriterion> {
        Binding(
            get: { currentPreferences?.bubbleSizingCriterion ?? .priority },
            set: { currentPreferences?.bubbleSizingCriterion = $0 }
        )
    }

    private var bubbleGroupingBinding: Binding<BubbleGroupingMode> {
        Binding(
            get: { currentPreferences?.bubbleGroupingMode ?? .status },
            set: { currentPreferences?.bubbleGroupingMode = $0 }
        )
    }

    private var highPriorityOnlyBinding: Binding<Bool> {
        Binding(
            get: { currentPreferences?.showsOnlyHighPriorityProjects ?? false },
            set: { currentPreferences?.showsOnlyHighPriorityProjects = $0 }
        )
    }

    private var hideCompletedBinding: Binding<Bool> {
        Binding(
            get: { !(currentPreferences?.showsCompletedItems ?? true) },
            set: { currentPreferences?.showsCompletedItems = !$0 }
        )
    }

    private func openInProjects(_ inspector: BubbleInspectorContext) {
        switch inspector.sourceReference.kind {
        case .project:
            navigation.openProject(inspector.projectID)
        case .step:
            navigation.openProject(inspector.projectID, stepID: inspector.nodeID)
        }
    }

    private func setStatus(_ inspector: BubbleInspectorContext, _ status: ProjectStatus) {
        switch inspector.sourceReference.kind {
        case .project:
            project(for: inspector.projectID)?.setStatus(status)
        case .step:
            step(for: inspector.nodeID)?.setStatus(status)
        }
        persistContext()
    }

    private func setPriority(_ inspector: BubbleInspectorContext, _ priority: PriorityLevel) {
        switch inspector.sourceReference.kind {
        case .project:
            project(for: inspector.projectID)?.setPriority(priority)
        case .step:
            step(for: inspector.nodeID)?.setPriority(priority)
        }
        persistContext()
    }

    private func scheduleToday(_ inspector: BubbleInspectorContext) {
        switch inspector.sourceReference.kind {
        case .project:
            if let project = project(for: inspector.projectID) {
                PlanningMutationWorkflow.scheduleProjectFromToday(project)
            }
        case .step:
            if let step = step(for: inspector.nodeID) {
                PlanningMutationWorkflow.scheduleStepFromToday(step)
            }
        }
        persistContext()
    }

    private func shiftSchedule(_ inspector: BubbleInspectorContext, _ dayOffset: Int) {
        switch inspector.sourceReference.kind {
        case .project:
            if let project = project(for: inspector.projectID) {
                PlanningMutationWorkflow.shiftSchedule(project, byDays: dayOffset)
            }
        case .step:
            if let step = step(for: inspector.nodeID) {
                PlanningMutationWorkflow.shiftSchedule(step, byDays: dayOffset)
            }
        }
        persistContext()
    }

    private func clearSchedule(_ inspector: BubbleInspectorContext) {
        switch inspector.sourceReference.kind {
        case .project:
            if let project = project(for: inspector.projectID) {
                PlanningMutationWorkflow.clearSchedule(project)
            }
        case .step:
            if let step = step(for: inspector.nodeID) {
                PlanningMutationWorkflow.clearSchedule(step)
            }
        }
        persistContext()
    }

    private func archiveProject(_ inspector: BubbleInspectorContext) {
        project(for: inspector.projectID)?.archive()
        persistContext()
    }

    private func restoreProject(_ inspector: BubbleInspectorContext) {
        project(for: inspector.projectID)?.restoreFromArchive()
        showsArchivedProjects = true
        persistContext()
    }

    private func requestDelete(_ inspector: BubbleInspectorContext) {
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
            selectedNodeID = nil
            try modelContext.saveIfNeeded()
        } catch {
            mutationError = error.localizedDescription
        }
    }

    private func isProjectArchived(_ inspector: BubbleInspectorContext) -> Bool {
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

#Preview {
    NavigationStack {
        BubbleNetworkView()
    }
    .modelContainer(PreviewContainer.shared)
}
