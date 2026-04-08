import SwiftUI

struct TimelineGeometry {
    let scale: TimelineScale
    let labelWidth: CGFloat
    let unitWidth: CGFloat
    let rowHeight: CGFloat
    let trailingPadding: CGFloat

    init(
        scale: TimelineScale,
        labelWidth: CGFloat = 280,
        unitWidth: CGFloat? = nil,
        rowHeight: CGFloat = 72,
        trailingPadding: CGFloat = 32
    ) {
        self.scale = scale
        self.labelWidth = labelWidth
        self.unitWidth = unitWidth ?? (scale == .week ? 34 : 72)
        self.rowHeight = rowHeight
        self.trailingPadding = trailingPadding
    }

    func trackWidth(for snapshot: PlanningTimelineSnapshot) -> CGFloat {
        offset(for: snapshot.timelineEnd, from: snapshot.timelineStart) + width(for: snapshot.timelineStart, end: snapshot.timelineEnd, kind: .task) + trailingPadding
    }

    func offset(for date: Date, from timelineStart: Date) -> CGFloat {
        CGFloat(unitIndex(for: date, from: timelineStart)) * unitWidth
    }

    func width(for start: Date, end: Date, kind: PlanningEntryKind) -> CGFloat {
        if kind == .milestone {
            return max(unitWidth * 0.68, 18)
        }

        let units = max(unitSpan(from: start, to: end), 1)
        return CGFloat(units) * unitWidth
    }

    func columnCount(for snapshot: PlanningTimelineSnapshot) -> Int {
        max(unitIndex(for: snapshot.timelineEnd, from: snapshot.timelineStart) + 1, 1)
    }

    func date(forColumn index: Int, start: Date) -> Date {
        switch scale {
        case .week:
            Calendar.current.date(byAdding: .day, value: index, to: start) ?? start
        case .month:
            Calendar.current.date(byAdding: .day, value: index * 7, to: start) ?? start
        }
    }

    private func unitIndex(for date: Date, from start: Date) -> Int {
        let dayCount = Calendar.current.dateComponents([.day], from: start, to: date).day ?? 0
        switch scale {
        case .week:
            return dayCount
        case .month:
            return max(Int(floor(Double(dayCount) / 7.0)), 0)
        }
    }

    private func unitSpan(from start: Date, to end: Date) -> Int {
        let dayCount = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        switch scale {
        case .week:
            return dayCount + 1
        case .month:
            return max(Int(ceil(Double(dayCount + 1) / 7.0)), 1)
        }
    }
}

struct PlanningTimelineHeaderView: View {
    @Environment(\.appTheme) private var theme
    let snapshot: PlanningTimelineSnapshot
    let geometry: TimelineGeometry

    var body: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: geometry.labelWidth, height: 48)

            ForEach(0..<geometry.columnCount(for: snapshot), id: \.self) { index in
                let date = geometry.date(forColumn: index, start: snapshot.timelineStart)
                Text(label(for: date))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                    .frame(width: geometry.unitWidth, height: 48)
            }
        }
    }

    private func label(for date: Date) -> String {
        switch geometry.scale {
        case .week:
            date.formatted(.dateTime.day().month(.abbreviated))
        case .month:
            date.formatted(.dateTime.day().month(.abbreviated))
        }
    }
}

struct PlanningTimelineRowView: View {
    @Environment(\.appTheme) private var theme
    let entry: PlanningTimelineEntry
    let snapshot: PlanningTimelineSnapshot
    let geometry: TimelineGeometry
    let isSelected: Bool
    var showsDependencySignals: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            PlanningTimelineLabelView(entry: entry, isSelected: isSelected)
                .frame(width: geometry.labelWidth, height: geometry.rowHeight, alignment: .leading)

            PlanningTimelineTrackView(
                entry: entry,
                snapshot: snapshot,
                geometry: geometry,
                isSelected: isSelected,
                showsDependencySignals: showsDependencySignals
            )
            .frame(width: geometry.trackWidth(for: snapshot), height: geometry.rowHeight, alignment: .leading)
        }
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? theme.selectionBottom.opacity(0.72) : .clear)
        )
    }
}

