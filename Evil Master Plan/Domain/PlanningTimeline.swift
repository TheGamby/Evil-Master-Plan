import Foundation

struct PlanningFilterState: Equatable {
    var showsCompletedItems: Bool = true
    var showsOnlyHighPriorityProjects: Bool = false
    var showsOnlyBlockedItems: Bool = false
    var showsOnlyLinkedItems: Bool = false
    var showsArchivedProjects: Bool = false
}

enum PlanningEntryKind: String, Identifiable {
    case project
    case task
    case milestone

    var id: String { rawValue }

    var title: String {
        switch self {
        case .project:
            "Project"
        case .task:
            "Task"
        case .milestone:
            "Milestone"
        }
    }
}

enum PlanningScheduleSource: String, Identifiable {
    case explicit
    case derivedFromChildren
    case derivedFromContainer
    case sequenceFallback

    var id: String { rawValue }

    var title: String {
        switch self {
        case .explicit:
            "Scheduled"
        case .derivedFromChildren:
            "From Child Items"
        case .derivedFromContainer:
            "From Project Dates"
        case .sequenceFallback:
            "Estimated"
        }
    }

    var isDerived: Bool {
        self != .explicit
    }
}

struct PlanningTimelineGroup: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let status: ProjectStatus
    let priority: PriorityLevel
    let colorToken: ProjectColorToken
}

struct PlanningTimelineEntry: Identifiable {
    let id: UUID
    let sourceReference: PlanningItemReference
    let projectID: UUID
    let projectTitle: String
    let title: String
    let subtitle: String
    let kind: PlanningEntryKind
    let status: ProjectStatus
    let priority: PriorityLevel
    let progress: Double
    let colorToken: ProjectColorToken
    let startDate: Date
    let endDate: Date
    let scheduleSource: PlanningScheduleSource
    let indentLevel: Int
    let sortOrder: Double
    let isBlocked: Bool
    let hasIncompletePredecessors: Bool
    let predecessorCount: Int
    let successorCount: Int
    let blockedPredecessorCount: Int
    let openStepCount: Int
    let blockedStepCount: Int

    var durationDays: Int {
        let value = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return max(value + 1, 1)
    }
}

struct PlanningDependencyEdge: Identifiable {
    let id: UUID
    let sourceReference: PlanningItemReference
    let targetReference: PlanningItemReference
    let sourceEntryID: UUID
    let targetEntryID: UUID
    let sourceTitle: String
    let sourceSubtitle: String
    let targetTitle: String
    let targetSubtitle: String
    let sourceProjectID: UUID
    let targetProjectID: UUID
    let type: DependencyType
    let note: String
    let isBlocking: Bool
}

struct PlanningTimelineSummary {
    let visibleProjectCount: Int
    let visibleEntryCount: Int
    let blockedEntryCount: Int
    let visibleDependencyCount: Int
    let derivedScheduleCount: Int
}

struct PlanningInspectorDependency: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let type: DependencyType
    let note: String
    let isBlocking: Bool
}

struct PlanningInspectorContext {
    let entryID: UUID
    let sourceReference: PlanningItemReference
    let projectID: UUID
    let title: String
    let projectTitle: String
    let kind: PlanningEntryKind
    let status: ProjectStatus
    let priority: PriorityLevel
    let progress: Double
    let startDate: Date
    let endDate: Date
    let scheduleSource: PlanningScheduleSource
    let isBlocked: Bool
    let hasIncompletePredecessors: Bool
    let predecessorCount: Int
    let successorCount: Int
    let blockedPredecessorCount: Int
    let openStepCount: Int
    let blockedStepCount: Int
    let upcomingMilestones: [PlanningTimelineEntry]
    let incomingDependencies: [PlanningInspectorDependency]
    let outgoingDependencies: [PlanningInspectorDependency]
}

struct PlanningTimelineSnapshot {
    let timelineStart: Date
    let timelineEnd: Date
    let groups: [PlanningTimelineGroup]
    let entries: [PlanningTimelineEntry]
    let edges: [PlanningDependencyEdge]
    let summary: PlanningTimelineSummary
    let scale: TimelineScale
    let today: Date

    func entry(id: UUID?) -> PlanningTimelineEntry? {
        guard let id else {
            return nil
        }
        return entries.first { $0.id == id }
    }

