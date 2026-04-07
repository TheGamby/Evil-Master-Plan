import Foundation
import SwiftData

@MainActor
enum DataBootstrapper {
    static func seedIfNeeded(in context: ModelContext) throws {
        let projectCount = try context.fetchCount(FetchDescriptor<Project>())
        let inboxCount = try context.fetchCount(FetchDescriptor<IdeaInboxItem>())
        let preferencesCount = try context.fetchCount(FetchDescriptor<ViewPreferences>())

        if projectCount == 0 && inboxCount == 0 {
            let snapshot = SeedData.makeSampleSnapshot()
            snapshot.projects.forEach(context.insert)
            snapshot.dependencies.forEach(context.insert)
            snapshot.inboxItems.forEach(context.insert)

            if preferencesCount == 0 {
                context.insert(snapshot.preferences)
            }
        } else if preferencesCount == 0 {
            context.insert(ViewPreferences.default)
        }

        try context.save()
    }
}
