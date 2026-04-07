import Foundation
import SwiftData
import Testing
@testable import Evil_Master_Plan

@MainActor
struct Evil_Master_PlanTests {
    @Test
    func seedSnapshotCreatesSingleSharedPlanningGraph() {
        let snapshot = SeedData.makeSampleSnapshot(now: referenceDate)
        let projectIDs = Set(snapshot.projects.map(\.id))
        let stepIDs = Set(snapshot.projects.flatMap(\.steps).map(\.id))
        let milestoneCount = snapshot.projects.flatMap(\.steps).filter(\.isMilestone).count

        #expect(snapshot.projects.count == 4)
        #expect(milestoneCount > 0)
        #expect(snapshot.dependencies.allSatisfy { dependency in
            switch dependency.sourceKind {
            case .project:
                projectIDs.contains(dependency.sourceItemID)
            case .step:
                stepIDs.contains(dependency.sourceItemID)
            }
        })
        #expect(snapshot.dependencies.allSatisfy { dependency in
            switch dependency.targetKind {
            case .project:
                projectIDs.contains(dependency.targetItemID)
            case .step:
                stepIDs.contains(dependency.targetItemID)
            }
        })
    }

    @Test
    func ganttProjectionUsesSharedProjectAndStepDates() {
        let snapshot = SeedData.makeSampleSnapshot(now: referenceDate)
        let projection = PlanningProjectionFactory.gantt(
            projects: snapshot.projects,
            showCompletedItems: true,
            showsOnlyHighPriorityProjects: false
        )

        #expect(projection.rows.count >= snapshot.projects.count)
        #expect(projection.dayCount > 14)
        #expect(projection.rows.contains { $0.kind == .milestone })
        #expect(projection.rows.contains { $0.kind == .project })
        #expect(projection.rows.contains { $0.kind == .task })
    }

    @Test
    func bubbleProjectionRespondsToSizingCriterion() {
        let snapshot = SeedData.makeSampleSnapshot(now: referenceDate)
        let progressProjection = PlanningProjectionFactory.bubbleNetwork(
            projects: snapshot.projects,
            dependencies: snapshot.dependencies,
            sizing: .progress,
            canvasWidth: 900,
            showsOnlyHighPriorityProjects: false
        )
        let dependencyProjection = PlanningProjectionFactory.bubbleNetwork(
            projects: snapshot.projects,
            dependencies: snapshot.dependencies,
            sizing: .dependencyCount,
            canvasWidth: 900,
            showsOnlyHighPriorityProjects: false
        )

        let activeProjectID = snapshot.projects[0].id
        let progressNode = progressProjection.nodes.first { $0.id == activeProjectID }
        let dependencyNode = dependencyProjection.nodes.first { $0.id == activeProjectID }

        #expect(progressProjection.edges.count == snapshot.dependencies.count)
        #expect(progressNode?.radius != dependencyNode?.radius)
    }

    @Test
    func bootstrapSeedsOnlyEmptyStores() throws {
        let container = try PersistenceController.makeModelContainer(
            isStoredInMemoryOnly: true,
            enableCloudKitSync: false
        )
        let context = container.mainContext

        try DataBootstrapper.seedIfNeeded(in: context)
        try DataBootstrapper.seedIfNeeded(in: context)

        let projectCount = try context.fetchCount(FetchDescriptor<Project>())
        let dependencyCount = try context.fetchCount(FetchDescriptor<Dependency>())
        let preferenceCount = try context.fetchCount(FetchDescriptor<VisualizationPreferences>())

        #expect(projectCount == 4)
        #expect(dependencyCount == 4)
        #expect(preferenceCount == 1)
    }

    @Test
    func samplePreferencesAreSingletonScoped() {
        let snapshot = SeedData.makeSampleSnapshot(now: referenceDate)

        #expect(snapshot.preferences.scope == VisualizationPreferences.defaultScope)
        #expect(snapshot.preferences.showsOnlyHighPriorityProjects == false)
    }

    @Test
    func projectAndStepMutationsEnforceBasicInvariants() {
        let project = Project.starter(now: referenceDate)
        project.setProgress(2)
        project.setStartDate(referenceDate)
        project.setDueDate(referenceDate.addingTimeInterval(-86_400))
        let step = project.addMilestone(title: "Checkpoint")
        step.setProgress(-1)
        step.setStartDate(referenceDate)
        step.setDueDate(referenceDate.addingTimeInterval(-86_400))

        #expect(project.progress == 1)
        #expect(project.dueDate == referenceDate)
        #expect(step.progress == 0)
        #expect(step.dueDate == referenceDate)
        #expect(step.isMilestone)
    }

    private var referenceDate: Date {
        Date(timeIntervalSince1970: 1_775_520_000)
    }
}
