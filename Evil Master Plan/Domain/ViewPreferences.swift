import Foundation
import SwiftData

@Model
final class ViewPreferences {
    @Attribute(.unique) var id: UUID
    var bubbleSizingCriterion: BubbleSizingCriterion
    var projectSortCriterion: ProjectSortCriterion
    var showCompletedItems: Bool
    var highlightOnlyHighPriority: Bool

    init(
        id: UUID = UUID(),
        bubbleSizingCriterion: BubbleSizingCriterion = .priority,
        projectSortCriterion: ProjectSortCriterion = .updatedAt,
        showCompletedItems: Bool = true,
        highlightOnlyHighPriority: Bool = false
    ) {
        self.id = id
        self.bubbleSizingCriterion = bubbleSizingCriterion
        self.projectSortCriterion = projectSortCriterion
        self.showCompletedItems = showCompletedItems
        self.highlightOnlyHighPriority = highlightOnlyHighPriority
    }
}

extension ViewPreferences {
    static var `default`: ViewPreferences {
        ViewPreferences()
    }
}
