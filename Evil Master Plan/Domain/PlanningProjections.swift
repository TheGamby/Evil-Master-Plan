import Foundation

struct InboxSectionSnapshot: Identifiable {
    let state: IdeaInboxState
    let items: [IdeaInboxItem]

    var id: String { state.rawValue }
    var title: String { state.title }
}

struct InboxSnapshot {
    let newCount: Int
    let reviewingCount: Int
    let convertedCount: Int
    let archivedCount: Int
    let triageCount: Int
    let sections: [InboxSectionSnapshot]
    let defaultItemID: UUID?
}

enum InboxProjectionFactory {
    static func snapshot(items: [IdeaInboxItem], filter: InboxListFilter) -> InboxSnapshot {
        let orderedItems = items.sorted(by: inboxComesBefore(_:_:))
        let sections = sectionStates(for: filter).map { state in
            InboxSectionSnapshot(
                state: state,
                items: orderedItems.filter { $0.state == state }
            )
        }

        return InboxSnapshot(
            newCount: items.filter { $0.state == .open }.count,
            reviewingCount: items.filter { $0.state == .reviewing }.count,
            convertedCount: items.filter { $0.state == .converted }.count,
            archivedCount: items.filter { $0.state == .archived }.count,
            triageCount: items.filter { $0.state.needsTriage }.count,
            sections: sections.filter { !$0.items.isEmpty || filter == .all || $0.state.needsTriage },
            defaultItemID: orderedItems.first(where: { $0.state.needsTriage })?.id ?? orderedItems.first?.id
        )
    }

    private static func sectionStates(for filter: InboxListFilter) -> [IdeaInboxState] {
        switch filter {
        case .triage:
            [.open, .reviewing]
        case .reviewing:
            [.reviewing]
        case .converted:
            [.converted]
        case .archived:
            [.archived]
        case .all:
            [.open, .reviewing, .converted, .archived]
        }
    }

    nonisolated private static func inboxComesBefore(_ lhs: IdeaInboxItem, _ rhs: IdeaInboxItem) -> Bool {
        if lhs.state.sortRank != rhs.state.sortRank {
            return lhs.state.sortRank < rhs.state.sortRank
        }

        let lhsPriority = lhs.priorityHint?.rank ?? -1
        let rhsPriority = rhs.priorityHint?.rank ?? -1
        if lhsPriority != rhsPriority {
            return lhsPriority > rhsPriority
        }

        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }

        return lhs.createdAt > rhs.createdAt
    }
}

struct InboxProjectConversionDraft {
    var title: String
    var summary: String
    var status: ProjectStatus
    var priority: PriorityLevel
    var colorToken: ProjectColorToken
    var tags: [String]
}

struct InboxStepConversionDraft {
    let project: Project
    var title: String
    var notes: String
    var kind: ProjectStepKind
    var status: ProjectStatus
    var priority: PriorityLevel
    var startDate: Date?
    var dueDate: Date?
}

enum InboxConversionRequest {
    case newProject(InboxProjectConversionDraft)
    case projectStep(InboxStepConversionDraft)
}

struct InboxConversionResult {
    let targetProject: Project
    let targetStep: ProjectStep?
    let createdProject: Project?
    let conversionTarget: IdeaInboxConversionTarget
}

enum InboxWorkflow {
    static func makeProjectDraft(for item: IdeaInboxItem) -> InboxProjectConversionDraft {
        InboxProjectConversionDraft(
            title: item.title.trimmingCharacters(in: .whitespacesAndNewlines),
            summary: item.trimmedBody,
            status: .idea,
            priority: item.priorityHint ?? .medium,
            colorToken: .cobalt,
            tags: normalizedTags(item.tags + ["inbox"])
        )
    }

    static func makeStepDraft(for item: IdeaInboxItem, project: Project) -> InboxStepConversionDraft {
        InboxStepConversionDraft(
            project: project,
            title: item.title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: item.trimmedBody,
            kind: .task,
            status: .idea,
            priority: item.priorityHint ?? project.priority,
            startDate: project.startDate,
            dueDate: project.dueDate
        )
    }

