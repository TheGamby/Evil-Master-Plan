import CoreGraphics
import Foundation

struct PlanningItemResolver {
    private let projectsByID: [UUID: Project]
    private let stepsByID: [UUID: ProjectStep]
    private let dependencyCounts: [UUID: Int]

    init(projects: [Project], dependencies: [Dependency]) {
        projectsByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })

        var stepEntries: [(UUID, ProjectStep)] = []
        for project in projects {
            for step in project.steps {
                stepEntries.append((step.id, step))
            }
        }
        stepsByID = Dictionary(uniqueKeysWithValues: stepEntries)

        var counts: [UUID: Int] = [:]
        for dependency in dependencies {
            counts[dependency.sourceItemID, default: 0] += 1
            counts[dependency.targetItemID, default: 0] += 1
        }
        dependencyCounts = counts
    }

    func title(for reference: PlanningItemReference) -> String {
        switch reference.kind {
        case .project:
            return projectsByID[reference.id]?.title ?? "Unknown Project"
        case .step:
            return stepsByID[reference.id]?.title ?? "Unknown Step"
        }
    }

    func subtitle(for reference: PlanningItemReference) -> String {
        switch reference.kind {
        case .project:
            return "Project"
        case .step:
            return stepsByID[reference.id]?.project?.title ?? "Project Step"
        }
    }

    func priority(for reference: PlanningItemReference) -> PriorityLevel {
        switch reference.kind {
        case .project:
            return projectsByID[reference.id]?.priority ?? .medium
        case .step:
            return stepsByID[reference.id]?.priority ?? .medium
        }
    }

    func progress(for reference: PlanningItemReference) -> Double {
        switch reference.kind {
        case .project:
            return projectsByID[reference.id]?.progress ?? 0
        case .step:
            return stepsByID[reference.id]?.progress ?? 0
        }
    }

    func color(for reference: PlanningItemReference) -> ProjectColorToken {
        switch reference.kind {
        case .project:
            return projectsByID[reference.id]?.colorToken ?? .ember
        case .step:
            return stepsByID[reference.id]?.project?.colorToken ?? .ember
        }
    }

    func dependencyCount(for reference: PlanningItemReference) -> Int {
        dependencyCounts[reference.id, default: 0]
    }
}

struct BubbleNodeProjection: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let kind: PlanningItemKind
    let colorToken: ProjectColorToken
    let center: CGPoint
    let radius: CGFloat
}

struct BubbleEdgeProjection: Identifiable {
    let id: UUID
    let start: CGPoint
    let end: CGPoint
    let type: DependencyType
}

struct BubbleNetworkProjection {
    let nodes: [BubbleNodeProjection]
    let edges: [BubbleEdgeProjection]
    let canvasSize: CGSize
}

struct GanttRowProjection: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let kind: ProjectStepKind
    let colorToken: ProjectColorToken
    let startDate: Date
    let endDate: Date
    let progress: Double
    let status: ProjectStatus
    let indentLevel: Int
}

struct GanttProjection {
    let timelineStart: Date
    let timelineEnd: Date
    let rows: [GanttRowProjection]

    var dayCount: Int {
        let days = Calendar.current.dateComponents([.day], from: timelineStart, to: timelineEnd).day ?? 0
        return max(days + 1, 1)
    }
}

struct DependencyRowProjection: Identifiable {
    let id: UUID
    let sourceTitle: String
    let sourceSubtitle: String
    let targetTitle: String
    let targetSubtitle: String
    let type: DependencyType
    let note: String
}

struct FocusItemProjection: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let dueDate: Date
    let priority: PriorityLevel
}

struct DashboardSnapshot {
    let activeProjectCount: Int
    let blockedProjectCount: Int
    let inboxCount: Int
    let milestoneCount: Int
    let focusItems: [FocusItemProjection]
}

