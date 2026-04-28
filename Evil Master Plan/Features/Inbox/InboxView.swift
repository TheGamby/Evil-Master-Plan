import SwiftUI
import SwiftData

struct InboxView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigationModel.self) private var navigation
    @Query(sort: [SortDescriptor(\IdeaInboxItem.updatedAt, order: .reverse)]) private var inboxItems: [IdeaInboxItem]
    @Query(sort: [SortDescriptor(\Project.updatedAt, order: .reverse)]) private var projects: [Project]
    @State private var draftTitle = ""
    @State private var draftBody = ""
    @State private var draftTags = ""
    @State private var draftPriorityHint: PriorityLevel?
    @State private var draftSource: IdeaInboxSource? = .manualCapture
    @State private var activeFilter: InboxListFilter = .triage
    @State private var isShowingQuickCaptureDetails = false
    @State private var selectedItemID: UUID?
    @State private var isEditingSelectedItem = false
    @State private var conversionContext: InboxConversionSheetContext?
    @State private var mutationError: String?
    @State private var pendingDeletionItemID: UUID?

    private var snapshot: InboxSnapshot {
        InboxProjectionFactory.snapshot(items: inboxItems, filter: activeFilter)
    }

    private var selectedItem: IdeaInboxItem? {
        guard let selectedItemID else {
            return item(for: snapshot.defaultItemID)
        }

        return item(for: selectedItemID) ?? item(for: snapshot.defaultItemID)
    }

    private var pendingDeletionItem: IdeaInboxItem? {
        item(for: pendingDeletionItemID)
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    quickCapturePanel
                    inboxSummaryPanel

                    if proxy.size.width > 960 {
                        HStack(alignment: .top, spacing: 20) {
                            queuePanel
                                .frame(maxWidth: 420)
                            detailPanel
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 20) {
                            queuePanel
                            detailPanel
                        }
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Inbox")
        .onAppear(perform: syncSelection)
        .onChange(of: navigation.selectedInboxItemID) { _, _ in
            syncSelection()
        }
        .onChange(of: activeFilter) { _, _ in
            syncSelection()
        }
        .onChange(of: snapshot.defaultItemID) { _, _ in
            syncSelection()
        }
        .sheet(item: $conversionContext) { context in
            InboxConversionSheet(item: context.item, projects: projects) { request in
                convert(context.item, using: request)
            }
        }
        .sheet(isPresented: $isShowingQuickCaptureDetails) {
            NavigationStack {
                InboxQuickCaptureDetailsSheet(
                    bodyText: $draftBody,
                    tagsText: $draftTags,
                    priorityHint: $draftPriorityHint,
                    source: $draftSource
                )
            }
        }
        .sheet(isPresented: $isEditingSelectedItem) {
            NavigationStack {
                if let selectedItem {
                    ScrollView {
                        InboxEditPanel(item: selectedItem)
                            .padding(24)
                    }
                    .navigationTitle("Edit Inbox Item")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                isEditingSelectedItem = false
                            }
                        }
                    }
                } else {
                    EmptyStateView(
                        title: "Select an Inbox Item",
                        message: "Choose an item first, then open the editor.",
                        systemImage: "tray"
                    )
                    .padding(24)
                }
            }
        }
        .alert("Inbox Update Failed", isPresented: mutationErrorBinding) {
            Button("OK", role: .cancel) {
                mutationError = nil
            }
        } message: {
            Text(mutationError ?? "Unknown error")
        }
        .alert("Delete Inbox Item Permanently?", isPresented: pendingDeletionBinding) {
            Button("Delete", role: .destructive, action: deleteRequestedItem)
            Button("Cancel", role: .cancel) {
                pendingDeletionItemID = nil
            }
        } message: {
            Text("Deleting \(pendingDeletionItem?.title ?? "this item") removes it completely. Archive keeps it in history; delete does not.")
        }
    }

    private var quickCapturePanel: some View {
        PanelCard(title: "Quick Capture", subtitle: "Fast input first. Structure happens during triage, not at the moment of capture.") {
            VStack(alignment: .leading, spacing: 14) {
                TextField("Idea title", text: $draftTitle)
                    .textFieldStyle(.roundedBorder)

                if !draftBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draftPriorityHint != nil || !draftTags.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Label("Details added", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.projectColor(.cobalt))
                }

                Button {
                    isShowingQuickCaptureDetails = true
                } label: {
                    Label("Add details", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.bordered)

                Button(action: addInboxItem) {
                    Label("Send to Inbox", systemImage: "tray.and.arrow.down.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .disabled(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var inboxSummaryPanel: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
            MetricCard(
                title: "Needs Triage",
                value: "\(snapshot.triageCount)",
                systemImage: "tray.and.arrow.down.fill",
                tint: theme.projectColor(.cobalt)
            )
            MetricCard(
                title: "Reviewing",
                value: "\(snapshot.reviewingCount)",
                systemImage: "doc.text.magnifyingglass",
                tint: theme.projectColor(.cyan)
            )
            MetricCard(
                title: "Converted",
                value: "\(snapshot.convertedCount)",
                systemImage: "arrow.triangle.branch",
                tint: theme.statusColor(.done)
            )
            MetricCard(
                title: "Archived",
                value: "\(snapshot.archivedCount)",
                systemImage: "archivebox.fill",
                tint: theme.secondaryText
            )
        }
    }

    private var queuePanel: some View {
        PanelCard(
            title: "Triage Queue",
            subtitle: "Review the queue regularly: keep, review, convert, or archive. Converted items stay visible instead of disappearing."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Picker("View", selection: $activeFilter) {
                    ForEach(InboxListFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                if snapshot.sections.flatMap(\.items).isEmpty {
                    EmptyStateView(
                        title: activeFilter == .triage ? "No Items Need Triage" : "No Items In This Slice",
                        message: activeFilter == .triage
                            ? "Fresh capture and reviewing notes will land here."
                            : "Switch the filter or capture a new idea to repopulate the inbox.",
                        systemImage: "tray"
                    )
                } else {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(snapshot.sections) { section in
                            InboxQueueSection(
                                section: section,
                                selectedItemID: selectedItem?.id,
                                selectAction: { item in
                                    selectedItemID = item.id
                                    navigation.selectedInboxItemID = item.id
                                },
                                reviewAction: { item in
                                    item.markReviewing()
                                    persistContext()
                                },
                                convertAction: { item in
                                    conversionContext = InboxConversionSheetContext(item: item)
                                },
                                archiveAction: { item in
                                    item.archive()
                                    persistContext()
                                },
                                deleteAction: { item in
                                    pendingDeletionItemID = item.id
                                },
                                reopenAction: { item in
                                    item.reopen()
                                    persistContext()
                                },
                                openTargetAction: { item in
                                    openTarget(for: item)
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    private var detailPanel: some View {
        Group {
            if let selectedItem {
                InboxDetailPanel(
                    item: selectedItem,
                    openEditorAction: {
                        isEditingSelectedItem = true
                    },
                    openConvertAction: {
                        conversionContext = InboxConversionSheetContext(item: selectedItem)
                    },
                    reviewAction: {
                        selectedItem.markReviewing()
                        persistContext()
                    },
                    resetToNewAction: {
                        selectedItem.reopen()
                        persistContext()
                    },
                    archiveAction: {
                        selectedItem.archive()
                        persistContext()
                    },
                    deleteAction: {
                        pendingDeletionItemID = selectedItem.id
                    },
                    openTargetAction: {
                        openTarget(for: selectedItem)
                    }
                )
            } else {
                EmptyStateView(
                    title: "Select an Inbox Item",
                    message: "Use this area to understand context quickly. Edit fields in the dedicated editor page.",
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

    private var pendingDeletionBinding: Binding<Bool> {
        Binding(
            get: { pendingDeletionItem != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeletionItemID = nil
                }
            }
        )
    }

    private func addInboxItem() {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return
        }

        let item = IdeaInboxItem(
            title: title,
            body: draftBody,
            state: .open,
            tags: draftTags
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) },
            priorityHint: draftPriorityHint,
            source: draftSource
        )
        modelContext.insert(item)
        draftTitle = ""
        draftBody = ""
        draftTags = ""
        draftPriorityHint = nil
        draftSource = .manualCapture
        navigation.selectedInboxItemID = item.id
        selectedItemID = item.id
        activeFilter = .triage
        persistContext()
    }

    private func convert(_ item: IdeaInboxItem, using request: InboxConversionRequest) {
        let result = InboxWorkflow.convert(item, using: request)
        if let createdProject = result.createdProject {
            modelContext.insert(createdProject)
        }

        navigation.selectedInboxItemID = item.id
        selectedItemID = item.id
        activeFilter = .all
        persistContext()
    }

    private func deleteRequestedItem() {
        guard let pendingDeletionItem else {
            return
        }

        PlanningMutationWorkflow.deleteInboxItem(pendingDeletionItem, in: modelContext)
        if selectedItemID == pendingDeletionItem.id {
            selectedItemID = nil
        }
        if navigation.selectedInboxItemID == pendingDeletionItem.id {
            navigation.selectedInboxItemID = nil
        }
        pendingDeletionItemID = nil
        persistContext()
    }

    private func openTarget(for item: IdeaInboxItem) {
        if let linkedStep = item.linkedStep, let linkedProject = item.linkedProject {
            navigation.openProject(linkedProject.id, stepID: linkedStep.id)
        } else if let linkedProject = item.linkedProject {
            navigation.openProject(linkedProject.id)
        }
    }

    private func persistContext() {
        do {
            try modelContext.saveIfNeeded()
        } catch {
            mutationError = error.localizedDescription
        }
    }

    private func syncSelection() {
        if let requestedID = navigation.selectedInboxItemID,
           requestedID != selectedItemID,
           let requestedItem = item(for: requestedID) {
            selectedItemID = requestedItem.id
            activeFilter = filter(for: requestedItem.state)
            return
        }

        if let selectedItemID,
           let selectedItem = item(for: selectedItemID),
           isVisible(selectedItem, in: activeFilter) {
            return
        }

        selectedItemID = snapshot.defaultItemID
        navigation.selectedInboxItemID = snapshot.defaultItemID
    }

    private func item(for id: UUID?) -> IdeaInboxItem? {
        guard let id else {
            return nil
        }

        return inboxItems.first { $0.id == id }
    }

    private func isVisible(_ item: IdeaInboxItem, in filter: InboxListFilter) -> Bool {
        switch filter {
        case .triage:
            item.state.needsTriage
        case .reviewing:
            item.state == .reviewing
        case .converted:
            item.state == .converted
        case .archived:
            item.state == .archived
        case .all:
            true
        }
    }

    private func filter(for state: IdeaInboxState) -> InboxListFilter {
        switch state {
        case .open, .reviewing:
            .triage
        case .converted:
            .converted
        case .archived:
            .archived
        }
    }
}

private struct InboxQueueSection: View {
    @Environment(\.appTheme) private var theme
    let section: InboxSectionSnapshot
    let selectedItemID: UUID?
    let selectAction: (IdeaInboxItem) -> Void
    let reviewAction: (IdeaInboxItem) -> Void
    let convertAction: (IdeaInboxItem) -> Void
    let archiveAction: (IdeaInboxItem) -> Void
    let deleteAction: (IdeaInboxItem) -> Void
    let reopenAction: (IdeaInboxItem) -> Void
    let openTargetAction: (IdeaInboxItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(section.title)
                    .font(.headline)
                    .foregroundStyle(theme.primaryText)
                Spacer()
                TagChip(title: "\(section.items.count)")
            }

            ForEach(section.items) { item in
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        selectAction(item)
                    } label: {
                        InboxQueueRow(item: item, isSelected: item.id == selectedItemID)
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 8) {
                        if item.state == .open {
                            Button("Review") {
                                reviewAction(item)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        if item.canConvert {
                            Button("Convert") {
                                convertAction(item)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }

                        if item.state == .archived {
                            Button("Reopen") {
                                reopenAction(item)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        } else if item.state != .converted {
                            Button("Archive") {
                                archiveAction(item)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                .contextMenu {
                    if item.state == .open {
                        Button("Start Review") {
                            reviewAction(item)
                        }
                    }

                    if item.canConvert {
                        Button("Convert") {
                            convertAction(item)
                        }
                    }

                    if item.state == .archived {
                        Button("Return to Triage") {
                            reopenAction(item)
                        }
                    } else if item.state != .converted {
                        Button("Archive") {
                            archiveAction(item)
                        }
                    }

                    if item.state == .converted {
                        Button("Open Target") {
                            openTargetAction(item)
                        }
                    }

                    Button("Delete Permanently", role: .destructive) {
                        deleteAction(item)
                    }
                }
            }
        }
    }
}

private struct InboxQueueRow: View {
    @Environment(\.appTheme) private var theme
    let item: IdeaInboxItem
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(theme.primaryText)

                    if !item.trimmedBody.isEmpty {
                        Text(item.trimmedBody)
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                            .lineLimit(2)
                    }
                }

                Spacer()

                InboxStateBadge(state: item.state)
            }

            HStack(spacing: 8) {
                if let priorityHint = item.priorityHint {
                    PriorityBadge(priority: priorityHint)
                }

                if let source = item.source {
                    TagChip(title: source.title)
                }

                if let conversionTarget = item.conversionTarget {
                    InboxConversionBadge(target: conversionTarget)
                }
            }

            HStack {
                Text(item.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)

                Spacer()

                if let linkedProject = item.linkedProject {
                    TagChip(title: linkedProject.title)
                }
            }
        }
        .padding(16)
        .appInsetCard(selected: isSelected, stroke: isSelected ? theme.accent.opacity(0.42) : theme.subtleStroke)
    }
}

private struct InboxDetailPanel: View {
    private enum PrimaryAction {
        case openTarget
        case convert
        case startReview
        case returnToNew
        case returnToTriage

        var title: String {
            switch self {
            case .openTarget:
                "Open Target"
            case .convert:
                "Convert"
            case .startReview:
                "Start Review"
            case .returnToNew:
                "Return to New"
            case .returnToTriage:
                "Return to Triage"
            }
        }
    }

    @Environment(\.appTheme) private var theme
    let openEditorAction: () -> Void
    let openConvertAction: () -> Void
    let reviewAction: () -> Void
    let resetToNewAction: () -> Void
    let archiveAction: () -> Void
    let deleteAction: () -> Void
    let openTargetAction: () -> Void
    @Bindable var item: IdeaInboxItem

    init(
        item: IdeaInboxItem,
        openEditorAction: @escaping () -> Void,
        openConvertAction: @escaping () -> Void,
        reviewAction: @escaping () -> Void,
        resetToNewAction: @escaping () -> Void,
        archiveAction: @escaping () -> Void,
        deleteAction: @escaping () -> Void,
        openTargetAction: @escaping () -> Void
    ) {
        self._item = Bindable(item)
        self.openEditorAction = openEditorAction
        self.openConvertAction = openConvertAction
        self.reviewAction = reviewAction
        self.resetToNewAction = resetToNewAction
        self.archiveAction = archiveAction
        self.deleteAction = deleteAction
        self.openTargetAction = openTargetAction
    }

    var body: some View {
        PanelCard(
            title: item.title,
            subtitle: "Read-first detail card. Edit title, notes, metadata, and tags in the dedicated editor page."
        ) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    InboxStateBadge(state: item.state)

                    if let conversionTarget = item.conversionTarget {
                        InboxConversionBadge(target: conversionTarget)
                    }

                    if let priorityHint = item.priorityHint {
                        PriorityBadge(priority: priorityHint)
                    }
                }

                if !item.trimmedBody.isEmpty {
                    Text(item.trimmedBody)
                        .foregroundStyle(theme.secondaryText)
                }

                metadataContent

                VStack(alignment: .leading, spacing: 8) {
                    metadataRow(label: "Created", value: item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    metadataRow(label: "Updated", value: item.updatedAt.formatted(date: .abbreviated, time: .shortened))

                    if let convertedAt = item.convertedAt {
                        metadataRow(label: "Converted", value: convertedAt.formatted(date: .abbreviated, time: .shortened))
                    }

                    if let archivedAt = item.archivedAt {
                        metadataRow(label: "Archived", value: archivedAt.formatted(date: .abbreviated, time: .shortened))
                    }

                    if let linkedStep = item.linkedStep, let linkedProject = item.linkedProject {
                        metadataRow(label: "Target", value: "\(linkedProject.title) → \(linkedStep.title)")
                    } else if let linkedProject = item.linkedProject {
                        metadataRow(label: "Target", value: linkedProject.title)
                    }
                }

                actionRow
            }
        }
    }

    @ViewBuilder
    private var metadataContent: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
            MetricCard(
                title: "State",
                value: item.state.title,
                systemImage: "flag.fill",
                tint: theme.accent
            )
            MetricCard(
                title: "Priority Hint",
                value: item.priorityHint?.title ?? "None",
                systemImage: "exclamationmark.circle",
                tint: theme.priorityColor(item.priorityHint ?? .low)
            )
            MetricCard(
                title: "Source",
                value: item.source?.title ?? "Unknown",
                systemImage: "square.and.arrow.down",
                tint: theme.projectColor(.cobalt)
            )
            MetricCard(
                title: "Tags",
                value: item.tags.isEmpty ? "None" : "\(item.tags.count)",
                systemImage: "tag.fill",
                tint: theme.projectColor(.cyan)
            )
        }

        if !item.tags.isEmpty {
            HStack(spacing: 8) {
                ForEach(item.tags, id: \.self) { tag in
                    TagChip(title: tag)
                }
            }
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let primaryAction {
                Button(primaryAction.title, action: runPrimaryAction)
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)
            }

            Button(action: openEditorAction) {
                Label("Edit Item", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if item.state == .open && primaryAction != .startReview {
                Button("Start Review", action: reviewAction)
                    .buttonStyle(.bordered)
            }

            if item.state == .reviewing && primaryAction != .returnToNew {
                Button("Return to New", action: resetToNewAction)
                    .buttonStyle(.bordered)
            }

            if item.canConvert && primaryAction != .convert {
                Button("Convert", action: openConvertAction)
                    .buttonStyle(.bordered)
            }

            if item.state == .converted && primaryAction != .openTarget {
                Button("Open Target", action: openTargetAction)
                    .buttonStyle(.bordered)
            }

            if item.state == .archived && primaryAction != .returnToTriage {
                Button("Return to Triage", action: resetToNewAction)
                    .buttonStyle(.bordered)
            } else if item.state != .converted {
                Button("Archive", action: archiveAction)
                    .buttonStyle(.bordered)
            }

            Button("Delete Permanently", role: .destructive, action: deleteAction)
                .buttonStyle(.bordered)
        }
    }

    private var primaryAction: PrimaryAction? {
        if item.state == .converted {
            return .openTarget
        }

        if item.canConvert {
            return .convert
        }

        if item.state == .open {
            return .startReview
        }

        if item.state == .reviewing {
            return .returnToNew
        }

        if item.state == .archived {
            return .returnToTriage
        }

        return nil
    }

    private func runPrimaryAction() {
        switch primaryAction {
        case .openTarget:
            openTargetAction()
        case .convert:
            openConvertAction()
        case .startReview:
            reviewAction()
        case .returnToNew:
            resetToNewAction()
        case .returnToTriage:
            resetToNewAction()
        default:
            break
        }
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundStyle(theme.primaryText)
        }
    }
}

private struct InboxEditPanel: View {
    @Bindable var item: IdeaInboxItem

    init(item: IdeaInboxItem) {
        self._item = Bindable(item)
    }

    var body: some View {
        PanelCard(
            title: item.title,
            subtitle: "Edit fields without cluttering the read-focused detail card."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                TextField("Title", text: $item.title)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: item.title) { _, _ in item.touch() }

                TextField("Notes", text: $item.body, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(4...8)
                    .onChange(of: item.body) { _, _ in item.touch() }

                HStack(spacing: 12) {
                    Picker("Priority Hint", selection: $item.priorityHint) {
                        Text("None").tag(Optional<PriorityLevel>.none)
                        ForEach(PriorityLevel.allCases) { priority in
                            Text(priority.title).tag(Optional(priority))
                        }
                    }

                    Picker("Source", selection: $item.source) {
                        Text("Unknown").tag(Optional<IdeaInboxSource>.none)
                        ForEach(IdeaInboxSource.allCases) { source in
                            Text(source.title).tag(Optional(source))
                        }
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: item.priorityHint) { _, _ in item.touch() }
                .onChange(of: item.source) { _, _ in item.touch() }

                TextField("Tags", text: tagsBinding)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var tagsBinding: Binding<String> {
        Binding(
            get: { item.tags.joined(separator: ", ") },
            set: { item.setTags(from: $0) }
        )
    }
}

private struct InboxQuickCaptureDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var bodyText: String
    @Binding var tagsText: String
    @Binding var priorityHint: PriorityLevel?
    @Binding var source: IdeaInboxSource?

    var body: some View {
        Form {
            Section("Optional Context") {
                TextField("Context, fragment, or next thought", text: $bodyText, axis: .vertical)
                    .lineLimit(4...8)
            }

            Section("Metadata") {
                Picker("Priority Hint", selection: $priorityHint) {
                    Text("None").tag(Optional<PriorityLevel>.none)
                    ForEach(PriorityLevel.allCases) { priority in
                        Text(priority.title).tag(Optional(priority))
                    }
                }

                Picker("Source", selection: $source) {
                    Text("Unknown").tag(Optional<IdeaInboxSource>.none)
                    ForEach(IdeaInboxSource.allCases) { source in
                        Text(source.title).tag(Optional(source))
                    }
                }

                TextField("Tags", text: $tagsText)
            }
        }
        .navigationTitle("Capture Details")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

private struct InboxConversionSheetContext: Identifiable {
    let item: IdeaInboxItem
    var id: UUID { item.id }
}

private enum InboxConversionMode: String, CaseIterable, Identifiable {
    case project
    case step

    var id: String { rawValue }

    var title: String {
        switch self {
        case .project:
            "New Project"
        case .step:
            "Step in Existing Project"
        }
    }
}

private struct InboxConversionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: IdeaInboxItem
    let projects: [Project]
    let onConvert: (InboxConversionRequest) -> Void
    @State private var mode: InboxConversionMode = .project
    @State private var title: String
    @State private var notes: String
    @State private var status: ProjectStatus
    @State private var priority: PriorityLevel
    @State private var colorToken: ProjectColorToken
    @State private var tagsText: String
    @State private var selectedProjectID: UUID?
    @State private var stepKind: ProjectStepKind = .task

    init(
        item: IdeaInboxItem,
        projects: [Project],
        onConvert: @escaping (InboxConversionRequest) -> Void
    ) {
        self.item = item
        self.projects = projects
        self.onConvert = onConvert

        let projectDraft = InboxWorkflow.makeProjectDraft(for: item)
        _title = State(initialValue: projectDraft.title)
        _notes = State(initialValue: projectDraft.summary)
        _status = State(initialValue: .idea)
        _priority = State(initialValue: item.priorityHint ?? .medium)
        _colorToken = State(initialValue: projectDraft.colorToken)
        _tagsText = State(initialValue: projectDraft.tags.joined(separator: ", "))
        _selectedProjectID = State(initialValue: projects.first?.id)
    }

    private var canSubmit: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return false
        }

        if mode == .step {
            return selectedProject != nil
        }

        return true
    }

    private var selectedProject: Project? {
        guard let selectedProjectID else {
            return nil
        }

        return projects.first { $0.id == selectedProjectID }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Transition") {
                    Picker("Convert Into", selection: $mode) {
                        Text(InboxConversionMode.project.title).tag(InboxConversionMode.project)
                        Text(InboxConversionMode.step.title).tag(InboxConversionMode.step)
                    }
                    .pickerStyle(.segmented)

                    Text("The inbox item stays in the system and is marked as converted after the target is created.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Mapped Content") {
                    TextField("Title", text: $title)
                    TextField(mode == .project ? "Project summary" : "Step notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if mode == .project {
                    Section("New Project") {
                        Picker("Status", selection: $status) {
                            ForEach(ProjectStatus.allCases.filter { $0 != .done }) { status in
                                Text(status.title).tag(status)
                            }
                        }

                        Picker("Priority", selection: $priority) {
                            ForEach(PriorityLevel.allCases) { priority in
                                Text(priority.title).tag(priority)
                            }
                        }

                        Picker("Color", selection: $colorToken) {
                            ForEach(ProjectColorToken.allCases) { token in
                                Text(token.rawValue.capitalized).tag(token)
                            }
                        }

                        TextField("Tags", text: $tagsText)
                    }
                } else {
                    Section("Existing Project") {
                        if projects.isEmpty {
                            Text("Create a project first if you want to turn this into a step.")
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Project", selection: $selectedProjectID) {
                                ForEach(projects) { project in
                                    Text(project.title).tag(Optional(project.id))
                                }
                            }

                            Picker("Kind", selection: $stepKind) {
                                Text("Task").tag(ProjectStepKind.task)
                                Text("Milestone").tag(ProjectStepKind.milestone)
                            }

                            Picker("Status", selection: $status) {
                                ForEach(ProjectStatus.allCases.filter { $0 != .done }) { status in
                                    Text(status.title).tag(status)
                                }
                            }

                            Picker("Priority", selection: $priority) {
                                ForEach(PriorityLevel.allCases) { priority in
                                    Text(priority.title).tag(priority)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Convert Inbox Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Convert", action: submit)
                        .disabled(!canSubmit)
                }
            }
        }
    }

    private func submit() {
        switch mode {
        case .project:
            onConvert(
                .newProject(
                    InboxProjectConversionDraft(
                        title: title,
                        summary: notes,
                        status: status,
                        priority: priority,
                        colorToken: colorToken,
                        tags: tagsText
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    )
                )
            )
        case .step:
            guard let selectedProject else {
                return
            }

            let draft = InboxWorkflow.makeStepDraft(for: item, project: selectedProject)
            onConvert(
                .projectStep(
                    InboxStepConversionDraft(
                        project: selectedProject,
                        title: title,
                        notes: notes,
                        kind: stepKind,
                        status: status,
                        priority: priority,
                        startDate: draft.startDate,
                        dueDate: stepKind == .milestone ? (draft.dueDate ?? selectedProject.dueDate ?? .now) : draft.dueDate
                    )
                )
            )
        }

        dismiss()
    }
}

#Preview {
    NavigationStack {
        InboxView()
    }
    .modelContainer(PreviewContainer.shared)
}
