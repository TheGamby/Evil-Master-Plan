import Foundation
import SwiftData

@MainActor
enum PreviewContainer {
    static let shared: ModelContainer = {
        let container = PersistenceController.makePreviewContainer()
        do {
            try DataBootstrapper.seedIfNeeded(in: container.mainContext)
        } catch {
            assertionFailure("Failed to seed preview container: \(error.localizedDescription)")
        }
        return container
    }()
}