    func inspector(for selectedEntryID: UUID?) -> PlanningInspectorContext? {
        guard let entry = entry(id: selectedEntryID) else {
            return nil
        }

        let upcomingMilestones = entries
            .filter { candidate in
                candidate.projectID == entry.projectID &&
                candidate.kind == .milestone &&
                candidate.status.isOpen
            }
            .sorted {
                if $0.startDate == $1.startDate {
                    return $0.priority > $1.priority
                }
                return $0.startDate < $1.startDate
            }
            .prefix(3)

        let incomingDependencies = edges
            .filter { $0.targetEntryID == entry.id }
            .map {
                PlanningInspectorDependency(
                    id: $0.id,
                    title: $0.sourceTitle,
                    subtitle: $0.sourceSubtitle,
                    type: $0.type,
                    note: $0.note,
                    isBlocking: $0.isBlocking
                )
            }

        let outgoingDependencies = edges
            .filter { $0.sourceEntryID == entry.id }
            .map {
                PlanningInspectorDependency(
                    id: $0.id,
                    title: $0.targetTitle,
                    subtitle: $0.targetSubtitle,
                    type: $0.type,
                    note: $0.note,
                    isBlocking: $0.isBlocking
                )
            }

        return PlanningInspectorContext(
            entryID: entry.id,
            sourceReference: entry.sourceReference,
            projectID: entry.projectID,
            title: entry.title,
            projectTitle: entry.projectTitle,
            kind: entry.kind,
            status: entry.status,
            priority: entry.priority,
            progress: entry.progress,
            startDate: entry.startDate,
            endDate: entry.endDate,
            scheduleSource: entry.scheduleSource,
            isBlocked: entry.isBlocked,
            hasIncompletePredecessors: entry.hasIncompletePredecessors,
            predecessorCount: entry.predecessorCount,
            successorCount: entry.successorCount,
            blockedPredecessorCount: entry.blockedPredecessorCount,
            openStepCount: entry.openStepCount,
            blockedStepCount: entry.blockedStepCount,
            upcomingMilestones: Array(upcomingMilestones),
            incomingDependencies: incomingDependencies,
            outgoingDependencies: outgoingDependencies
        )
    }
}

struct PlanningResolver {
    private let projectsByID: [UUID: Project]
    private let stepsByID: [UUID: ProjectStep]
    private let incomingDependenciesByReference: [PlanningItemReference: [Dependency]]
    private let outgoingDependenciesByReference: [PlanningItemReference: [Dependency]]
    private let dependencyCounts: [PlanningItemReference: Int]

    init(projects: [Project], dependencies: [Dependency]) {
        let projectsLookup = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
        let stepsLookup = Dictionary(
            uniqueKeysWithValues: projects.flatMap { project in
                project.steps.map { ($0.id, $0) }
            }
        )
        projectsByID = projectsLookup
        stepsByID = stepsLookup

        var incoming: [PlanningItemReference: [Dependency]] = [:]
        var outgoing: [PlanningItemReference: [Dependency]] = [:]
        var counts: [PlanningItemReference: Int] = [:]

        for dependency in dependencies where !dependency.isSelfReference {
            let source = dependency.sourceReference
            let target = dependency.targetReference
            let sourceExists: Bool
            switch source.kind {
            case .project:
                sourceExists = projectsLookup[source.id] != nil
            case .step:
                sourceExists = stepsLookup[source.id] != nil
            }

            let targetExists: Bool
            switch target.kind {
            case .project:
                targetExists = projectsLookup[target.id] != nil
            case .step:
                targetExists = stepsLookup[target.id] != nil
            }

            guard sourceExists, targetExists else {
                continue
            }

            incoming[target, default: []].append(dependency)
            outgoing[source, default: []].append(dependency)
            counts[source, default: 0] += 1
            counts[target, default: 0] += 1
        }

        incomingDependenciesByReference = incoming
        outgoingDependenciesByReference = outgoing
        dependencyCounts = counts
    }

    func contains(_ reference: PlanningItemReference) -> Bool {
        switch reference.kind {
        case .project:
            projectsByID[reference.id] != nil
        case .step:
            stepsByID[reference.id] != nil
        }
    }

    func project(id: UUID) -> Project? {
        projectsByID[id]
    }