    static func convert(
        _ item: IdeaInboxItem,
        using request: InboxConversionRequest,
        now: Date = .now
    ) -> InboxConversionResult {
        switch request {
        case .newProject(let draft):
            let project = Project.starter(title: sanitizedTitle(draft.title, fallback: item.title), now: now)
            let summary = draft.summary.trimmingCharacters(in: .whitespacesAndNewlines)

            project.summary = summary.isEmpty ? (item.trimmedBody.isEmpty ? project.summary : item.trimmedBody) : summary
            project.status = draft.status
            project.priority = draft.priority
            project.colorToken = draft.colorToken
            project.tags = normalizedTags(draft.tags + item.tags + ["inbox"])
            project.touch(at: now)
            item.markConverted(target: .project, project: project, at: now)

            return InboxConversionResult(
                targetProject: project,
                targetStep: nil,
                createdProject: project,
                conversionTarget: .project
            )

        case .projectStep(let draft):
            let step = draft.project.addStep(
                title: sanitizedTitle(draft.title, fallback: item.title),
                notes: draft.notes.trimmingCharacters(in: .whitespacesAndNewlines),
                status: draft.status,
                priority: draft.priority,
                progress: 0,
                startDate: draft.startDate,
                dueDate: draft.dueDate,
                kind: draft.kind
            )

            draft.project.mergeTags(item.tags)
            let target: IdeaInboxConversionTarget = draft.kind == .milestone ? .milestone : .task
            item.markConverted(target: target, project: draft.project, step: step, at: now)

            return InboxConversionResult(
                targetProject: draft.project,
                targetStep: step,
                createdProject: nil,
                conversionTarget: target
            )
        }
    }

    private static func sanitizedTitle(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }

        let fallbackTrimmed = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        return fallbackTrimmed.isEmpty ? "Inbox Conversion" : fallbackTrimmed
    }

    private static func normalizedTags(_ rawTags: [String]) -> [String] {
        var seen = Set<String>()

        return rawTags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0.lowercased()).inserted }
    }
}

enum FocusDestination: Hashable {
    case project(UUID)
    case step(projectID: UUID, stepID: UUID)
    case inbox(UUID)
}

struct FocusCandidate: Identifiable {
    let id: String
    let kind: FocusItemKind
    let title: String
    let subtitle: String
    let detail: String
    let reason: String
    let status: ProjectStatus?
    let priority: PriorityLevel?
    let dueDate: Date?
    let destination: FocusDestination
    let isBlocked: Bool
    let score: Int
}

struct FocusSectionSnapshot: Identifiable {
    let kind: FocusSectionKind
    let items: [FocusCandidate]

    var id: String { kind.rawValue }
    var title: String { kind.title }
    var subtitle: String { kind.subtitle }
}

struct FocusSnapshot {
    let activeProjectCount: Int
    let blockedItemCount: Int
    let triageCount: Int
    let soonMilestoneCount: Int
    let sections: [FocusSectionSnapshot]
}

enum FocusProjectionFactory {
    static func snapshot(
        projects: [Project],
        dependencies: [Dependency],
        inboxItems: [IdeaInboxItem],
        now: Date = .now
    ) -> FocusSnapshot {
        let activeProjects = projects.filter { !$0.isArchived }
        let resolver = PlanningResolver(projects: activeProjects, dependencies: dependencies)
        let nowImportant = buildNowImportant(projects: activeProjects, resolver: resolver, now: now)
        let blocked = buildBlocked(projects: activeProjects, resolver: resolver, now: now)
        let nextSteps = buildNextSteps(projects: activeProjects, resolver: resolver, now: now)
        let milestones = buildMilestones(projects: activeProjects, resolver: resolver, now: now)
        let inbox = buildInbox(items: inboxItems, now: now)

        return FocusSnapshot(
            activeProjectCount: activeProjects.filter { $0.status == .active }.count,
            blockedItemCount: blocked.count,
            triageCount: inboxItems.filter { $0.state.needsTriage }.count,
            soonMilestoneCount: milestones.count,
            sections: [
                FocusSectionSnapshot(kind: .nowImportant, items: nowImportant),
                FocusSectionSnapshot(kind: .blocked, items: blocked),
                FocusSectionSnapshot(kind: .nextSteps, items: nextSteps),
                FocusSectionSnapshot(kind: .inbox, items: inbox),
                FocusSectionSnapshot(kind: .milestones, items: milestones),
            ]
        )
    }