struct PlanningInspectorView: View {
    @Environment(\.appTheme) private var theme
    let inspector: PlanningInspectorContext?
    let openProjectsAction: ((PlanningInspectorContext) -> Void)?
    let setStatusAction: ((PlanningInspectorContext, ProjectStatus) -> Void)?
    let setPriorityAction: ((PlanningInspectorContext, PriorityLevel) -> Void)?
    let scheduleTodayAction: ((PlanningInspectorContext) -> Void)?
    let shiftScheduleAction: ((PlanningInspectorContext, Int) -> Void)?
    let clearScheduleAction: ((PlanningInspectorContext) -> Void)?
    let archiveProjectAction: ((PlanningInspectorContext) -> Void)?
    let restoreProjectAction: ((PlanningInspectorContext) -> Void)?
    let deleteEntryAction: ((PlanningInspectorContext) -> Void)?
    let removeDependencyAction: ((PlanningInspectorDependency) -> Void)?
    let isProjectArchived: ((PlanningInspectorContext) -> Bool)?

    init(
        inspector: PlanningInspectorContext?,
        openProjectsAction: ((PlanningInspectorContext) -> Void)? = nil,
        setStatusAction: ((PlanningInspectorContext, ProjectStatus) -> Void)? = nil,
        setPriorityAction: ((PlanningInspectorContext, PriorityLevel) -> Void)? = nil,
        scheduleTodayAction: ((PlanningInspectorContext) -> Void)? = nil,
        shiftScheduleAction: ((PlanningInspectorContext, Int) -> Void)? = nil,
        clearScheduleAction: ((PlanningInspectorContext) -> Void)? = nil,
        archiveProjectAction: ((PlanningInspectorContext) -> Void)? = nil,
        restoreProjectAction: ((PlanningInspectorContext) -> Void)? = nil,
        deleteEntryAction: ((PlanningInspectorContext) -> Void)? = nil,
        removeDependencyAction: ((PlanningInspectorDependency) -> Void)? = nil,
        isProjectArchived: ((PlanningInspectorContext) -> Bool)? = nil
    ) {
        self.inspector = inspector
        self.openProjectsAction = openProjectsAction
        self.setStatusAction = setStatusAction
        self.setPriorityAction = setPriorityAction
        self.scheduleTodayAction = scheduleTodayAction
        self.shiftScheduleAction = shiftScheduleAction
        self.clearScheduleAction = clearScheduleAction
        self.archiveProjectAction = archiveProjectAction
        self.restoreProjectAction = restoreProjectAction
        self.deleteEntryAction = deleteEntryAction
        self.removeDependencyAction = removeDependencyAction
        self.isProjectArchived = isProjectArchived
    }

    var body: some View {
        PanelCard(
            title: "Inspector",
            subtitle: "Selection shows the same planning item, dates, blockers, and dependencies used by Gantt and the dependency timeline."
        ) {
            if let inspector {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(inspector.title)
                            .font(.title3.weight(.semibold))
                        Text(inspector.projectTitle)
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                    }

                    HStack(spacing: 10) {
                        StatusBadge(status: inspector.status)
                        PriorityBadge(priority: inspector.priority)
                        PlanningKindBadge(kind: inspector.kind)
                    }

                    HStack(spacing: 16) {
                        MetricCard(
                            title: "Progress",
                            value: "\(Int(inspector.progress * 100))%",
                            systemImage: "chart.bar.fill",
                            tint: theme.projectColor(.cobalt)
                        )
                        MetricCard(
                            title: "Blocked Predecessors",
                            value: "\(inspector.blockedPredecessorCount)",
                            systemImage: "arrow.trianglehead.branch",
                            tint: theme.statusColor(.blocked)
                        )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Schedule")
                            .font(.headline)

                        Label(dateLabel(for: inspector), systemImage: "calendar")
                            .foregroundStyle(theme.secondaryText)
                        ScheduleSourceBadge(source: inspector.scheduleSource)

                        if inspector.hasIncompletePredecessors {
                            Label(
                                "\(inspector.blockedPredecessorCount) predecessor links are still open.",
                                systemImage: "exclamationmark.triangle.fill"
                            )
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.statusColor(.blocked))
                        }
                    }

                    if inspector.kind == .project {
                        HStack(spacing: 10) {
                            Label("\(inspector.openStepCount) open steps", systemImage: "list.bullet.rectangle")
                            Label("\(inspector.blockedStepCount) blocked steps", systemImage: "hand.raised.fill")
                        }
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                    }

                    if !inspector.upcomingMilestones.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Upcoming Milestones")
                                .font(.headline)

                            ForEach(inspector.upcomingMilestones) { milestone in
                                HStack {
                                    PlanningKindBadge(kind: milestone.kind)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(milestone.title)
                                            .font(.subheadline.weight(.semibold))
                                        Text(milestone.startDate, format: .dateTime.day().month(.abbreviated))
                                            .font(.caption)
                                            .foregroundStyle(theme.secondaryText)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }

                    if !inspector.incomingDependencies.isEmpty || !inspector.outgoingDependencies.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Dependencies")
                                .font(.headline)

                            if !inspector.incomingDependencies.isEmpty {
                                dependencySection(
                                    title: "Incoming",
                                    items: inspector.incomingDependencies
                                )
                            }

                            if !inspector.outgoingDependencies.isEmpty {
                                dependencySection(
                                    title: "Outgoing",
                                    items: inspector.outgoingDependencies
                                )
                            }
                        }
                    }