    func step(id: UUID) -> ProjectStep? {
        stepsByID[id]
    }

    func title(for reference: PlanningItemReference) -> String {
        switch reference.kind {
        case .project:
            projectsByID[reference.id]?.title ?? "Unknown Project"
        case .step:
            stepsByID[reference.id]?.title ?? "Unknown Step"
        }
    }

    func subtitle(for reference: PlanningItemReference) -> String {
        switch reference.kind {
        case .project:
            "Project"
        case .step:
            stepsByID[reference.id]?.project?.title ?? "Project Step"
        }
    }

    func projectID(for reference: PlanningItemReference) -> UUID? {
        switch reference.kind {
        case .project:
            reference.id
        case .step:
            stepsByID[reference.id]?.project?.id
        }
    }

    func color(for reference: PlanningItemReference) -> ProjectColorToken {
        switch reference.kind {
        case .project:
            projectsByID[reference.id]?.colorToken ?? .ember
        case .step:
            stepsByID[reference.id]?.project?.colorToken ?? .ember
        }
    }

    func status(for reference: PlanningItemReference) -> ProjectStatus {
        switch reference.kind {
        case .project:
            projectsByID[reference.id]?.status ?? .idea
        case .step:
            stepsByID[reference.id]?.status ?? .idea
        }
    }

    func priority(for reference: PlanningItemReference) -> PriorityLevel {
        switch reference.kind {
        case .project:
            projectsByID[reference.id]?.priority ?? .medium
        case .step:
            stepsByID[reference.id]?.priority ?? .medium
        }
    }

    func progress(for reference: PlanningItemReference) -> Double {
        switch reference.kind {
        case .project:
            projectsByID[reference.id]?.progress ?? 0
        case .step:
            stepsByID[reference.id]?.progress ?? 0
        }
    }

    func dependencyCount(for reference: PlanningItemReference) -> Int {
        dependencyCounts[reference, default: 0]
    }

    func incomingDependencies(for reference: PlanningItemReference) -> [Dependency] {
        incomingDependenciesByReference[reference, default: []]
    }

    func outgoingDependencies(for reference: PlanningItemReference) -> [Dependency] {
        outgoingDependenciesByReference[reference, default: []]
    }

    func unresolvedPredecessorCount(for reference: PlanningItemReference) -> Int {
        incomingDependencies(for: reference).filter { isBlocking($0) }.count
    }

    func isBlocked(_ reference: PlanningItemReference) -> Bool {
        switch reference.kind {
        case .project:
            guard let project = projectsByID[reference.id] else {
                return false
            }
            if project.status == .blocked || unresolvedPredecessorCount(for: reference) > 0 {
                return true
            }
            return project.steps.contains { step in
                isBlocked(PlanningItemReference(kind: .step, id: step.id))
            }
        case .step:
            guard let step = stepsByID[reference.id] else {
                return false
            }
            return step.status == .blocked || unresolvedPredecessorCount(for: reference) > 0
        }
    }

    func isBlocking(_ dependency: Dependency) -> Bool {
        guard contains(dependency.sourceReference), contains(dependency.targetReference) else {
            return false
        }

        switch dependency.type {
        case .finishToStart, .finishToFinish:
            return !isCompleted(dependency.sourceReference)
        case .startToStart:
            return !hasStarted(dependency.sourceReference)
        }
    }

    private func hasStarted(_ reference: PlanningItemReference) -> Bool {
        switch reference.kind {
        case .project:
            guard let project = projectsByID[reference.id] else {
                return false
            }
            return project.progress > 0.001 || project.status.countsAsStarted
        case .step:
            guard let step = stepsByID[reference.id] else {
                return false
            }
            return step.progress > 0.001 || step.status.countsAsStarted
        }
    }

    private func isCompleted(_ reference: PlanningItemReference) -> Bool {
        switch reference.kind {
        case .project:
            guard let project = projectsByID[reference.id] else {
                return false
            }
            return project.progress >= 0.999 || project.status.countsAsCompleted
        case .step:
            guard let step = stepsByID[reference.id] else {
                return false
            }
            return step.progress >= 0.999 || step.status.countsAsCompleted
        }
    }
}

