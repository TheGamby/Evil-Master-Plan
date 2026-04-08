import CoreGraphics
import Foundation

enum BubbleGraphBuilder {
    static func scene(
        projects: [Project],
        dependencies: [Dependency],
        sizing: BubbleSizingCriterion,
        grouping: BubbleGroupingMode,
        filter: BubbleFilterState,
        focusedProjectID: UUID?,
        selectedNodeID: UUID?,
        viewportWidth: CGFloat
    ) -> BubbleNetworkScene {
        let visibleProjects = filteredProjects(from: projects, dependencies: dependencies, filter: filter)
        let resolver = PlanningResolver(projects: visibleProjects, dependencies: dependencies)
        let focusProject = visibleProjects.first { $0.id == focusedProjectID }
        let focusedSteps = focusProject.map {
            relevantSteps(for: $0, resolver: resolver, hidesCompleted: filter.hidesCompletedProjects)
        } ?? []
        let sizingSystem = BubbleSizingSystem(
            criterion: sizing,
            visibleProjects: visibleProjects,
            focusedSteps: focusedSteps,
            resolver: resolver
        )

        let projectDrafts = visibleProjects.map { project in
            let group = groupDescriptor(for: project, resolver: resolver, mode: grouping)
            let reference = PlanningItemReference(kind: .project, id: project.id)
            return BubbleDraftNode(
                id: project.id,
                sourceReference: reference,
                title: project.title,
                subtitle: project.summary.isEmpty ? project.status.title : project.summary,
                kind: .project,
                status: project.status,
                priority: project.priority,
                progress: project.progress,
                dueDate: project.resolvedDueDate,
                colorToken: project.colorToken,
                radius: sizingSystem.radius(for: project),
                openStepCount: project.openStepCount,
                dependencyCount: resolver.dependencyCount(for: reference),
                isBlocked: resolver.isBlocked(reference),
                isFocused: project.id == focusedProjectID,
                isSelected: project.id == selectedNodeID,
                isConnectedToSelection: false,
                isDimmed: false,
                groupID: group.id,
                groupTitle: group.title,
                groupRank: group.rank,
                clusterParentID: nil
            )
        }

        let stepDrafts = focusedSteps.map { step in
            let project = step.project ?? focusProject
            let group = groupDescriptor(for: project, resolver: resolver, mode: grouping)
            let reference = PlanningItemReference(kind: .step, id: step.id)
            return BubbleDraftNode(
                id: step.id,
                sourceReference: reference,
                title: step.title,
                subtitle: step.kind.title,
                kind: step.isMilestone ? .milestone : .task,
                status: step.status,
                priority: step.priority,
                progress: step.progress,
                dueDate: step.dueDate,
                colorToken: project?.colorToken ?? .ember,
                radius: sizingSystem.radius(for: step),
                openStepCount: step.isOpen ? 1 : 0,
                dependencyCount: resolver.dependencyCount(for: reference),
                isBlocked: resolver.isBlocked(reference),
                isFocused: true,
                isSelected: step.id == selectedNodeID,
                isConnectedToSelection: false,
                isDimmed: false,
                groupID: group.id,
                groupTitle: group.title,
                groupRank: group.rank,
                clusterParentID: project?.id
            )
        }

        let allDrafts = projectDrafts + stepDrafts
        let visibleNodeIDs = Set(allDrafts.map(\.id))

        let edgeDrafts = dependencies.compactMap { dependency -> BubbleDraftEdge? in
            guard
                !dependency.isSelfReference,
                visibleNodeIDs.contains(dependency.sourceItemID),
                visibleNodeIDs.contains(dependency.targetItemID)
            else {
                return nil
            }

            let touchesFocusProject = focusedProjectID.map { projectID in
                dependency.sourceItemID == projectID || dependency.targetItemID == projectID
            } ?? false

            let touchesSelectedNode = selectedNodeID.map { nodeID in
                dependency.sourceItemID == nodeID || dependency.targetItemID == nodeID
            } ?? false

            return BubbleDraftEdge(
                id: dependency.id,
                sourceNodeID: dependency.sourceItemID,
                targetNodeID: dependency.targetItemID,
                type: dependency.type,
                weight: touchesFocusProject ? 1.0 : 0.72,
                isHighlighted: touchesSelectedNode
            )
        }

        let connectedIDs = selectedNodeID.map { selectedID in
            Set(
                edgeDrafts.flatMap { edge -> [UUID] in
                    guard edge.sourceNodeID == selectedID || edge.targetNodeID == selectedID else {
                        return []
                    }
                    return [edge.sourceNodeID, edge.targetNodeID]
                }
            )
        } ?? []

        let hasSelection = selectedNodeID != nil
        let groups = uniqueGroups(from: allDrafts)
        let enrichedDrafts = allDrafts.map { node in
            let connected = connectedIDs.contains(node.id)
            let dimmed = hasSelection && !node.isSelected && !connected && !node.isFocused

            return BubbleDraftNode(
                id: node.id,
                sourceReference: node.sourceReference,
                title: node.title,
                subtitle: node.subtitle,
                kind: node.kind,
                status: node.status,
                priority: node.priority,
                progress: node.progress,
                dueDate: node.dueDate,
                colorToken: node.colorToken,
                radius: node.radius,
                openStepCount: node.openStepCount,
                dependencyCount: node.dependencyCount,
                isBlocked: node.isBlocked,
                isFocused: node.isFocused,
                isSelected: node.isSelected,
                isConnectedToSelection: connected,
                isDimmed: dimmed,
                groupID: node.groupID,
                groupTitle: node.groupTitle,
                groupRank: node.groupRank,
                clusterParentID: node.clusterParentID
            )
        }

        let graph = BubbleGraphLayoutEngine.layout(
            draft: BubbleGraphDraft(nodes: enrichedDrafts, edges: edgeDrafts, groups: groups),
            viewportWidth: viewportWidth
        )

        return BubbleNetworkScene(
            graph: graph,
            summary: BubbleGraphSummary(
                visibleProjectCount: visibleProjects.count,
                blockedProjectCount: visibleProjects.filter {
                    resolver.isBlocked(PlanningItemReference(kind: .project, id: $0.id))
                }.count,
                visibleConnectionCount: edgeDrafts.count,
                focusedStepCount: focusedSteps.count
            ),
            inspector: inspectorContext(
                selectedNodeID: selectedNodeID,
                resolver: resolver
            )
        )
    }

