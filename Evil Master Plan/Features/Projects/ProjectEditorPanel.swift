import SwiftUI
import SwiftData

struct ProjectEditorPanel: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Query private var dependencies: [Dependency]
    @Binding var mutationError: String?
    let focusedStepID: UUID?
    let archiveAction: () -> Void
    let restoreAction: () -> Void
    let requestDeleteAction: () -> Void
    @Bindable var project: Project

    init(
        project: Project,
        focusedStepID: UUID? = nil,
        mutationError: Binding<String?>,
        archiveAction: @escaping () -> Void,
        restoreAction: @escaping () -> Void,
        requestDeleteAction: @escaping () -> Void
    ) {
        self.focusedStepID = focusedStepID
        self._project = Bindable(project)
        self._mutationError = mutationError
        self.archiveAction = archiveAction
        self.restoreAction = restoreAction
        self.requestDeleteAction = requestDeleteAction
    }

    private var isEditable: Bool {
        !project.isArchived
    }

    private var projectDependencyCount: Int {
        dependencies.filter {
            $0.sourceReference == PlanningItemReference(kind: .project, id: project.id) ||
            $0.targetReference == PlanningItemReference(kind: .project, id: project.id)
        }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            projectDetailsCard
            projectStepsCard
        }
    }

    private var projectDetailsCard: some View {
        PanelCard(
            title: project.title,
            subtitle: "Projects are now editable working objects: status, priority, dates, archive state, and destructive actions all go through one consistent workflow."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                headerBadges

                if project.isArchived {
                    archivedNotice
                }

                VStack(alignment: .leading, spacing: 16) {
                    TextField("Project Title", text: $project.title)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: project.title) { _, _ in project.touch() }

                    TextField("Summary", text: $project.summary, axis: .vertical)
                        .lineLimit(3...5)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: project.summary) { _, _ in project.touch() }

                    HStack(spacing: 12) {
                        Picker("Status", selection: statusBinding) {
                            ForEach(ProjectStatus.allCases) { status in
                                Text(status.title).tag(status)
                            }
                        }

                        Picker("Priority", selection: priorityBinding) {
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
                        Slider(value: progressBinding, in: 0...1)
                    }

                    HStack(alignment: .top, spacing: 20) {
                        OptionalDatePickerRow(title: "Start Date", selection: startDateBinding)
                        OptionalDatePickerRow(title: "Due Date", selection: dueDateBinding)
                    }

                    HStack(spacing: 12) {
                        Picker("Color", selection: colorBinding) {
                            ForEach(ProjectColorToken.allCases) { token in
                                Text(token.rawValue.capitalized).tag(token)
                            }
                        }
                        .pickerStyle(.menu)

                        TextField("Tags", text: tagsBinding)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .disabled(!isEditable)

                actionStrip
            }
        }
    }

    private var headerBadges: some View {
        HStack(spacing: 8) {
            StatusBadge(status: project.status)
            PriorityBadge(priority: project.priority)
            TagChip(title: "\(project.openStepCount) open steps")
            TagChip(title: "\(projectDependencyCount) links")

            if project.isArchived {
                ArchiveBadge()
            }
        }
    }

    private var archivedNotice: some View {
        Label(
            "Archived projects stay out of the active planning surfaces until you restore them.",
            systemImage: "archivebox.fill"
        )
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(theme.secondaryText)
    }

    private var actionStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                CompactActionMenu(title: "Quick Status", systemImage: "flag.fill", tint: theme.accent) {
                    ForEach(ProjectStatus.allCases) { status in
                        Button(status.title) {
                            project.setStatus(status)
                            persistContext()
                        }
                    }
                }

                CompactActionMenu(title: "Priority", systemImage: "exclamationmark.circle") {
                    ForEach(PriorityLevel.allCases) { priority in
                        Button(priority.title) {
                            project.setPriority(priority)
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
                }

                CompactActionMenu(title: "Schedule", systemImage: "calendar") {
                    Button("Start Today") {
                        PlanningMutationWorkflow.scheduleProjectFromToday(project)
                        persistContext()
                    }

                    Button("Bring Forward 1 Week") {
                        PlanningMutationWorkflow.shiftSchedule(project, byDays: -7)
                        persistContext()
                    }

                    Button("Push Back 1 Week") {
                        PlanningMutationWorkflow.shiftSchedule(project, byDays: 7)
                        persistContext()
                    }

                    Button("Clear Dates") {
                        PlanningMutationWorkflow.clearSchedule(project)
                        persistContext()
                    }
                }

                CompactActionMenu(title: "Progress", systemImage: "chart.bar.fill") {
                    ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { value in
                        Button(value.formatted(.percent.precision(.fractionLength(0)))) {
                            project.setProgress(value)
                            persistContext()
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                if project.isArchived {
                    Button("Restore Project", action: restoreAction)
                        .buttonStyle(.borderedProminent)
                        .tint(theme.projectColor(project.colorToken))
                } else {
                    Button("Archive Project", action: archiveAction)
                        .buttonStyle(.bordered)
                }

                Button("Delete Permanently", role: .destructive, action: requestDeleteAction)
                    .buttonStyle(.bordered)
            }
        }
    }

    private var projectStepsCard: some View {
        PanelCard(
            title: "Steps",
            subtitle: "Tasks and milestones can now be added, reordered, rescheduled, reprioritized, and safely deleted with dependency cleanup."
        ) {
            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Button("Add Step", action: addStep)
                            .buttonStyle(.borderedProminent)
                            .tint(theme.projectColor(project.colorToken))
                            .disabled(!isEditable)

                        Button("Add Milestone", action: addMilestone)
                            .buttonStyle(.bordered)
                            .disabled(!isEditable)
                    }

                    if project.sortedSteps.isEmpty {
                        EmptyStateView(
                            title: project.isArchived ? "Archived Project Has No Active Step Editing" : "No Steps Yet",
                            message: project.isArchived
                                ? "Restore the project first if you want to keep working on its structure."
                                : "Break the project into a few visible pieces or add a milestone for the next commit point.",
                            systemImage: "point.bottomleft.forward.to.point.topright.scurvepath"
                        )
                    } else {
                        ForEach(project.sortedSteps) { step in
                            ProjectStepEditorCard(
                                step: step,
                                colorToken: project.colorToken,
                                dependencyCount: dependencyCount(for: step),
                                isFocused: step.id == focusedStepID,
                                isEditable: isEditable,
                                canMoveEarlier: project.canMoveStep(step, direction: .earlier),
                                canMoveLater: project.canMoveStep(step, direction: .later),
                                moveEarlierAction: {
                                    if PlanningMutationWorkflow.moveStep(step, direction: .earlier) {
                                        persistContext()
                                    }
                                },
                                moveLaterAction: {
                                    if PlanningMutationWorkflow.moveStep(step, direction: .later) {
                                        persistContext()
                                    }
                                },
                                removeAction: { remove(step) },
                                persistAction: persistContext
                            )
                            .id(step.id)
                        }
                    }
                }
                .onAppear {
                    scrollToFocusedStep(using: proxy)
                }
                .onChange(of: focusedStepID) { _, _ in
                    scrollToFocusedStep(using: proxy)
                }
            }
        }
    }

    private var statusBinding: Binding<ProjectStatus> {
        Binding(
            get: { project.status },
            set: {
                project.setStatus($0)
                persistContext()
            }
        )
    }

    private var priorityBinding: Binding<PriorityLevel> {
        Binding(
            get: { project.priority },
            set: {
                project.setPriority($0)
                persistContext()
            }
        )
    }

    private var colorBinding: Binding<ProjectColorToken> {
        Binding(
            get: { project.colorToken },
            set: {
                project.colorToken = $0
                project.touch()
                persistContext()
            }
        )
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
            set: {
                project.setStartDate($0)
                persistContext()
            }
        )
    }

    private var dueDateBinding: Binding<Date?> {
        Binding(
            get: { project.dueDate },
            set: {
                project.setDueDate($0)
                persistContext()
            }
        )
    }

    private var tagsBinding: Binding<String> {
        Binding(
            get: { project.tags.joined(separator: ", ") },
            set: { project.setTags(from: $0) }
        )
    }

    private func dependencyCount(for step: ProjectStep) -> Int {
        dependencies.filter {
            $0.sourceReference == PlanningItemReference(kind: .step, id: step.id) ||
            $0.targetReference == PlanningItemReference(kind: .step, id: step.id)
        }.count
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
        do {
            try PlanningMutationWorkflow.deleteStep(step, in: modelContext)
            persistContext()
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

    private func scrollToFocusedStep(using proxy: ScrollViewProxy) {
        guard let focusedStepID else {
            return
        }

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(focusedStepID, anchor: .center)
            }
        }
    }
}