enum PlanningTimelineBuilder {
    static func snapshot(
        projects: [Project],
        dependencies: [Dependency],
        filter: PlanningFilterState,
        scale: TimelineScale,
        projectSortCriterion: ProjectSortCriterion,
        now: Date = .now
    ) -> PlanningTimelineSnapshot {
        let visibleProjects = filteredProjects(from: projects, filter: filter)
        let resolver = PlanningResolver(projects: visibleProjects, dependencies: dependencies)
        let sortedProjects = sortProjects(visibleProjects, criterion: projectSortCriterion)

        var stepEntries = buildStepEntries(
            from: sortedProjects,
            resolver: resolver,
            showsCompletedItems: filter.showsCompletedItems
        )

        var projectEntries = buildProjectEntries(
            from: sortedProjects,
            stepEntries: stepEntries,
            resolver: resolver,
            now: now
        )

        stepEntries = shiftDerivedSchedules(
            stepEntries,
            projectEntries: projectEntries,
            resolver: resolver
        )

        projectEntries = buildProjectEntries(
            from: sortedProjects,
            stepEntries: stepEntries,
            resolver: resolver,
            now: now
        )

        let allEntries = projectEntries + stepEntries
        let allEdges = buildEdges(from: allEntries, resolver: resolver)
        let visibleEntries = filteredEntries(
            from: allEntries,
            edges: allEdges,
            filter: filter
        )
        let visibleEntryIDs = Set(visibleEntries.map(\.id))
        let visibleEdges = allEdges.filter {
            visibleEntryIDs.contains($0.sourceEntryID) && visibleEntryIDs.contains($0.targetEntryID)
        }
        let visibleProjectIDs = Set(visibleEntries.map(\.projectID))
        let projectOrder = Dictionary(uniqueKeysWithValues: sortedProjects.enumerated().map { ($1.id, $0) })

        let groups = sortedProjects.compactMap { project -> PlanningTimelineGroup? in
            guard visibleProjectIDs.contains(project.id) else {
                return nil
            }

            return PlanningTimelineGroup(
                id: project.id,
                title: project.title,
                subtitle: "\(project.openStepCount) open steps",
                status: project.status,
                priority: project.priority,
                colorToken: project.colorToken
            )
        }

        let calendar = Calendar.current
        let allDates = visibleEntries.flatMap { [$0.startDate, $0.endDate] } + [calendar.startOfDay(for: now)]
        let start = allDates.min() ?? calendar.startOfDay(for: now)
        let end = allDates.max() ?? calendar.date(byAdding: .day, value: 14, to: start) ?? start

        return PlanningTimelineSnapshot(
            timelineStart: calendar.startOfDay(for: start),
            timelineEnd: calendar.startOfDay(for: end),
            groups: groups,
            entries: sortEntries(visibleEntries, projectOrder: projectOrder),
            edges: visibleEdges,
            summary: PlanningTimelineSummary(
                visibleProjectCount: groups.count,
                visibleEntryCount: visibleEntries.count,
                blockedEntryCount: visibleEntries.filter(\.isBlocked).count,
                visibleDependencyCount: visibleEdges.count,
                derivedScheduleCount: visibleEntries.filter { $0.scheduleSource.isDerived }.count
            ),
            scale: scale,
            today: calendar.startOfDay(for: now)
        )
    }

    private static func filteredProjects(from projects: [Project], filter: PlanningFilterState) -> [Project] {
        projects.filter { project in
            if !filter.showsArchivedProjects && project.isArchived {
                return false
            }

            if filter.showsOnlyHighPriorityProjects && !project.isHighPriority {
                return false
            }

            if !filter.showsCompletedItems && project.status == .done && project.openStepCount == 0 {
                return false
            }

            return true
        }
    }

