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
    func planningSnapshotUsesSharedProjectAndStepDates() {
        let snapshot = SeedData.makeSampleSnapshot(now: referenceDate)
        let timeline = PlanningTimelineBuilder.snapshot(
            projects: snapshot.projects,
            dependencies: snapshot.dependencies,
            filter: PlanningFilterState(
                showsCompletedItems: true,
                showsOnlyHighPriorityProjects: false,
                showsOnlyBlockedItems: false,
                showsOnlyLinkedItems: false
            ),
            scale: .week,
            projectSortCriterion: .updatedAt,
            now: referenceDate
        )

        #expect(timeline.entries.count >= snapshot.projects.count)
        #expect(timeline.timelineEnd > timeline.timelineStart)
        #expect(timeline.entries.contains { $0.kind == .milestone })
        #expect(timeline.entries.contains { $0.kind == .project })
        #expect(timeline.entries.contains { $0.kind == .task })
        #expect(timeline.edges.count == snapshot.dependencies.count)
    }

    @Test
    func planningSnapshotTreatsMilestonesAsStepBasedMarkers() {
        let snapshot = SeedData.makeSampleSnapshot(now: referenceDate)
        let timeline = PlanningTimelineBuilder.snapshot(
            projects: snapshot.projects,
            dependencies: snapshot.dependencies,
            filter: PlanningFilterState(),
            scale: .week,
            projectSortCriterion: .updatedAt,
            now: referenceDate
        )

        let milestoneEntries = timeline.entries.filter { $0.kind == .milestone }

        #expect(!milestoneEntries.isEmpty)
        #expect(milestoneEntries.allSatisfy { $0.sourceReference.kind == .step })
        #expect(milestoneEntries.allSatisfy { Calendar.current.isDate($0.startDate, inSameDayAs: $0.endDate) })
    }

    @Test
    func planningSnapshotFlagsOpenPredecessorsAndDerivedSchedules() {
        let snapshot = SeedData.makeSampleSnapshot(now: referenceDate)
        let timeline = PlanningTimelineBuilder.snapshot(
            projects: snapshot.projects,
            dependencies: snapshot.dependencies,
            filter: PlanningFilterState(
                showsCompletedItems: true,
                showsOnlyHighPriorityProjects: false,
                showsOnlyBlockedItems: false,
                showsOnlyLinkedItems: false
            ),
            scale: .week,
            projectSortCriterion: .updatedAt,
            now: referenceDate
        )

        let atlasBeta = snapshot.projects[0].steps.first { $0.isMilestone }
        let sketchbook = snapshot.projects[3]
        let betaEntry = timeline.entries.first { $0.id == atlasBeta?.id }
        let sketchProjectEntry = timeline.entries.first { $0.id == sketchbook.id }

        #expect(betaEntry?.hasIncompletePredecessors == true)
        #expect(betaEntry?.blockedPredecessorCount == 1)
        #expect(timeline.edges.contains { $0.targetEntryID == betaEntry?.id && $0.isBlocking })
        #expect(sketchProjectEntry?.scheduleSource.isDerived == true)
    }

    @Test
    func planningSnapshotCanFilterToBlockedTimelineItems() {
        let snapshot = SeedData.makeSampleSnapshot(now: referenceDate)
        let timeline = PlanningTimelineBuilder.snapshot(
            projects: snapshot.projects,
            dependencies: snapshot.dependencies,
            filter: PlanningFilterState(
                showsCompletedItems: true,
                showsOnlyHighPriorityProjects: false,
                showsOnlyBlockedItems: true,
                showsOnlyLinkedItems: false
            ),
            scale: .month,
            projectSortCriterion: .updatedAt,
            now: referenceDate
        )

        #expect(!timeline.entries.isEmpty)
        #expect(timeline.entries.allSatisfy { $0.isBlocked })
        #expect(timeline.summary.blockedEntryCount == timeline.entries.count)
    }

    @Test
    func archivedProjectsAreHiddenByDefaultButCanBeShownExplicitly() {
        let snapshot = SeedData.makeSampleSnapshot(now: referenceDate)
        let archivedProject = snapshot.projects[0]
        archivedProject.archive(at: referenceDate)

        let hiddenTimeline = PlanningTimelineBuilder.snapshot(
            projects: snapshot.projects,
            dependencies: snapshot.dependencies,
            filter: PlanningFilterState(),
            scale: .week,
            projectSortCriterion: .updatedAt,
            now: referenceDate
        )
        let visibleTimeline = PlanningTimelineBuilder.snapshot(
            projects: snapshot.projects,
            dependencies: snapshot.dependencies,
            filter: PlanningFilterState(showsArchivedProjects: true),
            scale: .week,
            projectSortCriterion: .updatedAt,
            now: referenceDate
        )
        let hiddenBubble = BubbleGraphBuilder.scene(
            projects: snapshot.projects,
            dependencies: snapshot.dependencies,
            sizing: .priority,
            grouping: .status,
            filter: BubbleFilterState(),
            focusedProjectID: nil,
            selectedNodeID: nil,
            viewportWidth: 900
        )
        let visibleBubble = BubbleGraphBuilder.scene(
            projects: snapshot.projects,
            dependencies: snapshot.dependencies,
            sizing: .priority,
            grouping: .status,
            filter: BubbleFilterState(showsArchivedProjects: true),
            focusedProjectID: nil,
            selectedNodeID: nil,
            viewportWidth: 900
        )
        let focus = FocusProjectionFactory.snapshot(
            projects: snapshot.projects,
            dependencies: snapshot.dependencies,
            inboxItems: snapshot.inboxItems,
            now: referenceDate
        )

        #expect(hiddenTimeline.entries.contains(where: { $0.projectID == archivedProject.id }) == false)
        #expect(hiddenBubble.graph.nodes.contains(where: { $0.id == archivedProject.id }) == false)
        #expect(visibleTimeline.entries.contains(where: { $0.projectID == archivedProject.id }) == true)
        #expect(visibleBubble.graph.nodes.contains(where: { $0.id == archivedProject.id }) == true)
        #expect(focus.sections.flatMap(\.items).contains(where: { $0.title == archivedProject.title }) == false)
    }

    @Test
    func bubbleGraphUsesOpenStepSizingForRealProjectLoad() {
        let snapshot = SeedData.makeSampleSnapshot(now: referenceDate)
        let scene = BubbleGraphBuilder.scene(
            projects: snapshot.projects,
            dependencies: snapshot.dependencies,
            sizing: .openStepCount,
            grouping: .status,
            filter: BubbleFilterState(
                primaryFilter: .all,
                hidesCompletedProjects: false,
                showsOnlyHighPriorityProjects: false
            ),
            focusedProjectID: nil,
            selectedNodeID: nil,
            viewportWidth: 900
        )

        let atlasNode = scene.graph.nodes.first { $0.id == snapshot.projects[0].id }
        let latticeNode = scene.graph.nodes.first { $0.id == snapshot.projects[2].id }

        #expect(scene.graph.nodes.filter { $0.kind == .project }.count == snapshot.projects.count)
        #expect(scene.summary.visibleConnectionCount == 1)
        #expect((atlasNode?.radius ?? 0) > (latticeNode?.radius ?? .greatestFiniteMagnitude))
    }

    @Test
    func bubbleGraphFocusModeShowsRelevantStepsAndStoredDependencies() {
        let snapshot = SeedData.makeSampleSnapshot(now: referenceDate)
        let atlas = snapshot.projects[0]
        let scene = BubbleGraphBuilder.scene(
            projects: snapshot.projects,
            dependencies: snapshot.dependencies,
            sizing: .priority,
            grouping: .status,
            filter: BubbleFilterState(
                primaryFilter: .all,
                hidesCompletedProjects: true,
                showsOnlyHighPriorityProjects: false
            ),
            focusedProjectID: atlas.id,
            selectedNodeID: atlas.id,
            viewportWidth: 900
        )

        let stepNodes = scene.graph.nodes.filter { $0.clusterParentID == atlas.id }

        #expect(stepNodes.count == 2)
        #expect(stepNodes.contains { $0.kind == .milestone })
        #expect(scene.graph.edges.contains { $0.sourceNodeID == stepNodes.first?.id || $0.targetNodeID == stepNodes.first?.id })
        #expect(scene.inspector?.incomingDependencies.count == 1)
    }

    @Test
    func bubbleLayoutIsDeterministicForSameInput() {
        let snapshot = SeedData.makeSampleSnapshot(now: referenceDate)
        let firstScene = BubbleGraphBuilder.scene(
            projects: snapshot.projects,
            dependencies: snapshot.dependencies,
            sizing: .dependencyCount,
            grouping: .priority,
            filter: BubbleFilterState(
                primaryFilter: .all,
                hidesCompletedProjects: false,
                showsOnlyHighPriorityProjects: false
            ),
            focusedProjectID: snapshot.projects[2].id,
            selectedNodeID: snapshot.projects[2].id,
            viewportWidth: 980
        )
        let secondScene = BubbleGraphBuilder.scene(
            projects: snapshot.projects,
            dependencies: snapshot.dependencies,
            sizing: .dependencyCount,
            grouping: .priority,
            filter: BubbleFilterState(
                primaryFilter: .all,
                hidesCompletedProjects: false,
                showsOnlyHighPriorityProjects: false
            ),
            focusedProjectID: snapshot.projects[2].id,
            selectedNodeID: snapshot.projects[2].id,
            viewportWidth: 980
        )

        #expect(firstScene.graph.nodes.count == secondScene.graph.nodes.count)

        for node in firstScene.graph.nodes {
            let other = secondScene.graph.nodes.first { $0.id == node.id }
            #expect(other != nil)
            #expect(abs((other?.position.x ?? 0) - node.position.x) < 0.001)
            #expect(abs((other?.position.y ?? 0) - node.position.y) < 0.001)
        }
    }

    @Test
    func bootstrapLeavesEmptyStoresEmptyExceptForPreferences() throws {
        let container = try PersistenceController.makeModelContainer(
            isStoredInMemoryOnly: true,
            enableCloudKitSync: false
        )
        let context = container.mainContext

        try DataBootstrapper.seedIfNeeded(in: context)
        try DataBootstrapper.seedIfNeeded(in: context)

        let projectCount = try context.fetchCount(FetchDescriptor<Project>())
        let inboxCount = try context.fetchCount(FetchDescriptor<IdeaInboxItem>())
        let dependencyCount = try context.fetchCount(FetchDescriptor<Dependency>())
        let preferenceCount = try context.fetchCount(FetchDescriptor<VisualizationPreferences>())

        #expect(projectCount == 0)
        #expect(inboxCount == 0)
        #expect(dependencyCount == 0)
        #expect(preferenceCount == 1)
    }

    @Test
    func bootstrapRemovesLegacySampleContent() throws {
        let container = try PersistenceController.makeModelContainer(
            isStoredInMemoryOnly: true,
            enableCloudKitSync: false
        )
        let context = container.mainContext

        SeedData.installSampleContent(in: context)
        try context.save()

        try DataBootstrapper.seedIfNeeded(in: context)

        let projectCount = try context.fetchCount(FetchDescriptor<Project>())
        let inboxCount = try context.fetchCount(FetchDescriptor<IdeaInboxItem>())
        let dependencyCount = try context.fetchCount(FetchDescriptor<Dependency>())
        let preferenceCount = try context.fetchCount(FetchDescriptor<VisualizationPreferences>())

        #expect(projectCount == 0)
        #expect(inboxCount == 0)
        #expect(dependencyCount == 0)
        #expect(preferenceCount == 1)
    }

    @Test
    func samplePreferencesAreSingletonScoped() {
        let snapshot = SeedData.makeSampleSnapshot(now: referenceDate)

        #expect(snapshot.preferences.scope == VisualizationPreferences.defaultScope)
        #expect(snapshot.preferences.showsOnlyHighPriorityProjects == false)
        #expect(snapshot.preferences.appColorTheme == .emberDusk)
        #expect(snapshot.preferences.bubbleGroupingMode == .status)
        #expect(snapshot.preferences.timelineScale == .week)
    }

    @Test
    func visualizationPreferencesRepairLegacyDefaultsRestoresMissingEnums() {
        let preferences = VisualizationPreferences.default
        preferences.appColorTheme = nil
        preferences.bubbleGroupingMode = nil
        preferences.timelineScale = nil

        let didRepair = preferences.repairLegacyDefaults()

        #expect(didRepair == true)
        #expect(preferences.appColorTheme == .emberDusk)
        #expect(preferences.bubbleGroupingMode == .status)
        #expect(preferences.timelineScale == .week)
    }

    @Test
    func bootstrapRepairsLegacyPreferenceDefaults() throws {
        let container = try PersistenceController.makeModelContainer(
            isStoredInMemoryOnly: true,
            enableCloudKitSync: false
        )
        let context = container.mainContext
        let preferences = VisualizationPreferences.default
        preferences.appColorTheme = nil
        preferences.bubbleGroupingMode = nil
        preferences.timelineScale = nil
        context.insert(preferences)
        try context.save()

        try DataBootstrapper.seedIfNeeded(in: context)

        let storedPreferences = try #require(context.fetch(FetchDescriptor<VisualizationPreferences>()).first)
        #expect(storedPreferences.appColorTheme == .emberDusk)
        #expect(storedPreferences.bubbleGroupingMode == .status)
        #expect(storedPreferences.timelineScale == .week)
    }

    @Test
    func seedSnapshotProvidesInboxLifecycleCoverage() {
        let snapshot = SeedData.makeSampleSnapshot(now: referenceDate)
        let inboxSnapshot = InboxProjectionFactory.snapshot(items: snapshot.inboxItems, filter: .all)

        #expect(snapshot.inboxItems.count == 4)
        #expect(inboxSnapshot.newCount == 1)
        #expect(inboxSnapshot.reviewingCount == 1)
        #expect(inboxSnapshot.convertedCount == 1)
        #expect(inboxSnapshot.archivedCount == 1)
        #expect(inboxSnapshot.triageCount == 2)
    }

    @Test
    func inboxConversionToProjectPreservesSourceContext() {
        let item = IdeaInboxItem(
            title: "Turn cockpit notes into a project",
            body: "Capture the daily working loop and test it against real blocked work.",
            state: .open,
            tags: ["focus", "workflow"],
            priorityHint: .high,
            source: .manualCapture
        )

        let result = InboxWorkflow.convert(
            item,
            using: .newProject(InboxWorkflow.makeProjectDraft(for: item)),
            now: referenceDate
        )

        #expect(item.state == .converted)
        #expect(item.linkedProject === result.targetProject)
        #expect(item.linkedStep == nil)
        #expect(item.convertedAt == referenceDate)
        #expect(item.conversionTarget == .project)
        #expect(result.createdProject === result.targetProject)
        #expect(result.targetProject.summary.contains("daily working loop"))
        #expect(result.targetProject.tags.contains("focus"))
        #expect(result.targetProject.tags.contains("workflow"))
        #expect(result.targetProject.tags.contains("inbox"))
    }

    @Test
    func inboxConversionToExistingStepLinksProjectAndStep() {
        let project = Project.starter(title: "Atlas", now: referenceDate)
        let item = IdeaInboxItem(
            title: "Hook share sheet into capture flow",
            body: "Use the current project shell instead of inventing a second capture surface.",
            state: .reviewing,
            tags: ["capture", "share"],
            priorityHint: .urgent,
            source: .shareSheet
        )
        let draft = InboxWorkflow.makeStepDraft(for: item, project: project)

        let result = InboxWorkflow.convert(
            item,
            using: .projectStep(
                InboxStepConversionDraft(
                    project: project,
                    title: draft.title,
                    notes: draft.notes,
                    kind: .task,
                    status: .idea,
                    priority: .urgent,
                    startDate: draft.startDate,
                    dueDate: draft.dueDate
                )
            ),
            now: referenceDate
        )

        #expect(result.createdProject == nil)
        #expect(project.steps.count == 1)
        #expect(item.state == .converted)
        #expect(item.linkedProject === project)
        #expect(item.linkedStep?.title == "Hook share sheet into capture flow")
        #expect(item.conversionTarget == .task)
        #expect(project.tags.contains("capture"))
        #expect(project.tags.contains("share"))
    }

    @Test
    func inboxItemTagsStayNonOptionalAtCallSites() {
        let item = IdeaInboxItem(title: "Inbox")

        #expect(item.tags.isEmpty)
        #expect(item.tagsStorage == nil)

        item.tags = [" focus ", "Focus", "", "workflow "]

        #expect(item.tags == ["focus", "workflow"])
        #expect(item.tagsStorage == ["focus", "workflow"])

        item.tags = []

        #expect(item.tags.isEmpty)
        #expect(item.tagsStorage == nil)
    }

    @Test
    func deletingStepRemovesDependenciesAndReopensLinkedInboxItem() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let project = Project.starter(title: "Atlas", now: referenceDate)
        let otherProject = Project.starter(title: "Pulse", now: referenceDate)
        let step = project.addStep(title: "Wire quick actions")
        let target = otherProject.addStep(title: "Render dependency view")
        let dependency = Dependency(
            sourceKind: .step,
            sourceItemID: step.id,
            targetKind: .step,
            targetItemID: target.id
        )
        let item = IdeaInboxItem(title: "Recovered from deleted step")
        item.markConverted(target: .task, project: project, step: step, at: referenceDate)

        context.insert(project)
        context.insert(otherProject)
        context.insert(dependency)
        context.insert(item)
        try context.save()

        try PlanningMutationWorkflow.deleteStep(step, in: context, now: referenceDate)
        try context.save()

        let storedDependencies = try context.fetch(FetchDescriptor<Dependency>())
        let storedProjects = try context.fetch(FetchDescriptor<Project>())
        let storedItems = try context.fetch(FetchDescriptor<IdeaInboxItem>())

        #expect(storedDependencies.isEmpty)
        #expect(storedProjects.first(where: { $0.id == project.id })?.steps.isEmpty == true)
        #expect(storedItems.first?.state == .reviewing)
        #expect(storedItems.first?.linkedProject == nil)
        #expect(storedItems.first?.linkedStep == nil)
        #expect(storedItems.first?.convertedAt == nil)
        #expect(storedItems.first?.conversionTarget == nil)
    }

    @Test
    func deletingProjectRemovesDependenciesAndReopensLinkedInboxItem() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let project = Project.starter(title: "Atlas", now: referenceDate)
        let linkedStep = project.addStep(title: "Inspect deletion flow")
        let otherProject = Project.starter(title: "Pulse", now: referenceDate)
        let dependency = Dependency(
            sourceKind: .project,
            sourceItemID: project.id,
            targetKind: .project,
            targetItemID: otherProject.id
        )
        let item = IdeaInboxItem(title: "Recovered from deleted project")
        item.markConverted(target: .project, project: project, step: linkedStep, at: referenceDate)

        context.insert(project)
        context.insert(otherProject)
        context.insert(dependency)
        context.insert(item)
        try context.save()

        try PlanningMutationWorkflow.deleteProject(project, in: context, now: referenceDate)
        try context.save()

        let storedProjects = try context.fetch(FetchDescriptor<Project>())
        let storedDependencies = try context.fetch(FetchDescriptor<Dependency>())
        let storedItems = try context.fetch(FetchDescriptor<IdeaInboxItem>())

        #expect(storedProjects.count == 1)
        #expect(storedProjects.first?.title == "Pulse")
        #expect(storedDependencies.isEmpty)
        #expect(storedItems.first?.state == .reviewing)
        #expect(storedItems.first?.linkedProject == nil)
        #expect(storedItems.first?.linkedStep == nil)
        #expect(storedItems.first?.convertedAt == nil)
    }

    @Test
    func focusProjectionHighlightsBlockedWorkMilestonesAndInboxTriage() {
        let snapshot = SeedData.makeSampleSnapshot(now: referenceDate)
        let focus = FocusProjectionFactory.snapshot(
            projects: snapshot.projects,
            dependencies: snapshot.dependencies,
            inboxItems: snapshot.inboxItems,
            now: referenceDate
        )

        let blockedSection = focus.sections.first { $0.kind == .blocked }
        let inboxSection = focus.sections.first { $0.kind == .inbox }
        let milestoneSection = focus.sections.first { $0.kind == .milestones }

        #expect(focus.activeProjectCount == 2)
        #expect(focus.triageCount == 2)
        #expect(blockedSection?.items.contains(where: { $0.title == "Dependency Lattice" }) == true)
        #expect(inboxSection?.items.count == 2)
        #expect(inboxSection?.items.contains(where: { $0.kind == .inbox }) == true)
        #expect(milestoneSection?.items.contains(where: { $0.kind == .milestone }) == true)
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
        project.setStatus(.done)
        project.setProgress(0.4)
        step.setStatus(.done)
        step.setProgress(0.3)

        #expect(project.progress == 0.4)
        #expect(project.dueDate == referenceDate)
        #expect(project.status == .active)
        #expect(step.progress == 0.3)
        #expect(step.dueDate == referenceDate)
        #expect(step.isMilestone)
        #expect(step.status == .active)
    }

    private var referenceDate: Date {
        Date(timeIntervalSince1970: 1_775_520_000)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        try PersistenceController.makeModelContainer(
            isStoredInMemoryOnly: true,
            enableCloudKitSync: false
        )
    }
}