    private static func filteredProjects(
        from projects: [Project],
        dependencies: [Dependency],
        filter: BubbleFilterState
    ) -> [Project] {
        let resolver = PlanningResolver(projects: projects, dependencies: dependencies)
        return projects.filter { project in
            if !filter.showsArchivedProjects && project.isArchived {
                return false
            }

            if filter.showsOnlyHighPriorityProjects && !project.isHighPriority {
                return false
            }

            if filter.hidesCompletedProjects && project.status == .done {
                return false
            }

            switch filter.primaryFilter {
            case .all:
                return true
            case .active:
                return project.status == .active
            case .blocked:
                return resolver.isBlocked(PlanningItemReference(kind: .project, id: project.id))
            }
        }
    }

    private static func relevantSteps(
        for project: Project,
        resolver: PlanningResolver,
        hidesCompleted: Bool
    ) -> [ProjectStep] {
        let candidateSteps = project.sortedSteps.filter { !hidesCompleted || $0.status != .done }
        let prioritized = candidateSteps.sorted {
            if $0.isMilestone != $1.isMilestone {
                return $0.isMilestone
            }
            let lhsBlocked = resolver.isBlocked(PlanningItemReference(kind: .step, id: $0.id))
            let rhsBlocked = resolver.isBlocked(PlanningItemReference(kind: .step, id: $1.id))
            if lhsBlocked || rhsBlocked {
                return lhsBlocked
            }
            if $0.priority != $1.priority {
                return $0.priority > $1.priority
            }
            return ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
        }

        let filtered = prioritized.filter {
            let reference = PlanningItemReference(kind: .step, id: $0.id)
            return $0.isMilestone || resolver.isBlocked(reference) || $0.status == .active || $0.isHighPriority
        }

        let result = filtered.isEmpty ? Array(prioritized.prefix(4)) : Array(filtered.prefix(6))
        return result.sorted(using: SortDescriptor(\.sortOrder))
    }