    private static func buildNowImportant(
        projects: [Project],
        resolver: PlanningResolver,
        now: Date
    ) -> [FocusCandidate] {
        projects
            .filter { project in
                let reference = PlanningItemReference(kind: .project, id: project.id)
                let recentThreshold = calendar.date(byAdding: .day, value: -3, to: now) ?? now
                guard project.status.isOpen, !resolver.isBlocked(reference) else {
                    return false
                }

                return project.status == .active ||
                    project.isHighPriority ||
                    urgencyScore(for: project.resolvedDueDate, now: now) > 0 ||
                    project.updatedAt >= recentThreshold
            }
            .map { project in
                FocusCandidate(
                    id: "project-\(project.id.uuidString)",
                    kind: .project,
                    title: project.title,
                    subtitle: focusProjectSubtitle(project),
                    detail: project.summary,
                    reason: focusProjectReason(project, now: now),
                    status: project.status,
                    priority: project.priority,
                    dueDate: project.resolvedDueDate,
                    destination: .project(project.id),
                    isBlocked: false,
                    score: projectScore(project, now: now)
                )
            }
            .sorted(by: candidateComesBefore(_:_:))
            .prefix(4)
            .map(\.self)
    }

    private static func buildBlocked(
        projects: [Project],
        resolver: PlanningResolver,
        now: Date
    ) -> [FocusCandidate] {
        let blockedProjects = projects
            .filter { resolver.isBlocked(PlanningItemReference(kind: .project, id: $0.id)) }
            .map { project in
                let reference = PlanningItemReference(kind: .project, id: project.id)
                return FocusCandidate(
                    id: "project-\(project.id.uuidString)",
                    kind: .project,
                    title: project.title,
                    subtitle: focusProjectSubtitle(project),
                    detail: project.summary,
                    reason: blockedReason(
                        directBlocked: project.status == .blocked,
                        dependencyBlocked: resolver.unresolvedPredecessorCount(for: reference) > 0,
                        blockedChildCount: project.blockedStepCount
                    ),
                    status: project.status,
                    priority: project.priority,
                    dueDate: project.resolvedDueDate,
                    destination: .project(project.id),
                    isBlocked: true,
                    score: projectScore(project, now: now) + 30
                )
            }

        let blockedSteps = projects.flatMap { project in
            project.sortedSteps.compactMap { step -> FocusCandidate? in
                let projectReference = PlanningItemReference(kind: .project, id: project.id)
                let stepReference = PlanningItemReference(kind: .step, id: step.id)

                guard step.status.isOpen,
                      resolver.isBlocked(stepReference),
                      !resolver.isBlocked(projectReference)
                else {
                    return nil
                }

                return FocusCandidate(
                    id: "step-\(step.id.uuidString)",
                    kind: step.isMilestone ? .milestone : .step,
                    title: step.title,
                    subtitle: project.title,
                    detail: step.notes,
                    reason: blockedReason(
                        directBlocked: step.status == .blocked,
                        dependencyBlocked: resolver.unresolvedPredecessorCount(for: stepReference) > 0,
                        blockedChildCount: 0
                    ),
                    status: step.status,
                    priority: step.priority,
                    dueDate: step.dueDate ?? project.resolvedDueDate,
                    destination: .step(projectID: project.id, stepID: step.id),
                    isBlocked: true,
                    score: stepScore(step, in: project, now: now) + 30
                )
            }
        }

        return (blockedProjects + blockedSteps)
            .sorted(by: candidateComesBefore(_:_:))
            .prefix(5)
            .map(\.self)
    }

