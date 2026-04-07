import SwiftData

extension ModelContext {
    func saveIfNeeded() throws {
        guard hasChanges else {
            return
        }

        try save()
    }
}