    private static func uniqueGroups(from nodes: [BubbleDraftNode]) -> [BubbleDraftGroup] {
        var groups: [String: BubbleDraftGroup] = [:]
        for node in nodes where node.clusterParentID == nil {
            groups[node.groupID] = BubbleDraftGroup(
                id: node.groupID,
                title: node.groupTitle,
                rank: node.groupRank
            )
        }
        return Array(groups.values)
    }

    private static func groupDescriptor(
        for project: Project?,
        resolver: PlanningResolver,
        mode: BubbleGroupingMode
    ) -> (id: String, title: String, rank: Int) {
        guard let project else {
            return ("misc", "Misc", 99)
        }

        switch mode {
        case .status:
            if resolver.isBlocked(PlanningItemReference(kind: .project, id: project.id)) {
                return ("status-blocked", "Blocked Projects", 0)
            }

            switch project.status {
            case .active:
                return ("status-active", "Active Projects", 1)
            case .paused:
                return ("status-paused", "Paused Projects", 2)
            case .idea:
                return ("status-idea", "Ideas", 3)
            case .done:
                return ("status-done", "Done Projects", 4)
            case .blocked:
                return ("status-blocked", "Blocked Projects", 0)
            }
        case .priority:
            switch project.priority {
            case .urgent:
                return ("priority-urgent", "Urgent", 0)
            case .high:
                return ("priority-high", "High Priority", 1)
            case .medium:
                return ("priority-medium", "Medium Priority", 2)
            case .low:
                return ("priority-low", "Low Priority", 3)
            }
        }
    }

    private static func inspectorContext(
        selectedNodeID: UUID?,
        resolver: PlanningResolver
    ) -> BubbleInspectorContext? {
        guard let selectedNodeID else {
            return nil
        }

        if let project = resolver.project(id: selectedNodeID) {
            let reference = PlanningItemReference(kind: .project, id: project.id)
            return BubbleInspectorContext(
                nodeID: project.id,
                sourceReference: reference,
                projectID: project.id,
                title: project.title,
                subtitle: project.summary.isEmpty ? project.status.title : project.summary,
                kind: .project,
                status: project.status,
                priority: project.priority,
                progress: project.progress,
                dueDate: project.resolvedDueDate,
                isBlocked: resolver.isBlocked(reference),
                openStepCount: project.openStepCount,
                blockedStepCount: project.blockedStepCount,
                dependencyCount: resolver.dependencyCount(for: reference),
                projectTitle: project.title,
                upcomingMilestones: milestoneContext(for: project),
                incomingDependencies: dependencyContext(for: resolver.incomingDependencies(for: reference), resolver: resolver, targetingSource: true),
                outgoingDependencies: dependencyContext(for: resolver.outgoingDependencies(for: reference), resolver: resolver, targetingSource: false)
            )
        }

        guard
            let step = resolver.step(id: selectedNodeID),
            let project = step.project
        else {
            return nil
        }

        let reference = PlanningItemReference(kind: .step, id: step.id)
        return BubbleInspectorContext(
            nodeID: step.id,
            sourceReference: reference,
            projectID: project.id,
            title: step.title,
            subtitle: "\(step.kind.title) in \(project.title)",
            kind: step.isMilestone ? .milestone : .task,
            status: step.status,
            priority: step.priority,
            progress: step.progress,
            dueDate: step.dueDate,
            isBlocked: resolver.isBlocked(reference),
            openStepCount: project.openStepCount,
            blockedStepCount: project.blockedStepCount,
            dependencyCount: resolver.dependencyCount(for: reference),
            projectTitle: project.title,
            upcomingMilestones: milestoneContext(for: project),
            incomingDependencies: dependencyContext(for: resolver.incomingDependencies(for: reference), resolver: resolver, targetingSource: true),
            outgoingDependencies: dependencyContext(for: resolver.outgoingDependencies(for: reference), resolver: resolver, targetingSource: false)
        )
    }

