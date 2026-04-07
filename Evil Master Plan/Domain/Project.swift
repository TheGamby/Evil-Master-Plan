import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var title: String
    var summary: String
    var status: ProjectStatus
    var priority: PriorityLevel
    var progress: Double
    var createdAt: Date
    var updatedAt: Date
    var startDate: Date?
    var dueDate: Date?
    var tags: [String]
    var colorToken: ProjectColorToken
    @Relationship(deleteRule: .cascade, inverse: \ProjectStep.project) var steps: [ProjectStep]

    init(
        id: UUID = UUID(),
        title: String,
        summary: String = "",
        status: ProjectStatus = .idea,
        priority: PriorityLevel = .medium,
        progress: Double = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        startDate: Date? = nil,
        dueDate: Date? = nil,
        tags: [String] = [],
        colorToken: ProjectColorToken = .ember,
        steps: [ProjectStep] = []
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.status = status
        self.priority = priority
        self.progress = min(max(progress, 0), 1)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.startDate = startDate
        self.dueDate = dueDate
        self.tags = tags
        self.colorToken = colorToken
        self.steps = steps
    }
}

extension Project {
    static func starter(title: String = "New Project", now: Date = .now) -> Project {
        Project(
            title: title,
            summary: "Define the direction, then break it into a few visible steps.",
            status: .idea,
            priority: .medium,
            progress: 0.05,
            createdAt: now,
            updatedAt: now,
            startDate: now,
            dueDate: Calendar.current.date(byAdding: .day, value: 21, to: now),
            tags: ["new"],
            colorToken: .cobalt
        )
    }

    var sortedSteps: [ProjectStep] {
        steps.sorted(using: SortDescriptor(\.sortOrder))
    }

    var resolvedStartDate: Date? {
        startDate ?? steps.compactMap(\.startDate).min()
    }

    var resolvedDueDate: Date? {
        dueDate ?? steps.compactMap(\.dueDate).max()
    }

    var milestoneCount: Int {
        steps.filter(\.isMilestone).count
    }

    func touch(at date: Date = .now) {
        updatedAt = date
    }
}