                    if showsActionStrip(for: inspector) {
                        inspectorActionStrip(for: inspector)
                    }
                }
            } else {
                EmptyStateView(
                    title: "No Timeline Selection",
                    message: "Select a project, task, or milestone to inspect blockers, dates, and dependency context.",
                    systemImage: "timeline.selection"
                )
            }
        }
    }

    @ViewBuilder
    private func dependencySection(
        title: String,
        items: [PlanningInspectorDependency]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.secondaryText)

            ForEach(items.prefix(4)) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: item.isBlocking ? "arrow.turn.down.right" : "arrow.right")
                        .foregroundStyle(item.isBlocking ? theme.statusColor(.blocked) : theme.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                        Text(item.subtitle)
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                        if !item.note.isEmpty {
                            Text(item.note)
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        Text(item.type.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(theme.secondaryText)

                        if let removeDependencyAction {
                            Button(role: .destructive) {
                                removeDependencyAction(item)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func inspectorActionStrip(for inspector: PlanningInspectorContext) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 10) {
                if let openProjectsAction {
                    Button("Open In Projects") {
                        openProjectsAction(inspector)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)
                }

                if let deleteEntryAction {
                    Button("Delete Permanently", role: .destructive) {
                        deleteEntryAction(inspector)
                    }
                    .buttonStyle(.bordered)
                }
            }

            HStack(spacing: 10) {
                if let setStatusAction {
                    CompactActionMenu(title: "Status", systemImage: "flag.fill", tint: theme.accent) {
                        ForEach(ProjectStatus.allCases) { status in
                            Button(status.title) {
                                setStatusAction(inspector, status)
                            }
                        }
                    }
                }

                if let setPriorityAction {
                    CompactActionMenu(title: "Priority", systemImage: "exclamationmark.circle") {
                        ForEach(PriorityLevel.allCases) { priority in
                            Button(priority.title) {
                                setPriorityAction(inspector, priority)
                            }
                        }
                    }
                }

                if scheduleTodayAction != nil || shiftScheduleAction != nil || clearScheduleAction != nil {
                    CompactActionMenu(title: "Schedule", systemImage: "calendar") {
                        if let scheduleTodayAction {
                            Button("Schedule Today") {
                                scheduleTodayAction(inspector)
                            }
                        }

                        if let shiftScheduleAction {
                            Button("Bring Forward 1 Week") {
                                shiftScheduleAction(inspector, -7)
                            }

                            Button("Push Back 1 Week") {
                                shiftScheduleAction(inspector, 7)
                            }
                        }

                        if let clearScheduleAction {
                            Button("Clear Dates") {
                                clearScheduleAction(inspector)
                            }
                        }
                    }
                }
            }

            if inspector.kind == .project {
                HStack(spacing: 12) {
                    if let isProjectArchived, isProjectArchived(inspector), let restoreProjectAction {
                        Button("Restore Project") {
                            restoreProjectAction(inspector)
                        }
                        .buttonStyle(.bordered)
                    } else if let archiveProjectAction {
                        Button("Archive Project") {
                            archiveProjectAction(inspector)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private func showsActionStrip(for inspector: PlanningInspectorContext) -> Bool {
        openProjectsAction != nil ||
        setStatusAction != nil ||
        setPriorityAction != nil ||
        scheduleTodayAction != nil ||
        shiftScheduleAction != nil ||
        clearScheduleAction != nil ||
        archiveProjectAction != nil ||
        restoreProjectAction != nil ||
        deleteEntryAction != nil
    }

    private func dateLabel(for inspector: PlanningInspectorContext) -> String {
        if Calendar.current.isDate(inspector.startDate, inSameDayAs: inspector.endDate) {
            return inspector.startDate.formatted(.dateTime.day().month(.abbreviated))
        }

        return "\(inspector.startDate.formatted(.dateTime.day().month(.abbreviated))) - \(inspector.endDate.formatted(.dateTime.day().month(.abbreviated)))"
    }
}

struct PlanningKindBadge: View {
    @Environment(\.appTheme) private var theme
    let kind: PlanningEntryKind

    var body: some View {
        Text(kind.title)
            .font(.caption.weight(.bold))
            .foregroundStyle(theme.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.insetBackground, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(theme.subtleStroke, lineWidth: 1)
            )
    }
}

struct ScheduleSourceBadge: View {
    @Environment(\.appTheme) private var theme
    let source: PlanningScheduleSource

    var body: some View {
        Text(source.title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(source.isDerived ? theme.priorityColor(.medium) : theme.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.insetBackground, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(theme.subtleStroke, lineWidth: 1)
            )
    }
}

private struct PlanningTimelineLabelView: View {
    @Environment(\.appTheme) private var theme
    let entry: PlanningTimelineEntry
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            marker
                .padding(.leading, CGFloat(entry.indentLevel) * 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(entry.kind == .project ? .headline : .subheadline.weight(.medium))
                    .foregroundStyle(isSelected ? theme.primaryText : theme.primaryText.opacity(0.94))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(entry.subtitle)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)

                    if entry.scheduleSource.isDerived {
                        ScheduleSourceBadge(source: entry.scheduleSource)
                    }
                }
            }

            Spacer(minLength: 10)

            if entry.hasIncompletePredecessors {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(theme.statusColor(.blocked))
            }
        }
        .padding(.horizontal, 14)
    }

    @ViewBuilder
    private var marker: some View {
        if entry.kind == .milestone {
            TimelineDiamond()
                .fill(theme.projectColor(entry.colorToken))
                .frame(width: 14, height: 14)
        } else {
            Circle()
                .fill(theme.projectColor(entry.colorToken))
                .frame(width: entry.kind == .project ? 12 : 8, height: entry.kind == .project ? 12 : 8)
        }
    }
}

private struct PlanningTimelineTrackView: View {
    @Environment(\.appTheme) private var theme
    let entry: PlanningTimelineEntry
    let snapshot: PlanningTimelineSnapshot
    let geometry: TimelineGeometry
    let isSelected: Bool
    let showsDependencySignals: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.insetBottom.opacity(0.45))
                .frame(width: geometry.trackWidth(for: snapshot), height: geometry.rowHeight - 20)

            todayMarker

            if entry.kind == .milestone {
                TimelineDiamond()
                    .fill(theme.projectColor(entry.colorToken))
                    .frame(width: 18, height: 18)
                    .overlay(
                        TimelineDiamond()
                            .stroke(isSelected ? theme.primaryText : .clear, lineWidth: 2)
                    )
                    .offset(x: barX + max(barWidth - 9, 0), y: (geometry.rowHeight - 18) / 2 - 1)
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.projectColor(entry.colorToken).opacity(entry.kind == .project ? 0.34 : 0.84))
                    .frame(width: max(barWidth, 12), height: entry.kind == .project ? 20 : 24)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(theme.projectColor(entry.colorToken))
                            .frame(width: max(barWidth * entry.progress, 12), height: entry.kind == .project ? 20 : 24)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(borderColor, style: StrokeStyle(lineWidth: 1.5, dash: entry.scheduleSource.isDerived ? [5, 4] : []))
                    )
                    .offset(x: barX, y: (geometry.rowHeight - 24) / 2 - 1)
            }

            if showsDependencySignals {
                dependencyCounters
                    .offset(x: max(barX + barWidth + 12, 0), y: (geometry.rowHeight - 28) / 2 - 1)
            }
        }
    }

    private var barX: CGFloat {
        geometry.offset(for: entry.startDate, from: snapshot.timelineStart)
    }

    private var barWidth: CGFloat {
        geometry.width(for: entry.startDate, end: entry.endDate, kind: entry.kind)
    }

    private var borderColor: Color {
        if entry.isBlocked {
            return theme.statusColor(.blocked)
        }
        if isSelected {
            return theme.primaryText.opacity(0.85)
        }
        return theme.primaryText.opacity(entry.scheduleSource.isDerived ? 0.38 : 0.08)
    }

    @ViewBuilder
    private var dependencyCounters: some View {
        HStack(spacing: 8) {
            if entry.predecessorCount > 0 {
                counter("\(entry.predecessorCount) in", tint: entry.hasIncompletePredecessors ? theme.statusColor(.blocked) : theme.accent)
            }
            if entry.successorCount > 0 {
                counter("\(entry.successorCount) out", tint: theme.projectColor(.cobalt))
            }
        }
    }

    private func counter(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(theme.insetBackground, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(theme.subtleStroke, lineWidth: 1)
            )
    }

    private var todayMarker: some View {
        Rectangle()
            .fill(theme.accent.opacity(0.45))
            .frame(width: 2, height: geometry.rowHeight - 10)
            .offset(x: geometry.offset(for: snapshot.today, from: snapshot.timelineStart))
    }
}

private struct TimelineDiamond: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.closeSubpath()
        }
    }
}
