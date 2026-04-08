import Foundation

enum ProjectStatus: String, Codable, CaseIterable, Identifiable {
    case idea
    case active
    case paused
    case blocked
    case done

    var id: String { rawValue }

    nonisolated var title: String {
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

    var isOpen: Bool {
        self != .done
    }

    var countsAsStarted: Bool {
        switch self {
        case .idea, .paused:
            false
        case .active, .blocked, .done:
            true
        }
    }

    var countsAsCompleted: Bool {
        self == .done
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

    nonisolated var rank: Int {
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
    case reviewing
    case converted
    case archived

    var id: String { rawValue }

    var title: String {
        switch self {
        case .open:
            "New"
        case .reviewing:
            "Reviewing"
        case .converted:
            "Converted"
        case .archived:
            "Archived"
        }
    }

    nonisolated var needsTriage: Bool {
        switch self {
        case .open, .reviewing:
            true
        case .converted, .archived:
            false
        }
    }

    nonisolated var sortRank: Int {
        switch self {
        case .open:
            0
        case .reviewing:
            1
        case .converted:
            2
        case .archived:
            3
        }
    }
}

enum IdeaInboxSource: String, Codable, CaseIterable, Identifiable {
    case manualCapture
    case shareSheet
    case voiceMemo
    case imported

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manualCapture:
            "Manual"
        case .shareSheet:
            "Share Sheet"
        case .voiceMemo:
            "Voice Memo"
        case .imported:
            "Imported"
        }
    }
}

enum IdeaInboxConversionTarget: String, Codable, CaseIterable, Identifiable {
    case project
    case task
    case milestone

    var id: String { rawValue }

    var title: String {
        switch self {
        case .project:
            "Project"
        case .task:
            "Step"
        case .milestone:
            "Milestone"
        }
    }
}

enum InboxListFilter: String, CaseIterable, Identifiable {
    case triage
    case reviewing
    case converted
    case archived
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .triage:
            "Needs Triage"
        case .reviewing:
            "Reviewing"
        case .converted:
            "Converted"
        case .archived:
            "Archived"
        case .all:
            "All"
        }
    }
}

enum FocusSectionKind: String, CaseIterable, Identifiable {
    case nowImportant
    case blocked
    case nextSteps
    case inbox
    case milestones

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nowImportant:
            "Now Important"
        case .blocked:
            "Blocked"
        case .nextSteps:
            "Next Sensible Steps"
        case .inbox:
            "Inbox Review"
        case .milestones:
            "Milestones Soon"
        }
    }

    var subtitle: String {
        switch self {
        case .nowImportant:
            "Projects that are active, high leverage, or close enough to matter right now."
        case .blocked:
            "Things that are stalled by status or dependencies and should not stay invisible."
        case .nextSteps:
            "Concrete work items that are open, actionable, and aligned with active projects."
        case .inbox:
            "Loose capture that should be reviewed before it turns into noise."
        case .milestones:
            "Upcoming checkpoints worth keeping in sight while planning the week."
        }
    }

    var emptyTitle: String {
        switch self {
        case .nowImportant:
            "No Immediate Pressure"
        case .blocked:
            "No Visible Blockers"
        case .nextSteps:
            "No Next Steps Selected"
        case .inbox:
            "Inbox Triage Is Clear"
        case .milestones:
            "No Near Milestones"
        }
    }

    var emptyMessage: String {
        switch self {
        case .nowImportant:
            "Active and time-sensitive projects will surface here."
        case .blocked:
            "Blocked work from projects or dependencies will show up here."
        case .nextSteps:
            "Open steps from active or high-priority projects will populate this lane."
        case .inbox:
            "New and reviewing inbox items will return here when they need a decision."
        case .milestones:
            "Open milestones with nearby due dates will appear here."
        }
    }
}

enum FocusItemKind: String, Identifiable {
    case project
    case step
    case milestone
    case inbox

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .project:
            "square.stack.3d.up.fill"
        case .step:
            "checklist"
        case .milestone:
            "flag.checkered.2.crossed"
        case .inbox:
            "tray.and.arrow.down.fill"
        }
    }
}

enum BubbleSizingCriterion: String, Codable, CaseIterable, Identifiable {
    case progress
    case priority
    case dependencyCount
    case openStepCount

    var id: String { rawValue }

    var title: String {
        switch self {
        case .progress:
            "Progress"
        case .priority:
            "Priority"
        case .dependencyCount:
            "Dependency Count"
        case .openStepCount:
            "Open Step Count"
        }
    }
}

enum BubbleGroupingMode: String, Codable, CaseIterable, Identifiable {
    case status
    case priority

    var id: String { rawValue }

    var title: String {
        switch self {
        case .status:
            "Status"
        case .priority:
            "Priority"
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

enum TimelineScale: String, Codable, CaseIterable, Identifiable {
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week:
            "Week"
        case .month:
            "Month"
        }
    }
}
