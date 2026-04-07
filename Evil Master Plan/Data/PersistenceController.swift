import Foundation
import SwiftData

enum PersistenceController {
    static let schema = Schema([
        Project.self,
        ProjectStep.self,
        Dependency.self,
        IdeaInboxItem.self,
        ViewPreferences.self,
    ])

    static func makeDefaultContainer(enableCloudKitSync: Bool = false) -> ModelContainer {
        do {
            return try makeModelContainer(
                isStoredInMemoryOnly: false,
                enableCloudKitSync: enableCloudKitSync
            )
        } catch {
            fatalError("Unable to create SwiftData container: \(error.localizedDescription)")
        }
    }

    static func makePreviewContainer() -> ModelContainer {
        do {
            return try makeModelContainer(isStoredInMemoryOnly: true, enableCloudKitSync: false)
        } catch {
            fatalError("Unable to create preview container: \(error.localizedDescription)")
        }
    }

    static func makeModelContainer(
        isStoredInMemoryOnly: Bool,
        enableCloudKitSync: Bool
    ) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "EMPStore",
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly,
            allowsSave: true,
            groupContainer: .automatic,
            cloudKitDatabase: enableCloudKitSync && !isStoredInMemoryOnly ? .automatic : .none
        )

        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }
}
