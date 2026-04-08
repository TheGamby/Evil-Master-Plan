import Foundation
import SwiftData

enum StepMoveDirection {
    case earlier
    case later
}

enum PlanningMutationWorkflow {
    static func deleteProject(
        _ project: Project,
        in context: ModelContext,
        now: Date = .now
    ) throws {
        let stepIDs = Set(project.steps.map(\.id))
        let dependencies = try context.fetch(FetchDescriptor<Dependency>())
        let projects = try context.fetch(FetchDescriptor<Project>())
        let dependenciesToDelete = dependencies.filter { dependency in
            references(dependency, projectID: project.id, stepIDs: stepIDs)
        }

        touchProjects(
            affectedBy: dependenciesToDelete,
            in: projects,
            excluding: [project.id],
            at: now
        )
        dependenciesToDelete.forEach(context.delete)

        let inboxItems = try context.fetch(FetchDescriptor<IdeaInboxItem>())
        for item in inboxItems where links(item, toProjectID: project.id, stepIDs: stepIDs) {
            item.unlinkDeletedTarget(at: now)
        }

        context.delete(project)
    }

    static func deleteStep(
        _ step: ProjectStep,
        in context: ModelContext,
        now: Date = .now
    ) throws {
        let stepID = step.id
        let project = step.project
        let projectID = project?.id
        let dependencies = try context.fetch(FetchDescriptor<Dependency>())
        let projects = try context.fetch(FetchDescriptor<Project>())
        let dependenciesToDelete = dependencies.filter { dependency in
            references(dependency, stepID: stepID)
        }

        touchProjects(
            affectedBy: dependenciesToDelete,
            in: projects,
            excluding: projectID.map { [$0] } ?? [],
            at: now
        )
        dependenciesToDelete.forEach(context.delete)

        let inboxItems = try context.fetch(FetchDescriptor<IdeaInboxItem>())
        for item in inboxItems where item.linkedStep?.id == stepID {
            item.unlinkDeletedTarget(at: now)
        }

        project?.steps.removeAll { $0.id == stepID }
        context.delete(step)
        project?.normalizeStepOrder(at: now)
    }

    static func deleteDependency(
        _ dependency: Dependency,
        in context: ModelContext,
        now: Date = .now
    ) throws {
        let projects = try context.fetch(FetchDescriptor<Project>())
        touchProjects(affectedBy: [dependency], in: projects, excluding: [], at: now)
        context.delete(dependency)
    }

    static func deleteInboxItem(_ item: IdeaInboxItem, in context: ModelContext) {
        context.delete(item)
    }

    static func moveStep(
        _ step: ProjectStep,
        direction: StepMoveDirection,
        at date: Date = .now
    ) -> Bool {
        guard let project = step.project else {
            return false
        }

        return project.moveStep(step, direction: direction, at: date)
    }

    static func nudgePriority(
        for project: Project,
        by offset: Int,
        at date: Date = .now
    ) {
        project.setPriority(priority(relativeTo: project.priority, offset: offset), at: date)
    }

    static func nudgePriority(
        for step: ProjectStep,
        by offset: Int,
        at date: Date = .now
    ) {
        step.setPriority(priority(relativeTo: step.priority, offset: offset), at: date)
    }

    static func shiftSchedule(
        _ project: Project,
        byDays dayOffset: Int,
        now: Date = .now
    ) {
        let baseline = projectScheduleBaseline(for: project, now: now)
        let calendar = Calendar.current

        project.startDate = calendar.date(byAdding: .day, value: dayOffset, to: baseline.start)
        project.dueDate = calendar.date(byAdding: .day, value: dayOffset, to: baseline.end)
        project.touch(at: now)
    }

    static func shiftSchedule(
        _ step: ProjectStep,
        byDays dayOffset: Int,
        now: Date = .now
    ) {
        let calendar = Calendar.current

        if step.isMilestone {
            let baseline = step.dueDate
                ?? step.startDate
                ?? step.project?.resolvedDueDate
                ?? step.project?.resolvedStartDate
                ?? calendar.startOfDay(for: now)
            let shifted = calendar.date(byAdding: .day, value: dayOffset, to: baseline) ?? baseline
            step.startDate = shifted
            step.dueDate = shifted
            step.touch(at: now)
            return
        }

        let baseline = stepScheduleBaseline(for: step, now: now)
        step.startDate = calendar.date(byAdding: .day, value: dayOffset, to: baseline.start)
        step.dueDate = calendar.date(byAdding: .day, value: dayOffset, to: baseline.end)
        step.touch(at: now)
    }

