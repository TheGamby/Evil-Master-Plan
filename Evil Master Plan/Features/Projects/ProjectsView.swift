import SwiftUI
import SwiftData

private enum ProjectListScope: String, CaseIterable, Identifiable {
    case active
    case archived
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active:
            "Active"
        case .archived:
            "Archived"
        case .all:
            "All"
        }
    }
}

struct ProjectsView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigationModel.self) private var navigation
    @Query private var projects: [Project]
    @Query private var preferences: [VisualizationPreferences]
    @State private var listScope: ProjectListScope = .active
    @State private var selectedProjectID: UUID?
    @State private var isEditingSelectedProject = false
    @State private var mutationError: String?
    @State private var pendingDeletionProjectID: UUID?

    private var currentPreferences: VisualizationPreferences? {
        preferences.first
    }

    private var visibleProjects: [Project] {
        let scopedProjects = projects.filter { project in
            switch listScope {
            case .active:
                !project.isArchived
            case .archived:
                project.isArchived
            case .all:
                true
            }
        }

        let sourceProjects: [Project]
        if currentPreferences?.showsOnlyHighPriorityProjects == true {
            sourceProjects = scopedProjects.filter(\.isHighPriority)
        } else {
            sourceProjects = scopedProjects
        }

        let criterion = currentPreferences?.projectSortCriterion ?? .updatedAt

        switch criterion {
        case .updatedAt:
            return sourceProjects.sorted { $0.updatedAt > $1.updatedAt }
        case .priority:
            return sourceProjects.sorted { $0.priority > $1.priority }
        case .dueDate:
            return sourceProjects.sorted { ($0.resolvedDueDate ?? .distantFuture) < ($1.resolvedDueDate ?? .distantFuture) }
        case .progress:
            return sourceProjects.sorted { $0.progress > $1.progress }
        }
    }

    private var selectedProject: Project? {
        guard let selectedProjectID else {
            return visibleProjects.first
        }

        return visibleProjects.first { $0.id == selectedProjectID } ?? visibleProjects.first
    }

    private var pendingDeletionProject: Project? {
        guard let pendingDeletionProjectID else {
            return nil
        }

        return projects.first { $0.id == pendingDeletionProjectID }
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                if proxy.size.width > 920 {
                    HStack(alignment: .top, spacing: 20) {
                        projectListPanel
                            .frame(maxWidth: 360)
                        projectDetailPanel
                    }
                    .padding(24)
                } else {
                    VStack(alignment: .leading, spacing: 20) {
                        projectListPanel
                        projectDetailPanel
                    }
                    .padding(24)
                }
            }
        }
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem {
                Button(action: addProject) {
                    Label("New Project", systemImage: "plus")
                }
            }
        }
        .onAppear(perform: syncSelection)
        .onChange(of: visibleProjects.map(\.id)) { _, _ in
            syncSelection()
        }
        .onChange(of: navigation.selectedProjectID) { _, _ in
            syncSelection()
        }
        .alert("Project Update Failed", isPresented: mutationErrorBinding) {
            Button("OK", role: .cancel) {
                mutationError = nil
            }
        } message: {
            Text(mutationError ?? "Unknown error")
        }
        .alert("Delete Project Permanently?", isPresented: pendingDeletionBinding) {
            Button("Delete", role: .destructive, action: deleteRequestedProject)
            Button("Cancel", role: .cancel) {
                pendingDeletionProjectID = nil
            }
        } message: {
            Text("Deleting \(pendingDeletionProject?.title ?? "this project") removes its steps, linked dependencies, and converted inbox targets that pointed into it.")
        }
        .sheet(isPresented: $isEditingSelectedProject) {
            NavigationStack {
                if let project = selectedProject {
                    ScrollView {
                        ProjectEditorPanel(
                            project: project,
                            focusedStepID: project.id == navigation.selectedProjectID ? navigation.selectedStepID : nil,
                            mutationError: $mutationError,
                            archiveAction: { archive(project) },
                            restoreAction: { restore(project) },
                            requestDeleteAction: { pendingDeletionProjectID = project.id }
                        )
                        .padding(24)
                    }
                    .navigationTitle("Edit Project")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                isEditingSelectedProject = false
                            }
                        }
                    }
                } else {
                    EmptyStateView(
                        title: "Select a Project",
                        message: "Choose a project from the list before opening the editor.",
                        systemImage: "square.stack.3d.up"
                    )
                    .padding(24)
                }
            }
        }
    }

    private var projectListPanel: some View {
        PanelCard(
            title: "Project Stack",
            subtitle: "Projects can now be actively worked, archived out of the main lanes, or permanently deleted with cleanup of dependent references."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Button(action: addProject) {
                        Label("Add Project", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)

                    Picker("Scope", selection: $listScope) {
                        ForEach(ProjectListScope.allCases) { scope in
                            Text(scope.title).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if visibleProjects.isEmpty {
                    EmptyStateView(
                        title: emptyStateTitle,
                        message: emptyStateMessage,
                        systemImage: "square.stack.3d.up"
                    )
                } else {
                    ForEach(visibleProjects) { project in
                        Button {
                            open(project)
                        } label: {
                            ProjectRowCard(
                                project: project,
                                isSelected: project.id == selectedProject?.id
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Open Project") {
                                open(project)
                            }

                            Divider()

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

                            Button("Start Today") {
                                PlanningMutationWorkflow.scheduleProjectFromToday(project)
                                persistContext()
                            }

                            Button("Push Back 1 Week") {
                                PlanningMutationWorkflow.shiftSchedule(project, byDays: 7)
                                persistContext()
                            }

                            if project.isArchived {
                                Button("Restore Project") {
                                    restore(project)
                                }
                            } else {
                                Button("Archive Project") {
                                    archive(project)
                                }
                            }

                            Button("Delete Permanently", role: .destructive) {
                                pendingDeletionProjectID = project.id
                            }
                        }
                    }
                }
            }
        }
    }

    private var projectDetailPanel: some View {
        Group {
            if let project = selectedProject {
                ProjectOverviewPanel(
                    project: project,
                    openEditorAction: {
                        isEditingSelectedProject = true
                    },
                    createProjectAction: addProject
                )
            } else {
                EmptyStateView(
                    title: "Select a Project",
                    message: "Open a project to see key facts here. Editing and creation live in dedicated flows.",
                    systemImage: "sidebar.left"
                )
            }
        }
    }

    private var emptyStateTitle: String {
        switch listScope {
        case .active:
            return projects.isEmpty ? "No Projects Yet" : "No Active Projects Match This Filter"
        case .archived:
            return "No Archived Projects"
        case .all:
            return "No Projects Match This Filter"
        }
    }

    private var emptyStateMessage: String {
        switch listScope {
        case .active:
            return projects.isEmpty
                ? "Capture a first project and the editor will appear here."
                : "Current filters are hiding active work. Try widening the scope."
        case .archived:
            return "Archived projects live here until you restore them."
        case .all:
            return "Current preferences are limiting the list to high-priority work only."
        }
    }

    private var pendingDeletionBinding: Binding<Bool> {
        Binding(
            get: { pendingDeletionProject != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeletionProjectID = nil
                }
            }
        )
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

    private func addProject() {
        let project = Project.starter()
        modelContext.insert(project)
        listScope = .active
        open(project)
        persistContext()
    }

    private func archive(_ project: Project) {
        project.archive()
        persistContext()
    }

    private func restore(_ project: Project) {
        project.restoreFromArchive()
        listScope = .all
        open(project)
        persistContext()
    }

    private func deleteRequestedProject() {
        guard let pendingDeletionProject else {
            return
        }

        do {
            try PlanningMutationWorkflow.deleteProject(pendingDeletionProject, in: modelContext)
            pendingDeletionProjectID = nil
            if navigation.selectedProjectID == pendingDeletionProject.id {
                navigation.selectedProjectID = nil
                navigation.selectedStepID = nil
            }
            try modelContext.saveIfNeeded()
        } catch {
            mutationError = error.localizedDescription
        }
    }

    private func open(_ project: Project) {
        selectedProjectID = project.id
        navigation.selectedStepID = nil
        navigation.selectedProjectID = project.id
    }

    private func persistContext() {
        do {
            try modelContext.saveIfNeeded()
        } catch {
            mutationError = error.localizedDescription
        }
    }

    private func syncSelection() {
        if let navigationProjectID = navigation.selectedProjectID,
           let navigationProject = projects.first(where: { $0.id == navigationProjectID }) {
            if navigationProject.isArchived && listScope == .active {
                listScope = .all
            }

            if visibleProjects.contains(where: { $0.id == navigationProjectID }) {
                selectedProjectID = navigationProjectID
                return
            }
        }

        if let selectedProjectID, visibleProjects.contains(where: { $0.id == selectedProjectID }) {
            return
        }

        selectedProjectID = visibleProjects.first?.id
        if navigation.selectedProjectID == nil {
            navigation.selectedProjectID = visibleProjects.first?.id
        }
    }
}

private struct ProjectOverviewPanel: View {
    @Environment(\.appTheme) private var theme
    let project: Project
    let openEditorAction: () -> Void
    let createProjectAction: () -> Void

    var body: some View {
        PanelCard(
            title: project.title,
            subtitle: "Information stays readable in this panel. Editing happens in a dedicated editor page."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    StatusBadge(status: project.status)
                    PriorityBadge(priority: project.priority)
                    TagChip(title: "\(project.openStepCount) open steps")

                    if project.isArchived {
                        ArchiveBadge()
                    }
                }

                if !project.summary.isEmpty {
                    Text(project.summary)
                        .foregroundStyle(theme.secondaryText)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                    MetricCard(
                        title: "Progress",
                        value: project.progress.formatted(.percent.precision(.fractionLength(0))),
                        systemImage: "chart.bar.fill",
                        tint: theme.projectColor(project.colorToken)
                    )
                    MetricCard(
                        title: "Steps",
                        value: "\(project.sortedSteps.count)",
                        systemImage: "list.bullet.rectangle.portrait",
                        tint: theme.accent
                    )
                    MetricCard(
                        title: "Created",
                        value: project.createdAt.formatted(date: .abbreviated, time: .omitted),
                        systemImage: "calendar",
                        tint: theme.projectColor(.cobalt)
                    )
                    MetricCard(
                        title: "Due",
                        value: project.resolvedDueDate?.formatted(date: .abbreviated, time: .omitted) ?? "Not set",
                        systemImage: "calendar.badge.clock",
                        tint: theme.projectColor(.rose)
                    )
                }

                if !project.tags.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(project.tags, id: \.self) { tag in
                            TagChip(title: tag)
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button(action: openEditorAction) {
                        Label("Edit Project", systemImage: "square.and.pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)

                    Button(action: createProjectAction) {
                        Label("New Project", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProjectsView()
    }
    .modelContainer(PreviewContainer.shared)
}