    private static func sortProjects(_ projects: [Project], criterion: ProjectSortCriterion) -> [Project] {
        projects.sorted { lhs, rhs in
            switch criterion {
            case .updatedAt:
                if lhs.updatedAt == rhs.updatedAt {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                return lhs.updatedAt > rhs.updatedAt
            case .priority:
                if lhs.priority == rhs.priority {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.priority > rhs.priority
            case .dueDate:
                let lhsDate = lhs.resolvedDueDate ?? .distantFuture
                let rhsDate = rhs.resolvedDueDate ?? .distantFuture
                if lhsDate == rhsDate {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhsDate < rhsDate
            case .progress:
                if abs(lhs.progress - rhs.progress) < 0.001 {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.progress > rhs.progress
            }
        }
    }

    private static func buildStepEntries(
        from projects: [Project],
        resolver: PlanningResolver,
        showsCompletedItems: Bool
    ) -> [PlanningTimelineEntry] {
        var result: [PlanningTimelineEntry] = []

        for project in projects {
            for (index, step) in project.sortedSteps.enumerated() {
                if !showsCompletedItems && !step.status.isOpen {
                    continue
                }

                let schedule = resolveStepSchedule(step, in: project, index: index)
                let reference = PlanningItemReference(kind: .step, id: step.id)
                let blockedPredecessorCount = resolver.unresolvedPredecessorCount(for: reference)

                result.append(
                    PlanningTimelineEntry(
                        id: step.id,
                        sourceReference: reference,
                        projectID: project.id,
                        projectTitle: project.title,
                        title: step.title,
                        subtitle: step.kind.title,
                        kind: step.isMilestone ? .milestone : .task,
                        status: step.status,
                        priority: step.priority,
                        progress: step.progress,
                        colorToken: project.colorToken,
                        startDate: schedule.start,
                        endDate: schedule.end,
                        scheduleSource: schedule.source,
                        indentLevel: 1,
                        sortOrder: step.sortOrder,
                        isBlocked: resolver.isBlocked(reference),
                        hasIncompletePredecessors: blockedPredecessorCount > 0,
                        predecessorCount: resolver.incomingDependencies(for: reference).count,
                        successorCount: resolver.outgoingDependencies(for: reference).count,
                        blockedPredecessorCount: blockedPredecessorCount,
                        openStepCount: step.isOpen ? 1 : 0,
                        blockedStepCount: step.status == .blocked ? 1 : 0
                    )
                )
            }
        }

        return result
    }

    private static func buildProjectEntries(
        from projects: [Project],
        stepEntries: [PlanningTimelineEntry],
        resolver: PlanningResolver,
        now: Date
    ) -> [PlanningTimelineEntry] {
        let stepEntriesByProjectID = Dictionary(grouping: stepEntries, by: \.projectID)

        return projects.map { project in
            let reference = PlanningItemReference(kind: .project, id: project.id)
            let projectSteps = stepEntriesByProjectID[project.id, default: []]
            let schedule = resolveProjectSchedule(project, stepEntries: projectSteps, now: now)
            let blockedPredecessorCount = resolver.unresolvedPredecessorCount(for: reference)
            let blockedChildren = projectSteps.filter(\.isBlocked).count

            return PlanningTimelineEntry(
                id: project.id,
                sourceReference: reference,
                projectID: project.id,
                projectTitle: project.title,
                title: project.title,
                subtitle: project.summary.isEmpty ? project.priority.title : project.summary,
                kind: .project,
                status: project.status,
                priority: project.priority,
                progress: project.progress,
                colorToken: project.colorToken,
                startDate: schedule.start,
                endDate: schedule.end,
                scheduleSource: schedule.source,
                indentLevel: 0,
                sortOrder: -1,
                isBlocked: resolver.isBlocked(reference) || blockedChildren > 0,
                hasIncompletePredecessors: blockedPredecessorCount > 0,
                predecessorCount: resolver.incomingDependencies(for: reference).count,
                successorCount: resolver.outgoingDependencies(for: reference).count,
                blockedPredecessorCount: blockedPredecessorCount,
                openStepCount: project.openStepCount,
                blockedStepCount: max(project.blockedStepCount, blockedChildren)
            )
        }
    }

    private static func shiftDerivedSchedules(
        _ stepEntries: [PlanningTimelineEntry],
        projectEntries: [PlanningTimelineEntry],
        resolver: PlanningResolver
    ) -> [PlanningTimelineEntry] {
        var entriesByReference = Dictionary(
            uniqueKeysWithValues: (projectEntries + stepEntries).map { ($0.sourceReference, $0) }
        )
        var adjustedEntries = stepEntries

        for index in adjustedEntries.indices {
            let entry = adjustedEntries[index]
            guard entry.scheduleSource != .explicit else {
                continue
            }

            let anchors = resolver.incomingDependencies(for: entry.sourceReference).compactMap { dependency -> Date? in
                guard let source = entriesByReference[dependency.sourceReference] else {
                    return nil
                }

                switch dependency.type {
                case .finishToStart, .finishToFinish:
                    return source.endDate
                case .startToStart:
                    return source.startDate
                }
            }

            guard let anchor = anchors.max(), anchor > entry.startDate else {
                continue
            }

            let shifted = entry.shifted(toStartOnOrAfter: anchor)
            adjustedEntries[index] = shifted
            entriesByReference[shifted.sourceReference] = shifted
        }

        return adjustedEntries
    }

    private static func buildEdges(
        from entries: [PlanningTimelineEntry],
        resolver: PlanningResolver
    ) -> [PlanningDependencyEdge] {
        let entriesByReference = Dictionary(uniqueKeysWithValues: entries.map { ($0.sourceReference, $0) })

        return entries.compactMap { entry in
            resolver.outgoingDependencies(for: entry.sourceReference).compactMap { dependency -> PlanningDependencyEdge? in
                guard
                    let source = entriesByReference[dependency.sourceReference],
                    let target = entriesByReference[dependency.targetReference]
                else {
                    return nil
                }

                return PlanningDependencyEdge(
                    id: dependency.id,
                    sourceReference: dependency.sourceReference,
                    targetReference: dependency.targetReference,
                    sourceEntryID: source.id,
                    targetEntryID: target.id,
                    sourceTitle: source.title,
                    sourceSubtitle: source.subtitle,
                    targetTitle: target.title,
                    targetSubtitle: target.subtitle,
                    sourceProjectID: source.projectID,
                    targetProjectID: target.projectID,
                    type: dependency.type,
                    note: dependency.note,
                    isBlocking: resolver.isBlocking(dependency)
                )
            }
        }
        .flatMap { $0 }
    }

    private static func filteredEntries(
        from entries: [PlanningTimelineEntry],
        edges: [PlanningDependencyEdge],
        filter: PlanningFilterState
    ) -> [PlanningTimelineEntry] {
        let linkedIDs = Set(edges.flatMap { [$0.sourceEntryID, $0.targetEntryID] })
        let projectEntries = Dictionary(uniqueKeysWithValues: entries.filter { $0.kind == .project }.map { ($0.projectID, $0) })

        var visibleIDs = Set(entries.compactMap { entry -> UUID? in
            if filter.showsOnlyBlockedItems && !entry.isBlocked {
                return nil
            }

            if filter.showsOnlyLinkedItems && !linkedIDs.contains(entry.id) {
                return nil
            }

            return entry.id
        })

        for entry in entries where entry.kind != .project && visibleIDs.contains(entry.id) {
            visibleIDs.insert(entry.projectID)
        }

        return entries.filter { entry in
            if visibleIDs.contains(entry.id) {
                return true
            }

            guard entry.kind == .project else {
                return false
            }

            return projectEntries[entry.projectID]?.id == entry.id && visibleIDs.contains(entry.id)
        }
    }

    private static func sortEntries(
        _ entries: [PlanningTimelineEntry],
        projectOrder: [UUID: Int]
    ) -> [PlanningTimelineEntry] {
        entries.sorted { lhs, rhs in
            if lhs.projectID != rhs.projectID {
                let lhsOrder = projectOrder[lhs.projectID] ?? .max
                let rhsOrder = projectOrder[rhs.projectID] ?? .max
                if lhsOrder != rhsOrder {
                    return lhsOrder < rhsOrder
                }
                return lhs.projectTitle.localizedCaseInsensitiveCompare(rhs.projectTitle) == .orderedAscending
            }

            if lhs.indentLevel != rhs.indentLevel {
                return lhs.indentLevel < rhs.indentLevel
            }

            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }

            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private static func resolveProjectSchedule(
        _ project: Project,
        stepEntries: [PlanningTimelineEntry],
        now: Date
    ) -> (start: Date, end: Date, source: PlanningScheduleSource) {
        let calendar = Calendar.current

        if project.startDate != nil || project.dueDate != nil {
            let start = project.startDate ?? stepEntries.map(\.startDate).min() ?? project.createdAt
            let end = max(project.dueDate ?? stepEntries.map(\.endDate).max() ?? start, start)
            return (calendar.startOfDay(for: start), calendar.startOfDay(for: end), .explicit)
        }

        if !stepEntries.isEmpty {
            let start = stepEntries.map(\.startDate).min() ?? calendar.startOfDay(for: now)
            let end = stepEntries.map(\.endDate).max() ?? start
            return (calendar.startOfDay(for: start), calendar.startOfDay(for: end), .derivedFromChildren)
        }

        let start = calendar.startOfDay(for: project.createdAt)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return (start, end, .sequenceFallback)
    }

    private static func resolveStepSchedule(
        _ step: ProjectStep,
        in project: Project,
        index: Int
    ) -> (start: Date, end: Date, source: PlanningScheduleSource) {
        let calendar = Calendar.current
        let fallbackDuration = step.isMilestone ? 0 : 3

        if let startDate = step.startDate, let dueDate = step.dueDate {
            let start = calendar.startOfDay(for: startDate)
            let end = calendar.startOfDay(for: max(dueDate, startDate))
            return (start, step.isMilestone ? start : end, .explicit)
        }

        if let startDate = step.startDate {
            let start = calendar.startOfDay(for: startDate)
            let end = step.isMilestone
                ? start
                : calendar.date(byAdding: .day, value: fallbackDuration, to: start) ?? start
            return (start, calendar.startOfDay(for: end), .explicit)
        }

        if let dueDate = step.dueDate {
            let end = calendar.startOfDay(for: dueDate)
            let start = step.isMilestone
                ? end
                : calendar.date(byAdding: .day, value: -fallbackDuration, to: end) ?? end
            return (calendar.startOfDay(for: start), end, .explicit)
        }

        if let projectStart = project.startDate ?? project.resolvedStartDate {
            let start = calendar.date(byAdding: .day, value: index * 3, to: calendar.startOfDay(for: projectStart)) ?? projectStart
            if step.isMilestone {
                let milestoneDate = project.dueDate.map { calendar.startOfDay(for: $0) } ?? calendar.startOfDay(for: start)
                return (milestoneDate, milestoneDate, .derivedFromContainer)
            }
            let end = project.dueDate.flatMap {
                min(calendar.startOfDay(for: $0), calendar.date(byAdding: .day, value: fallbackDuration, to: calendar.startOfDay(for: start)) ?? start)
            } ?? (calendar.date(byAdding: .day, value: fallbackDuration, to: calendar.startOfDay(for: start)) ?? start)
            return (calendar.startOfDay(for: start), calendar.startOfDay(for: max(end, start)), .derivedFromContainer)
        }

        let baseline = calendar.startOfDay(for: project.createdAt)
        let start = calendar.date(byAdding: .day, value: index * 4, to: baseline) ?? baseline
        if step.isMilestone {
            return (calendar.startOfDay(for: start), calendar.startOfDay(for: start), .sequenceFallback)
        }
        let end = calendar.date(byAdding: .day, value: fallbackDuration, to: calendar.startOfDay(for: start)) ?? start
        return (calendar.startOfDay(for: start), calendar.startOfDay(for: end), .sequenceFallback)
    }
}

private extension PlanningTimelineEntry {
    func shifted(toStartOnOrAfter anchor: Date) -> PlanningTimelineEntry {
        guard anchor > startDate else {
            return self
        }

        let durationOffset = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        let normalizedStart = Calendar.current.startOfDay(for: anchor)
        let normalizedEnd = kind == .milestone
            ? normalizedStart
            : Calendar.current.date(byAdding: .day, value: max(durationOffset, 0), to: normalizedStart) ?? normalizedStart

        return PlanningTimelineEntry(
            id: id,
            sourceReference: sourceReference,
            projectID: projectID,
            projectTitle: projectTitle,
            title: title,
            subtitle: subtitle,
            kind: kind,
            status: status,
            priority: priority,
            progress: progress,
            colorToken: colorToken,
            startDate: normalizedStart,
            endDate: normalizedEnd,
            scheduleSource: scheduleSource,
            indentLevel: indentLevel,
            sortOrder: sortOrder,
            isBlocked: isBlocked,
            hasIncompletePredecessors: hasIncompletePredecessors,
            predecessorCount: predecessorCount,
            successorCount: successorCount,
            blockedPredecessorCount: blockedPredecessorCount,
            openStepCount: openStepCount,
            blockedStepCount: blockedStepCount
        )
    }
}
