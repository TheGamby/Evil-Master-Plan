import Foundation

enum ProjectStatus: String, Codable, CaseIterable, Identifiable {
    case idea
    case active
    case paused
    case blocked
    case done

    var id: String { rawValue }

    var title: String {
        switch self {
        case .idea:
            "Idea"
        case .active:
            "Active"
        case .paused:
            "Paused"
        case .blocked:
            "Blocked"
        case .done:
            "Done"
        }
    }
}

enum PriorityLevel: String, Codable, CaseIterable, Identifiable, Comparable {
    case low
    case medium
    case high
    case urgent

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var rank: Int {
        switch self {
        case .low:
            0
        case .medium:
            1
        case .high:
            2
        case .urgent:
            3
        }
    }

    static func < (lhs: PriorityLevel, rhs: PriorityLevel) -> Bool {
        lhs.rank < rhs.rank
    }

    var isHighPriority: Bool {
        self >= .high
    }
}

enum ProjectStepKind: String, Codable, CaseIterable, Identifiable {
    case task
    case milestone

    var id: String { rawValue }

    var title: String {
        switch self {
        case .task:
            "Task"
        case .milestone:
            "Milestone"
        }
    }
}

enum DependencyType: String, Codable, CaseIterable, Identifiable {
    case finishToStart
    case startToStart
    case finishToFinish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .finishToStart:
            "Finish to Start"
        case .startToStart:
            "Start to Start"
        case .finishToFinish:
            "Finish to Finish"
        }
    }
}

enum PlanningItemKind: String, Codable, CaseIterable, Identifiable {
    case project
    case step

    var id: String { rawValue }
}

enum ProjectColorToken: String, Codable, CaseIterable, Identifiable {
    case ember
    case cyan
    case lime
    case cobalt
    case rose

    var id: String { rawValue }
}

enum IdeaInboxState: String, Codable, CaseIterable, Identifiable {
    case open
    case converted
    case archived

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }
}

enum BubbleSizingCriterion: String, Codable, CaseIterable, Identifiable {
    case progress
    case priority
    case dependencyCount

    var id: String { rawValue }

    var title: String {
        switch self {
        case .progress:
            "Progress"
        case .priority:
            "Priority"
        case .dependencyCount:
            "Dependency Count"
        }
    }
}

enum ProjectSortCriterion: String, Codable, CaseIterable, Identifiable {
    case updatedAt
    case priority
    case dueDate
    case progress

    var id: String { rawValue }

    var title: String {
        switch self {
        case .updatedAt:
            "Recently Updated"
        case .priority:
            "Priority"
        case .dueDate:
            "Due Date"
        case .progress:
            "Progress"
        }
    }
}

enum GanttRowKind: String, Codable, CaseIterable, Identifiable {
    case project
    case task
    case milestone

    var id: String { rawValue }
}