    private static func buildNextSteps(
        projects: [Project],
        resolver: PlanningResolver,
        now: Date
    ) -> [FocusCandidate] {
        projects.flatMap { project in
            project.sortedSteps.compactMap { step -> FocusCandidate? in
                let projectReference = PlanningItemReference(kind: .project, id: project.id)
                let stepReference = PlanningItemReference(kind: .step, id: step.id)

                guard step.status.isOpen,
                      !step.isMilestone,
                      !resolver.isBlocked(stepReference),
                      !resolver.isBlocked(projectReference)
                else {
                    return nil
                }

                guard project.status == .active || project.isHighPriority || step.priority.isHighPriority else {
                    return nil
                }

                return FocusCandidate(
                    id: "step-\(step.id.uuidString)",
                    kind: .step,
                    title: step.title,
                    subtitle: project.title,
                    detail: step.notes,
                    reason: nextStepReason(step, project: project, now: now),
                    status: step.status,
                    priority: step.priority,
                    dueDate: step.dueDate ?? project.resolvedDueDate,
                    destination: .step(projectID: project.id, stepID: step.id),
                    isBlocked: false,
                    score: stepScore(step, in: project, now: now)
                )
            }
        }
        .sorted(by: candidateComesBefore(_:_:))
        .prefix(5)
        .map(\.self)
    }

    private static func buildMilestones(
        projects: [Project],
        resolver: PlanningResolver,
        now: Date
    ) -> [FocusCandidate] {
        projects.flatMap { project in
            project.sortedSteps.compactMap { step -> FocusCandidate? in
                guard step.isMilestone, step.status.isOpen else {
                    return nil
                }

                let dueDate = step.dueDate ?? project.resolvedDueDate
                guard urgencyScore(for: dueDate, now: now) > 0 else {
                    return nil
                }

                return FocusCandidate(
                    id: "milestone-\(step.id.uuidString)",
                    kind: .milestone,
                    title: step.title,
                    subtitle: project.title,
                    detail: step.notes,
                    reason: resolver.isBlocked(PlanningItemReference(kind: .step, id: step.id))
                        ? "Milestone is visible and currently blocked."
                        : "Milestone is approaching soon.",
                    status: step.status,
                    priority: step.priority,
                    dueDate: dueDate,
                    destination: .step(projectID: project.id, stepID: step.id),
                    isBlocked: resolver.isBlocked(PlanningItemReference(kind: .step, id: step.id)),
                    score: milestoneScore(step, in: project, now: now)
                )
            }
        }
        .sorted(by: candidateComesBefore(_:_:))
        .prefix(4)
        .map(\.self)
    }

    private static func buildInbox(items: [IdeaInboxItem], now: Date) -> [FocusCandidate] {
        items
            .filter { $0.state.needsTriage }
            .map { item in
                FocusCandidate(
                    id: "inbox-\(item.id.uuidString)",
                    kind: .inbox,
                    title: item.title,
                    subtitle: item.state.title,
                    detail: item.trimmedBody,
                    reason: inboxReason(item, now: now),
                    status: nil,
                    priority: item.priorityHint,
                    dueDate: nil,
                    destination: .inbox(item.id),
                    isBlocked: false,
                    score: inboxScore(item, now: now)
                )
            }
            .sorted(by: candidateComesBefore(_:_:))
            .prefix(5)
            .map(\.self)
    }

    private static func focusProjectSubtitle(_ project: Project) -> String {
        "\(project.openStepCount) open steps"
    }

    private static func focusProjectReason(_ project: Project, now: Date) -> String {
        if let dueDate = project.resolvedDueDate, urgencyScore(for: dueDate, now: now) >= 24 {
            return "Due soon, so it should stay on the front page."
        }

        if project.priority == .urgent {
            return "Urgent priority keeps it in the active lane."
        }

        if project.status == .active {
            return "Active work with visible motion."
        }

        return "Recently touched and still open."
    }

