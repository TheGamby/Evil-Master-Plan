import SwiftUI
import SwiftData

struct ProjectsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var projects: [Project]
    @Query private var preferences: [ViewPreferences]
    @State private var selectedProjectID: UUID?

    private var sortedProjects: [Project] {
        let criterion = preferences.first?.projectSortCriterion ?? .updatedAt

        switch criterion {
        case .updatedAt:
            return projects.sorted { $0.updatedAt > $1.updatedAt }
        case .priority:
            return projects.sorted { $0.priority > $1.priority }
        case .dueDate:
            return projects.sorted { ($0.resolvedDueDate ?? .distantFuture) < ($1.resolvedDueDate ?? .distantFuture) }
        case .progress:
            return projects.sorted { $0.progress > $1.progress }
        }
    }

    private var selectedProject: Project? {
        guard let selectedProjectID else {
            return sortedProjects.first
        }

        return sortedProjects.first { $0.id == selectedProjectID } ?? sortedProjects.first
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
        .onAppear {
            if selectedProjectID == nil {
                selectedProjectID = sortedProjects.first?.id
            }
        }
    }

    private var projectListPanel: some View {
        PanelCard(
            title: "Project Stack",
            subtitle: "Create quickly, then select a project to edit details and steps."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Button(action: addProject) {
                    Label("Add Project", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)

                if sortedProjects.isEmpty {
                    EmptyStateView(
                        title: "No Projects Yet",
                        message: "Capture a first project and the editor will appear here.",
                        systemImage: "square.stack.3d.up"
                    )
                } else {
                    ForEach(sortedProjects) { project in
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
                ProjectEditorPanel(project: project)
            } else {
                EmptyStateView(
                    title: "Select a Project",
                    message: "The right-hand side becomes a working inspector for the selected project.",
                    systemImage: "sidebar.left"
                )
            }
        }
    }

    private func addProject() {
        let project = Project.starter()
        modelContext.insert(project)
        selectedProjectID = project.id
        try? modelContext.save()
    }
}

private struct ProjectRowCard: View {
    let project: Project
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.projectColor(project.colorToken))
                .frame(width: 12, height: 54)

            VStack(alignment: .leading, spacing: 8) {
                Text(project.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(project.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    StatusBadge(status: project.status)
                    PriorityBadge(priority: project.priority)
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

private struct ProjectEditorPanel: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PanelCard(title: project.title, subtitle: "Shared planning data edited once and reused by every visualization.") {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Project Title", text: binding(for: \.title))
                        .textFieldStyle(.roundedBorder)

                    TextField("Summary", text: binding(for: \.summary), axis: .vertical)
                        .lineLimit(3...5)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 12) {
                        Picker("Status", selection: binding(for: \.status)) {
                            ForEach(ProjectStatus.allCases) { status in
                                Text(status.title).tag(status)
                            }
                        }

                        Picker("Priority", selection: binding(for: \.priority)) {
                            ForEach(PriorityLevel.allCases) { priority in
                                Text(priority.title).tag(priority)
                            }
                        }
                    }
                    .pickerStyle(.menu)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Progress")
                            Spacer()
                            Text(project.progress, format: .percent.precision(.fractionLength(0)))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: binding(for: \.progress), in: 0...1)
                    }

                    HStack(alignment: .top, spacing: 20) {
                        OptionalDatePickerRow(title: "Start Date", selection: binding(for: \.startDate))
                        OptionalDatePickerRow(title: "Due Date", selection: binding(for: \.dueDate))
                    }

                    HStack(spacing: 12) {
                        Picker("Color", selection: binding(for: \.colorToken)) {
                            ForEach(ProjectColorToken.allCases) { token in
                                Text(token.rawValue.capitalized).tag(token)
                            }
                        }
                        .pickerStyle(.menu)

                        TextField("Tags", text: tagsBinding)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            PanelCard(title: "Steps", subtitle: "Milestones are explicit `ProjectStep` records, not a second task system.") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Button("Add Step", action: addStep)
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.projectColor(project.colorToken))
                        Button("Add Milestone", action: addMilestone)
                            .buttonStyle(.bordered)
                    }

                    if project.sortedSteps.isEmpty {
                        EmptyStateView(
                            title: "No Steps Yet",
                            message: "Break the project into a few visible pieces or add a milestone for the next commit point.",
                            systemImage: "point.bottomleft.forward.to.point.topright.scurvepath"
                        )
                    } else {
                        ForEach(project.sortedSteps) { step in
                            ProjectStepEditorCard(step: step, colorToken: project.colorToken)
                        }
                    }
                }
            }
        }
    }

    private var tagsBinding: Binding<String> {
        Binding(
            get: { project.tags.joined(separator: ", ") },
            set: { value in
                project.tags = value
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                project.touch()
            }
        )
    }

    private func binding<Value>(for keyPath: ReferenceWritableKeyPath<Project, Value>) -> Binding<Value> {
        Binding(
            get: { project[keyPath: keyPath] },
            set: { newValue in
                project[keyPath: keyPath] = newValue
                project.touch()
            }
        )
    }

    private func addStep() {
        let nextOrder = (project.steps.map(\.sortOrder).max() ?? -1) + 1
        let step = ProjectStep(
            project: project,
            title: "New Step",
            notes: "",
            status: .idea,
            priority: .medium,
            progress: 0,
            startDate: project.startDate,
            dueDate: project.dueDate,
            sortOrder: nextOrder
        )
        project.steps.append(step)
        project.touch()
    }

    private func addMilestone() {
        let nextOrder = (project.steps.map(\.sortOrder).max() ?? -1) + 1
        let step = ProjectStep(
            project: project,
            title: "New Milestone",
            notes: "",
            status: .idea,
            priority: .high,
            progress: 0,
            startDate: project.dueDate,
            dueDate: project.dueDate,
            sortOrder: nextOrder,
            kind: .milestone
        )
        project.steps.append(step)
        project.touch()
    }
}