private struct ProjectStepEditorCard: View {
    @Environment(\.appTheme) private var theme
    @Bindable var step: ProjectStep
    let colorToken: ProjectColorToken
    let dependencyCount: Int
    let isFocused: Bool
    let isEditable: Bool
    let canMoveEarlier: Bool
    let canMoveLater: Bool
    let moveEarlierAction: () -> Void
    let moveLaterAction: () -> Void
    let removeAction: () -> Void
    let persistAction: () -> Void
    @State private var showsDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Step Title", text: $step.title)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: step.title) { _, _ in step.touch() }

                    HStack(spacing: 8) {
                        TagChip(title: step.kind.title)
                        TagChip(title: "\(dependencyCount) links")
                        if step.isHighPriority {
                            PriorityBadge(priority: step.priority)
                        }
                    }
                }

                Spacer()

                CompactActionMenu(title: "Quick Actions", systemImage: "ellipsis.circle") {
                    Button("Move Earlier") {
                        moveEarlierAction()
                    }
                    .disabled(!canMoveEarlier)

                    Button("Move Later") {
                        moveLaterAction()
                    }
                    .disabled(!canMoveLater)

                    Divider()

                    ForEach(ProjectStatus.allCases) { status in
                        Button("Mark \(status.title)") {
                            step.setStatus(status)
                            persistAction()
                        }
                    }

                    Divider()

                    Button("Raise Priority") {
                        PlanningMutationWorkflow.nudgePriority(for: step, by: 1)
                        persistAction()
                    }

                    Button("Lower Priority") {
                        PlanningMutationWorkflow.nudgePriority(for: step, by: -1)
                        persistAction()
                    }

                    Divider()

                    Button("Schedule Today") {
                        PlanningMutationWorkflow.scheduleStepFromToday(step)
                        persistAction()
                    }

                    Button("Bring Forward 1 Week") {
                        PlanningMutationWorkflow.shiftSchedule(step, byDays: -7)
                        persistAction()
                    }

                    Button("Push Back 1 Week") {
                        PlanningMutationWorkflow.shiftSchedule(step, byDays: 7)
                        persistAction()
                    }

                    Button("Clear Dates") {
                        PlanningMutationWorkflow.clearSchedule(step)
                        persistAction()
                    }

                    Divider()

                    Button("Delete Permanently", role: .destructive) {
                        showsDeleteConfirmation = true
                    }
                }
                .disabled(!isEditable)
            }

            TextField("Notes", text: $step.notes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...3)
                .onChange(of: step.notes) { _, _ in step.touch() }

            HStack(spacing: 12) {
                Picker("Kind", selection: kindBinding) {
                    ForEach(ProjectStepKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }

                Picker("Status", selection: statusBinding) {
                    ForEach(ProjectStatus.allCases) { status in
                        Text(status.title).tag(status)
                    }
                }

                Picker("Priority", selection: priorityBinding) {
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
                        .foregroundStyle(theme.secondaryText)
                }
                Slider(value: progressBinding, in: 0...1)
            }

            HStack(alignment: .top, spacing: 20) {
                OptionalDatePickerRow(title: "Start Date", selection: startDateBinding)
                OptionalDatePickerRow(title: "Due Date", selection: dueDateBinding)
            }

            HStack(spacing: 10) {
                Button {
                    moveEarlierAction()
                } label: {
                    Label("Earlier", systemImage: "arrow.up")
                }
                .buttonStyle(.bordered)
                .disabled(!isEditable || !canMoveEarlier)

                Button {
                    moveLaterAction()
                } label: {
                    Label("Later", systemImage: "arrow.down")
                }
                .buttonStyle(.bordered)
                .disabled(!isEditable || !canMoveLater)

                Spacer()

                Button("Delete Permanently", role: .destructive) {
                    showsDeleteConfirmation = true
                }
                .buttonStyle(.bordered)
                .disabled(!isEditable)
            }
        }
        .padding(16)
        .appInsetCard(
            selected: isFocused,
            stroke: isFocused ? theme.accent.opacity(0.5) : theme.projectColor(colorToken).opacity(0.24)
        )
        .disabled(!isEditable)
        .contextMenu {
            Button("Move Earlier") {
                moveEarlierAction()
            }
            .disabled(!canMoveEarlier)

            Button("Move Later") {
                moveLaterAction()
            }
            .disabled(!canMoveLater)

            Button("Delete Permanently", role: .destructive) {
                showsDeleteConfirmation = true
            }
        }
        .alert("Delete Step Permanently?", isPresented: $showsDeleteConfirmation) {
            Button("Delete", role: .destructive, action: removeAction)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Dependencies linked to this step will be removed, and converted inbox items that pointed here will return to reviewing.")
        }
    }

    private var kindBinding: Binding<ProjectStepKind> {
        Binding(
            get: { step.kind },
            set: {
                step.setKind($0)
                persistAction()
            }
        )
    }

    private var statusBinding: Binding<ProjectStatus> {
        Binding(
            get: { step.status },
            set: {
                step.setStatus($0)
                persistAction()
            }
        )
    }

    private var priorityBinding: Binding<PriorityLevel> {
        Binding(
            get: { step.priority },
            set: {
                step.setPriority($0)
                persistAction()
            }
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
            set: {
                step.setStartDate($0)
                persistAction()
            }
        )
    }

    private var dueDateBinding: Binding<Date?> {
        Binding(
            get: { step.dueDate },
            set: {
                step.setDueDate($0)
                persistAction()
            }
        )
    }
}
