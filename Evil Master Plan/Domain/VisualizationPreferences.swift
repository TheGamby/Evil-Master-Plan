import Foundation
import SwiftData

@Model
final class VisualizationPreferences {
    static let defaultScope = "app-default"

    @Attribute(.unique) var scope: String
    var appColorTheme: AppColorTheme?
    var bubbleSizingCriterion: BubbleSizingCriterion
    var bubbleGroupingMode: BubbleGroupingMode?
    var timelineScale: TimelineScale?
    var projectSortCriterion: ProjectSortCriterion
    var showsCompletedItems: Bool
    var showsOnlyHighPriorityProjects: Bool

    init(
        scope: String = VisualizationPreferences.defaultScope,
        appColorTheme: AppColorTheme = AppTheme.defaultStyle,
        bubbleSizingCriterion: BubbleSizingCriterion = .priority,
        bubbleGroupingMode: BubbleGroupingMode = .status,
        timelineScale: TimelineScale = .week,
        projectSortCriterion: ProjectSortCriterion = .updatedAt,
        showsCompletedItems: Bool = true,
        showsOnlyHighPriorityProjects: Bool = false
    ) {
        self.scope = scope
        self.appColorTheme = appColorTheme
        self.bubbleSizingCriterion = bubbleSizingCriterion
        self.bubbleGroupingMode = bubbleGroupingMode
        self.timelineScale = timelineScale
        self.projectSortCriterion = projectSortCriterion
        self.showsCompletedItems = showsCompletedItems
        self.showsOnlyHighPriorityProjects = showsOnlyHighPriorityProjects
    }
}

extension VisualizationPreferences {
    static var `default`: VisualizationPreferences {
        VisualizationPreferences()
    }

    @discardableResult
    func repairLegacyDefaults() -> Bool {
        var didChange = false

        if appColorTheme == nil {
            appColorTheme = AppTheme.defaultStyle
            didChange = true
        }

        if bubbleGroupingMode == nil {
            bubbleGroupingMode = .status
            didChange = true
        }

        if timelineScale == nil {
            timelineScale = .week
            didChange = true
        }

        return didChange
    }
}
