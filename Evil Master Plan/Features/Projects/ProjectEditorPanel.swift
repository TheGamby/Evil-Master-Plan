import SwiftUI
import SwiftData

struct ProjectEditorPanel: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var mutationError: String?
    @Bindable var project: Project

    init(project: Project, mutationError: Binding<String?>) {
        self._project = Bindable(project)
        self._mutationError = mutationError
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PanelCard(title: project.title, subtitle: "Edit the project once; Bubble, Gantt, Dashboard, and Dependencies all update from this shared model.") {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Project Title", text: $project.title)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: project.title) { _, _ in project.touch() }

                    TextField("Summary", text: $project.summary, axis: .vertical)
                        .lineLimit(3...5)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: project.summary) { _, _ in project.touch() }

                    HStack(spacing: 12) {
                        Picker("Status", selection: $project.status) {
                            ForEach(ProjectStatus.allCases) { status in
                                Text(status.title).tag(status)
                            }
                        }

                        Picker("Priority", selection: $project.priority) {
                            ForEach(PriorityLevel.allCases) { priority in
                                Text(priority.title).tag(priority)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: project.status) { _, _ in project.touch() }
                    .onChange(of: project.priority) { _, _ in project.touch() }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Progress")
                            Spacer()
                            Text(project.progress, format: .percent.precision(.fractionLength(0)))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: progressBinding, in: 0...1)
                    }

                    HStack(alignment: .top, spacing: 20) {
                        OptionalDatePickerRow(title: "Start Date", selection: startDateBinding)
                        OptionalDatePickerRow(title: "Due Date", selection: dueDateBinding)
                    }

                    HStack(spacing: 12) {
                        Picker("Color", selection: $project.colorToken) {
                            ForEach(ProjectColorToken.allCases) { token in
                                Text(token.rawValue.capitalized).tag(token)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: project.colorToken) { _, _ in project.touch() }

                        TextField("Tags", text: tagsBinding)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            PanelCard(title: "Steps", subtitle: "Milestones remain normal `ProjectStep` records so time, graph, and dependency views stay aligned.") {
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
                            ProjectStepEditorCard(
                                step: step,
                                colorToken: project.colorToken,
                                removeAction: { remove(step) }
                            )
                        }
                    }
                }
            }
        }
    }

    private var progressBinding: Binding<Double> {
        Binding(
            get: { project.progress },
            set: { project.setProgress($0) }
        )
    }

    private var startDateBinding: Binding<Date?> {
        Binding(
            get: { project.startDate },
            set: { project.setStartDate($0) }
        )
    }

    private var dueDateBinding: Binding<Date?> {
        Binding(
            get: { project.dueDate },
            set: { project.setDueDate($0) }
        )
    }

    private var tagsBinding: Binding<String> {
        Binding(
            get: { project.tags.joined(separator: ", ") },
            set: { project.setTags(from: $0) }
        )
    }

    private func addStep() {
        _ = project.addStep()
        persistContext()
    }

    private func addMilestone() {
        _ = project.addMilestone()
        persistContext()
    }

    private func remove(_ step: ProjectStep) {
        modelContext.delete(step)
        project.touch()
        persistContext()
    }

    private func persistContext() {
        do {
            try modelContext.saveIfNeeded()
        } catch {
            mutationError = error.localizedDescription
        }
    }
}

private struct ProjectStepEditorCard: View {
    @Bindable var step: ProjectStep
    let colorToken: ProjectColorToken
    let removeAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                TextField("Step Title", text: $step.title)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: step.title) { _, _ in step.touch() }

                Picker("Kind", selection: $step.kind) {
                    ForEach(ProjectStepKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: step.kind) { _, _ in step.touch() }

                Button(role: .destructive, action: removeAction) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            TextField("Notes", text: $step.notes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...3)
                .onChange(of: step.notes) { _, _ in step.touch() }

            HStack(spacing: 12) {
                Picker("Status", selection: $step.status) {
                    ForEach(ProjectStatus.allCases) { status in
                        Text(status.title).tag(status)
                    }
                }

                Picker("Priority", selection: $step.priority) {
                    ForEach(PriorityLevel.allCases) { priority in
                        Text(priority.title).tag(priority)
                    }
                }
            }
            .pickerStyle(.menu)
            .onChange(of: step.status) { _, _ in step.touch() }
            .onChange(of: step.priority) { _, _ in step.touch() }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Progress")
                    Spacer()
                    Text(step.progress, format: .percent.precision(.fractionLength(0)))
                        .foregroundStyle(.secondary)
                }
                Slider(value: progressBinding, in: 0...1)
            }

            HStack(alignment: .top, spacing: 20) {
                OptionalDatePickerRow(title: "Start Date", selection: startDateBinding)
                OptionalDatePickerRow(title: "Due Date", selection: dueDateBinding)
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.projectColor(colorToken).opacity(0.18), lineWidth: 1)
        )
    }

    private var progressBinding: Binding<Double> {
        Binding(
            get: { step.progress },
            set: { step.setProgress($0) }
        )
    }

    private var startDateBinding: Binding<Date?> {
        Binding(
            get: { step.startDate },
            set: { step.setStartDate($0) }
        )
    }

    private var dueDateBinding: Binding<Date?> {
        Binding(
            get: { step.dueDate },
            set: { step.setDueDate($0) }
        )
    }
}
