import SwiftUI
import SwiftData

struct ProjectsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var projects: [Project]
    @Query private var preferences: [VisualizationPreferences]
    @State private var selectedProjectID: UUID?
    @State private var mutationError: String?

    private var currentPreferences: VisualizationPreferences? {
        preferences.first
    }

    private var visibleProjects: [Project] {
        let sourceProjects: [Project]
        if currentPreferences?.showsOnlyHighPriorityProjects == true {
            sourceProjects = projects.filter(\.isHighPriority)
        } else {
            sourceProjects = projects
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
        .alert("Project Update Failed", isPresented: mutationErrorBinding) {
            Button("OK", role: .cancel) {
                mutationError = nil
            }
        } message: {
            Text(mutationError ?? "Unknown error")
        }
    }

    private var projectListPanel: some View {
        PanelCard(
            title: "Project Stack",
            subtitle: "One shared dataset. The list and every timeline view are reading the same projects and steps."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Button(action: addProject) {
                    Label("Add Project", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)

                if visibleProjects.isEmpty {
                    EmptyStateView(
                        title: projects.isEmpty ? "No Projects Yet" : "No Projects Match This Filter",
                        message: projects.isEmpty
                            ? "Capture a first project and the editor will appear here."
                            : "Current preferences are limiting the list to high-priority work only.",
                        systemImage: "square.stack.3d.up"
                    )
                } else {
                    ForEach(visibleProjects) { project in
                        Button {
                            selectedProjectID = project.id
                        } label: {
                            ProjectRowCard(
                                project: project,
                                isSelected: project.id == selectedProject?.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var projectDetailPanel: some View {
        Group {
            if let project = selectedProject {
                ProjectEditorPanel(project: project, mutationError: $mutationError)
            } else {
                EmptyStateView(
                    title: "Select a Project",
                    message: "The detail area becomes the working editor for the selected project.",
                    systemImage: "sidebar.left"
                )
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

    private func addProject() {
        let project = Project.starter()
        modelContext.insert(project)
        selectedProjectID = project.id

        do {
            try modelContext.saveIfNeeded()
        } catch {
            mutationError = error.localizedDescription
        }
    }

    private func syncSelection() {
        if let selectedProjectID, visibleProjects.contains(where: { $0.id == selectedProjectID }) {
            return
        }

        selectedProjectID = visibleProjects.first?.id
    }
}

#Preview {
    NavigationStack {
        ProjectsView()
    }
    .modelContainer(PreviewContainer.shared)
}