enum PlanningProjectionFactory {
    static func bubbleNetwork(
        projects: [Project],
        dependencies: [Dependency],
        sizing: BubbleSizingCriterion,
        canvasWidth: CGFloat
    ) -> BubbleNetworkProjection {
        let resolver = PlanningItemResolver(projects: projects, dependencies: dependencies)
        let sortedProjects = projects.sorted(using: SortDescriptor(\.createdAt))
        let stepDepth = max(sortedProjects.map { $0.steps.count }.max() ?? 0, 1)

        let projectSpacing = max(canvasWidth / CGFloat(max(sortedProjects.count, 1) + 1), 220)
        let canvasHeight = CGFloat(220 + stepDepth * 150)
        let canvasSize = CGSize(width: max(canvasWidth, CGFloat(sortedProjects.count) * 260), height: canvasHeight)

        var nodes: [BubbleNodeProjection] = []
        var pointsByID: [UUID: CGPoint] = [:]

        for (projectIndex, project) in sortedProjects.enumerated() {
            let projectReference = PlanningItemReference(kind: .project, id: project.id)
            let projectCenter = CGPoint(
                x: projectSpacing * CGFloat(projectIndex + 1),
                y: 120
            )

            let projectNode = BubbleNodeProjection(
                id: project.id,
                title: project.title,
                subtitle: "Project",
                kind: .project,
                colorToken: project.colorToken,
                center: projectCenter,
                radius: bubbleRadius(for: projectReference, resolver: resolver, sizing: sizing)
            )
            nodes.append(projectNode)
            pointsByID[project.id] = projectCenter

            let sortedSteps = project.sortedSteps
            let stepCount = max(sortedSteps.count, 1)

            for (stepIndex, step) in sortedSteps.enumerated() {
                let stepReference = PlanningItemReference(kind: .step, id: step.id)
                let normalized = stepCount == 1 ? 0 : CGFloat(stepIndex) / CGFloat(stepCount - 1)
                let stepCenter = CGPoint(
                    x: projectCenter.x - 90 + (normalized * 180),
                    y: 280 + CGFloat(stepIndex) * 130
                )

                let stepNode = BubbleNodeProjection(
                    id: step.id,
                    title: step.title,
                    subtitle: step.kind.title,
                    kind: .step,
                    colorToken: project.colorToken,
                    center: stepCenter,
                    radius: bubbleRadius(for: stepReference, resolver: resolver, sizing: sizing) * 0.82
                )
                nodes.append(stepNode)
                pointsByID[step.id] = stepCenter
            }
        }

        let edges = dependencies.compactMap { dependency -> BubbleEdgeProjection? in
            guard
                let start = pointsByID[dependency.sourceItemID],
                let end = pointsByID[dependency.targetItemID]
            else {
                return nil
            }

            return BubbleEdgeProjection(
                id: dependency.id,
                start: start,
                end: end,
                type: dependency.type
            )
        }

        return BubbleNetworkProjection(nodes: nodes, edges: edges, canvasSize: canvasSize)
    }

    static func gantt(projects: [Project], showCompletedItems: Bool) -> GanttProjection {
        let calendar = Calendar.current
        var rows: [GanttRowProjection] = []

        for project in projects.sorted(using: SortDescriptor(\.createdAt)) {
            if let projectRange = resolvedRange(for: project) {
                rows.append(
                    GanttRowProjection(
                        id: project.id,
                        title: project.title,
                        subtitle: project.priority.title,
                        kind: .task,
                        colorToken: project.colorToken,
                        startDate: projectRange.start,
                        endDate: projectRange.end,
                        progress: project.progress,
                        status: project.status,
                        indentLevel: 0
                    )
                )
            }

            for (index, step) in project.sortedSteps.enumerated() {
                if !showCompletedItems && step.status == .done {
                    continue
                }

                let range = resolvedRange(for: step, in: project, index: index)
                rows.append(
                    GanttRowProjection(
                        id: step.id,
                        title: step.title,
                        subtitle: step.kind.title,
                        kind: step.kind,
                        colorToken: project.colorToken,
                        startDate: range.start,
                        endDate: range.end,
                        progress: step.progress,
                        status: step.status,
                        indentLevel: 1
                    )
                )
            }
        }

        let start = rows.map(\.startDate).min() ?? calendar.startOfDay(for: .now)
        let end = rows.map(\.endDate).max() ?? calendar.date(byAdding: .day, value: 14, to: start) ?? start

        return GanttProjection(
            timelineStart: calendar.startOfDay(for: start),
            timelineEnd: calendar.startOfDay(for: end),
            rows: rows
        )
    }

