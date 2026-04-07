import SwiftUI
import SwiftData

@main
struct Evil_Master_PlanApp: App {
    private let modelContainer = PersistenceController.makeDefaultContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
