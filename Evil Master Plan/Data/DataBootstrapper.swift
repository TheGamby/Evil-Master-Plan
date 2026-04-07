import Foundation
import SwiftData

@MainActor
enum DataBootstrapper {
    static func seedIfNeeded(in context: ModelContext) throws {
        let projectCount = try context.fetchCount(FetchDescriptor<Project>())
        let inboxCount = try context.fetchCount(FetchDescriptor<IdeaInboxItem>())
        let preferencesCount = try context.fetchCount(FetchDescriptor<VisualizationPreferences>())

        if projectCount == 0 && inboxCount == 0 {
            SeedData.installSampleContent(
                in: context,
                includePreferences: preferencesCount == 0
            )
        } else if preferencesCount == 0 {
            context.insert(VisualizationPreferences.default)
        }

        try context.saveIfNeeded()
    }
}