    static func scheduleProjectFromToday(_ project: Project, now: Date = .now) {
        let baseline = projectScheduleBaseline(for: project, now: now)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let span = max(calendar.dateComponents([.day], from: baseline.start, to: baseline.end).day ?? 21, 0)

        project.startDate = today
        project.dueDate = calendar.date(byAdding: .day, value: max(span, 7), to: today) ?? today
        project.touch(at: now)
    }

    static func scheduleStepFromToday(_ step: ProjectStep, now: Date = .now) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        if step.isMilestone {
            step.startDate = today
            step.dueDate = today
            step.touch(at: now)
            return
        }

        let baseline = stepScheduleBaseline(for: step, now: now)
        let span = max(calendar.dateComponents([.day], from: baseline.start, to: baseline.end).day ?? 3, 0)

        step.startDate = today
        step.dueDate = calendar.date(byAdding: .day, value: max(span, 3), to: today) ?? today
        step.touch(at: now)
    }

    static func clearSchedule(_ project: Project, at date: Date = .now) {
        project.startDate = nil
        project.dueDate = nil
        project.touch(at: date)
    }

    static func clearSchedule(_ step: ProjectStep, at date: Date = .now) {
        step.startDate = nil
        step.dueDate = nil
        step.touch(at: date)
    }

    private static func priority(relativeTo priority: PriorityLevel, offset: Int) -> PriorityLevel {
        let all = PriorityLevel.allCases.sorted()
        guard let index = all.firstIndex(of: priority) else {
            return priority
        }

        let clampedIndex = min(max(index + offset, all.startIndex), all.index(before: all.endIndex))
        return all[clampedIndex]
    }

    private static func projectScheduleBaseline(
        for project: Project,
        now: Date
    ) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let start = project.startDate
            ?? project.resolvedStartDate
            ?? calendar.startOfDay(for: now)
        let fallbackEnd = calendar.date(byAdding: .day, value: 21, to: start) ?? start
        let end = max(project.dueDate ?? project.resolvedDueDate ?? fallbackEnd, start)
        return (calendar.startOfDay(for: start), calendar.startOfDay(for: end))
    }

    private static func stepScheduleBaseline(
        for step: ProjectStep,
        now: Date
    ) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let start = step.startDate
            ?? step.project?.resolvedStartDate
            ?? calendar.startOfDay(for: now)
        let fallbackEnd = calendar.date(byAdding: .day, value: 3, to: start) ?? start
        let end = max(step.dueDate ?? step.project?.resolvedDueDate ?? fallbackEnd, start)
        return (calendar.startOfDay(for: start), calendar.startOfDay(for: end))
    }

    private static func references(
        _ dependency: Dependency,
        projectID: UUID,
        stepIDs: Set<UUID>
    ) -> Bool {
        dependency.sourceReference == PlanningItemReference(kind: .project, id: projectID) ||
        dependency.targetReference == PlanningItemReference(kind: .project, id: projectID) ||
        stepIDs.contains(dependency.sourceItemID) ||
        stepIDs.contains(dependency.targetItemID)
    }

    private static func references(_ dependency: Dependency, stepID: UUID) -> Bool {
        dependency.sourceReference == PlanningItemReference(kind: .step, id: stepID) ||
        dependency.targetReference == PlanningItemReference(kind: .step, id: stepID)
    }

    private static func links(
        _ item: IdeaInboxItem,
        toProjectID projectID: UUID,
        stepIDs: Set<UUID>
    ) -> Bool {
        if item.linkedProject?.id == projectID {
            return true
        }

        guard let linkedStepID = item.linkedStep?.id else {
            return false
        }

        return stepIDs.contains(linkedStepID)
    }

    private static func touchProjects(
        affectedBy dependencies: [Dependency],
        in projects: [Project],
        excluding excludedProjectIDs: [UUID],
        at date: Date
    ) {
        guard !dependencies.isEmpty else {
            return
        }

        let excluded = Set(excludedProjectIDs)
        let stepLookup = Dictionary(
            uniqueKeysWithValues: projects.flatMap { project in
                project.steps.map { ($0.id, project.id) }
            }
        )

        var projectIDsToTouch = Set<UUID>()
        for dependency in dependencies {
            switch dependency.sourceKind {
            case .project:
                projectIDsToTouch.insert(dependency.sourceItemID)
            case .step:
                if let projectID = stepLookup[dependency.sourceItemID] {
                    projectIDsToTouch.insert(projectID)
                }
            }

            switch dependency.targetKind {
            case .project:
                projectIDsToTouch.insert(dependency.targetItemID)
            case .step:
                if let projectID = stepLookup[dependency.targetItemID] {
                    projectIDsToTouch.insert(projectID)
                }
            }
        }

        for project in projects where projectIDsToTouch.contains(project.id) && !excluded.contains(project.id) {
            project.touch(at: date)
        }
    }
}