    private static func dependencyContext(
        for dependencies: [Dependency],
        resolver: PlanningResolver,
        targetingSource: Bool
    ) -> [BubbleInspectorDependency] {
        Array(dependencies.prefix(4)).map { dependency in
            let reference = targetingSource ? dependency.sourceReference : dependency.targetReference
            return BubbleInspectorDependency(
                id: dependency.id,
                title: resolver.title(for: reference),
                subtitle: resolver.subtitle(for: reference),
                type: dependency.type,
                note: dependency.note
            )
        }
    }

    private static func milestoneContext(for project: Project) -> [BubbleInspectorMilestone] {
        Array(project.nextMilestones.prefix(3)).map {
            BubbleInspectorMilestone(id: $0.id, title: $0.title, dueDate: $0.dueDate)
        }
    }
}

private struct BubbleSizingSystem {
    let criterion: BubbleSizingCriterion
    let values: [UUID: Double]
    let minimumValue: Double
    let maximumValue: Double

    init(
        criterion: BubbleSizingCriterion,
        visibleProjects: [Project],
        focusedSteps: [ProjectStep],
        resolver: PlanningResolver
    ) {
        self.criterion = criterion

        var metrics: [UUID: Double] = [:]
        for project in visibleProjects {
            metrics[project.id] = BubbleSizingSystem.metric(for: project, criterion: criterion, resolver: resolver)
        }
        for step in focusedSteps {
            metrics[step.id] = BubbleSizingSystem.metric(for: step, criterion: criterion, resolver: resolver)
        }

        values = metrics
        minimumValue = metrics.values.min() ?? 0
        maximumValue = metrics.values.max() ?? 1
    }

    func radius(for project: Project) -> CGFloat {
        scaledRadius(for: values[project.id] ?? 0, range: 50...94)
    }

    func radius(for step: ProjectStep) -> CGFloat {
        scaledRadius(for: values[step.id] ?? 0, range: 26...52)
    }

    private func scaledRadius(for value: Double, range: ClosedRange<CGFloat>) -> CGFloat {
        let normalized: Double
        if abs(maximumValue - minimumValue) < 0.001 {
            normalized = value <= 0 ? 0.32 : 0.66
        } else {
            normalized = (value - minimumValue) / (maximumValue - minimumValue)
        }

        return range.lowerBound + CGFloat(normalized) * (range.upperBound - range.lowerBound)
    }

    private static func metric(
        for project: Project,
        criterion: BubbleSizingCriterion,
        resolver: PlanningResolver
    ) -> Double {
        switch criterion {
        case .priority:
            Double(project.priority.rank + 1)
        case .progress:
            project.progress
        case .dependencyCount:
            Double(resolver.dependencyCount(for: PlanningItemReference(kind: .project, id: project.id)))
        case .openStepCount:
            Double(project.openStepCount)
        }
    }

    private static func metric(
        for step: ProjectStep,
        criterion: BubbleSizingCriterion,
        resolver: PlanningResolver
    ) -> Double {
        switch criterion {
        case .priority:
            Double(step.priority.rank + 1)
        case .progress:
            step.progress
        case .dependencyCount:
            Double(resolver.dependencyCount(for: PlanningItemReference(kind: .step, id: step.id)))
        case .openStepCount:
            step.isOpen ? 1 : 0
        }
    }
}