    private static func nextStepReason(_ step: ProjectStep, project: Project, now: Date) -> String {
        if let dueDate = step.dueDate, urgencyScore(for: dueDate, now: now) >= 24 {
            return "Step is due soon and ready to move."
        }

        if step.priority.isHighPriority {
            return "High-priority step inside a live project."
        }

        return "Open step in an active project."
    }

    private static func inboxReason(_ item: IdeaInboxItem, now: Date) -> String {
        if item.state == .reviewing {
            return "Already in review and ready for a decision."
        }

        let age = max(calendar.dateComponents([.hour], from: item.createdAt, to: now).hour ?? 0, 0)
        if age >= 24 {
            return "Has been waiting long enough to deserve triage."
        }

        if item.priorityHint?.isHighPriority == true {
            return "High-priority idea that should not sink in the queue."
        }

        return "Fresh capture that still needs structure."
    }

    private static func blockedReason(
        directBlocked: Bool,
        dependencyBlocked: Bool,
        blockedChildCount: Int
    ) -> String {
        if dependencyBlocked {
            return "Blocked by unresolved predecessors."
        }

        if directBlocked {
            return "Explicitly marked blocked."
        }

        if blockedChildCount > 0 {
            return "\(blockedChildCount) child items are blocked."
        }

        return "Blocked work needs attention."
    }

    private static func projectScore(_ project: Project, now: Date) -> Int {
        var score = project.priority.rank * 18

        switch project.status {
        case .active:
            score += 42
        case .blocked:
            score += 36
        case .idea:
            score += 16
        case .paused:
            score += 8
        case .done:
            break
        }

        score += urgencyScore(for: project.resolvedDueDate, now: now)
        score += min(project.openStepCount, 4) * 4

        let recentThreshold = calendar.date(byAdding: .day, value: -2, to: now) ?? now
        if project.updatedAt >= recentThreshold {
            score += 8
        }

        return score
    }

    private static func stepScore(_ step: ProjectStep, in project: Project, now: Date) -> Int {
        var score = projectScore(project, now: now) / 2
        score += step.priority.rank * 15
        score += urgencyScore(for: step.dueDate ?? project.resolvedDueDate, now: now)

        switch step.status {
        case .active:
            score += 26
        case .blocked:
            score += 22
        case .idea:
            score += 10
        case .paused:
            score += 4
        case .done:
            break
        }

        return score
    }

    private static func milestoneScore(_ step: ProjectStep, in project: Project, now: Date) -> Int {
        stepScore(step, in: project, now: now) + 18
    }

    private static func inboxScore(_ item: IdeaInboxItem, now: Date) -> Int {
        var score = (item.priorityHint?.rank ?? 0) * 16
        score += item.state == .reviewing ? 26 : 18

        let ageInHours = max(calendar.dateComponents([.hour], from: item.createdAt, to: now).hour ?? 0, 0)
        score += min(ageInHours / 6, 8) * 4

        return score
    }

    private static func urgencyScore(for dueDate: Date?, now: Date) -> Int {
        guard let dueDate else {
            return 0
        }

        let dayDelta = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: dueDate)).day ?? 0

        switch dayDelta {
        case Int.min ... -1:
            return 34
        case 0 ... 2:
            return 30
        case 3 ... 7:
            return 20
        case 8 ... 14:
            return 10
        default:
            return 0
        }
    }

    nonisolated private static func candidateComesBefore(_ lhs: FocusCandidate, _ rhs: FocusCandidate) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score > rhs.score
        }

        if lhs.isBlocked != rhs.isBlocked {
            return lhs.isBlocked
        }

        switch (lhs.dueDate, rhs.dueDate) {
        case let (.some(left), .some(right)) where left != right:
            return left < right
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        default:
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private static let calendar = Calendar.current
}
