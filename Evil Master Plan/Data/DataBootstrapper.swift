import Foundation
import SwiftData

@MainActor
enum DataBootstrapper {
    static func seedIfNeeded(in context: ModelContext) throws {
        let preferenceDescriptor = FetchDescriptor<VisualizationPreferences>()
        let preferencesCount = try context.fetchCount(preferenceDescriptor)
        let didRemoveLegacySampleContent = try removeLegacySampleContent(in: context)

        if preferencesCount == 0 {
            context.insert(VisualizationPreferences.default)
        }

        let preferences = try context.fetch(preferenceDescriptor)
        let didRepairAnyPreference = preferences.reduce(false) { didRepair, preference in
            preference.repairLegacyDefaults() || didRepair
        }

        if didRepairAnyPreference {
            try context.saveIfNeeded()
        }

        if didRemoveLegacySampleContent {
            try context.saveIfNeeded()
        }

        try context.saveIfNeeded()
    }

    private static func removeLegacySampleContent(in context: ModelContext) throws -> Bool {
        let projects = try context.fetch(FetchDescriptor<Project>())
        let sampleProjects = projects.filter(SeedData.isSampleProject)
        let inboxItems = try context.fetch(FetchDescriptor<IdeaInboxItem>())
        let sampleInboxItems = inboxItems.filter(SeedData.isSampleInboxItem)

        guard !sampleProjects.isEmpty || !sampleInboxItems.isEmpty else {
            return false
        }

        let sampleProjectIDs = Set(sampleProjects.map(\.id))
        let sampleStepIDs = Set(sampleProjects.flatMap(\.steps).map(\.id))
        let sampleInboxIDs = Set(sampleInboxItems.map(\.id))
        let dependencies = try context.fetch(FetchDescriptor<Dependency>())
        var didRemoveAnyContent = false

        for dependency in dependencies where
            (dependency.sourceKind == .project && sampleProjectIDs.contains(dependency.sourceItemID)) ||
            (dependency.targetKind == .project && sampleProjectIDs.contains(dependency.targetItemID)) ||
            (dependency.sourceKind == .step && sampleStepIDs.contains(dependency.sourceItemID)) ||
            (dependency.targetKind == .step && sampleStepIDs.contains(dependency.targetItemID)) {
            context.delete(dependency)
            didRemoveAnyContent = true
        }

        for item in inboxItems where !sampleInboxIDs.contains(item.id) {
            let linksSampleProject = item.linkedProject.map { sampleProjectIDs.contains($0.id) } ?? false
            let linksSampleStep = item.linkedStep.map { sampleStepIDs.contains($0.id) } ?? false

            if linksSampleProject || linksSampleStep {
                item.unlinkDeletedTarget()
                didRemoveAnyContent = true
            }
        }

        for item in sampleInboxItems {
            context.delete(item)
            didRemoveAnyContent = true
        }

        for project in sampleProjects {
            context.delete(project)
            didRemoveAnyContent = true
        }

        return didRemoveAnyContent
    }
}