    static func dependencyRows(projects: [Project], dependencies: [Dependency]) -> [DependencyRowProjection] {
        let resolver = PlanningItemResolver(projects: projects, dependencies: dependencies)

        return dependencies.map { dependency in
            DependencyRowProjection(
                id: dependency.id,
                sourceTitle: resolver.title(for: dependency.sourceReference),
                sourceSubtitle: resolver.subtitle(for: dependency.sourceReference),
                targetTitle: resolver.title(for: dependency.targetReference),
                targetSubtitle: resolver.subtitle(for: dependency.targetReference),
                type: dependency.type,
                note: dependency.note
            )
        }
    }

    static func dashboard(projects: [Project], inboxItems: [IdeaInboxItem]) -> DashboardSnapshot {
        let activeProjects = projects.filter { $0.status == .active }
        let blockedProjects = projects.filter { $0.status == .blocked }
        let milestoneSteps = projects.flatMap(\.steps).filter(\.isMilestone)

        let focusItems = projects
            .flatMap { project in
                project.sortedSteps.map { step in
                    FocusItemProjection(
                        id: step.id,
                        title: step.title,
                        subtitle: project.title,
                        dueDate: step.dueDate ?? project.dueDate ?? .distantFuture,
                        priority: step.priority
                    )
                }
            }
            .filter { $0.dueDate != .distantFuture }
            .sorted {
                if $0.dueDate == $1.dueDate {
                    return $0.priority > $1.priority
                }
                return $0.dueDate < $1.dueDate
            }
            .prefix(4)

        return DashboardSnapshot(
            activeProjectCount: activeProjects.count,
            blockedProjectCount: blockedProjects.count,
            inboxCount: inboxItems.filter { $0.state == .open }.count,
            milestoneCount: milestoneSteps.count,
            focusItems: Array(focusItems)
        )
    }

    private static func bubbleRadius(
        for reference: PlanningItemReference,
        resolver: PlanningItemResolver,
        sizing: BubbleSizingCriterion
    ) -> CGFloat {
        switch sizing {
        case .progress:
            return 36 + (resolver.progress(for: reference) * 38)
        case .priority:
            return 36 + CGFloat(resolver.priority(for: reference).rank * 10)
        case .effort:
            return reference.kind == .project ? 74 : 48
        case .dependencyCount:
            return 34 + CGFloat(resolver.dependencyCount(for: reference) * 8)
        }
    }

    private static func resolvedRange(for project: Project) -> (start: Date, end: Date)? {
        guard let start = project.resolvedStartDate ?? project.createdAt as Date? else {
            return nil
        }

        let end = max(project.resolvedDueDate ?? start, start)
        return (start, end)
    }

    private static func resolvedRange(for step: ProjectStep, in project: Project, index: Int) -> (start: Date, end: Date) {
        let fallbackStart = step.project?.resolvedStartDate ?? project.startDate ?? project.createdAt
        let start = step.startDate ?? Calendar.current.date(byAdding: .day, value: index * 3, to: fallbackStart) ?? fallbackStart
        let fallbackEnd = Calendar.current.date(byAdding: .day, value: step.isMilestone ? 0 : 3, to: start) ?? start
        let end = max(step.dueDate ?? fallbackEnd, start)
        return (start, end)
    }
}