private struct ProjectStepEditorCard: View {
    let step: ProjectStep
    let colorToken: ProjectColorToken

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                TextField("Step Title", text: binding(for: \.title))
                    .textFieldStyle(.roundedBorder)
                Picker("Kind", selection: binding(for: \.kind)) {
                    ForEach(ProjectStepKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.menu)
            }

            TextField("Notes", text: binding(for: \.notes), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...3)

            HStack(spacing: 12) {
                Picker("Status", selection: binding(for: \.status)) {
                    ForEach(ProjectStatus.allCases) { status in
                        Text(status.title).tag(status)
                    }
                }

                Picker("Priority", selection: binding(for: \.priority)) {
                    ForEach(PriorityLevel.allCases) { priority in
                        Text(priority.title).tag(priority)
                    }
                }
            }
            .pickerStyle(.menu)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Progress")
                    Spacer()
                    Text(step.progress, format: .percent.precision(.fractionLength(0)))
                        .foregroundStyle(.secondary)
                }
                Slider(value: binding(for: \.progress), in: 0...1)
            }

            HStack(alignment: .top, spacing: 20) {
                OptionalDatePickerRow(title: "Start Date", selection: binding(for: \.startDate))
                OptionalDatePickerRow(title: "Due Date", selection: binding(for: \.dueDate))
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.projectColor(colorToken).opacity(0.18), lineWidth: 1)
        )
    }

    private func binding<Value>(for keyPath: ReferenceWritableKeyPath<ProjectStep, Value>) -> Binding<Value> {
        Binding(
            get: { step[keyPath: keyPath] },
            set: { newValue in
                step[keyPath: keyPath] = newValue
                step.touch()
            }
        )
    }
}

#Preview {
    NavigationStack {
        ProjectsView()
    }
    .modelContainer(PreviewContainer.shared)
}
