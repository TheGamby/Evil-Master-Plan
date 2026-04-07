import Foundation
import SwiftData

@MainActor
enum PreviewContainer {
    static let shared: ModelContainer = {
        let container = PersistenceController.makePreviewContainer()
        SeedData.installSampleContent(in: container.mainContext)
        try? container.mainContext.save()
        return container
    }()
}
