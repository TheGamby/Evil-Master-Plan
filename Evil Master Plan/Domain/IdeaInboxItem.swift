import Foundation
import SwiftData

@Model
final class IdeaInboxItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date
    var state: IdeaInboxState
    @Relationship var linkedProject: Project?

    init(
        id: UUID = UUID(),
        title: String,
        body: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        state: IdeaInboxState = .open,
        linkedProject: Project? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.state = state
        self.linkedProject = linkedProject
    }
}

extension IdeaInboxItem {
    func touch(at date: Date = .now) {
        updatedAt = date
    }
}
