import Foundation
import SwiftData

@Model
final class VisualizationPreferences {
    static let defaultScope = "app-default"

    @Attribute(.unique) var scope: String
    var bubbleSizingCriterion: BubbleSizingCriterion
    var projectSortCriterion: ProjectSortCriterion
    var showsCompletedItems: Bool
    var showsOnlyHighPriorityProjects: Bool

    init(
        scope: String = VisualizationPreferences.defaultScope,
        bubbleSizingCriterion: BubbleSizingCriterion = .priority,
        projectSortCriterion: ProjectSortCriterion = .updatedAt,
        showsCompletedItems: Bool = true,
        showsOnlyHighPriorityProjects: Bool = false
    ) {
        self.scope = scope
        self.bubbleSizingCriterion = bubbleSizingCriterion
        self.projectSortCriterion = projectSortCriterion
        self.showsCompletedItems = showsCompletedItems
        self.showsOnlyHighPriorityProjects = showsOnlyHighPriorityProjects
    }
}

extension VisualizationPreferences {
    static var `default`: VisualizationPreferences {
        VisualizationPreferences()
    }
}
