import CoreGraphics
import Foundation

enum BubblePrimaryFilter: String, CaseIterable, Identifiable {
    case all
    case active
    case blocked

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            "All Projects"
        case .active:
            "Active"
        case .blocked:
            "Blocked"
        }
    }
}

struct BubbleFilterState: Equatable {
    var primaryFilter: BubblePrimaryFilter = .all
    var hidesCompletedProjects: Bool = true
    var showsOnlyHighPriorityProjects: Bool = false
    var showsArchivedProjects: Bool = false
}

enum BubbleNodeKind: String, Identifiable {
    case project
    case task
    case milestone

    var id: String { rawValue }

    var title: String {
        switch self {
        case .project:
            "Project"
        case .task:
            "Task"
        case .milestone:
            "Milestone"
        }
    }
}

struct BubbleGroup: Identifiable {
    let id: String
    let title: String
    let frame: CGRect
    let nodeCount: Int
}

struct BubbleNode: Identifiable {
    let id: UUID
    let sourceReference: PlanningItemReference
    let title: String
    let subtitle: String?
    let kind: BubbleNodeKind
    let status: ProjectStatus
    let priority: PriorityLevel
    let progress: Double
    let dueDate: Date?
    let colorToken: ProjectColorToken
    let position: CGPoint
    let radius: CGFloat
    let openStepCount: Int
    let dependencyCount: Int
    let isBlocked: Bool
    let isFocused: Bool
    let isSelected: Bool
    let isConnectedToSelection: Bool
    let isDimmed: Bool
    let groupID: String
    let groupTitle: String
    let clusterParentID: UUID?
}

struct BubbleEdge: Identifiable {
    let id: UUID
    let sourceNodeID: UUID
    let targetNodeID: UUID
    let type: DependencyType
    let weight: Double
    let isHighlighted: Bool
}

struct BubbleGraph {
    let nodes: [BubbleNode]
    let edges: [BubbleEdge]
    let groups: [BubbleGroup]
    let canvasSize: CGSize
}

struct BubbleGraphSummary {
    let visibleProjectCount: Int
    let blockedProjectCount: Int
    let visibleConnectionCount: Int
    let focusedStepCount: Int
}

struct BubbleInspectorDependency: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let type: DependencyType
    let note: String
}

struct BubbleInspectorMilestone: Identifiable {
    let id: UUID
    let title: String
    let dueDate: Date?
}

struct BubbleInspectorContext {
    let nodeID: UUID
    let sourceReference: PlanningItemReference
    let projectID: UUID
    let title: String
    let subtitle: String
    let kind: BubbleNodeKind
    let status: ProjectStatus
    let priority: PriorityLevel
    let progress: Double
    let dueDate: Date?
    let isBlocked: Bool
    let openStepCount: Int
    let blockedStepCount: Int
    let dependencyCount: Int
    let projectTitle: String
    let upcomingMilestones: [BubbleInspectorMilestone]
    let incomingDependencies: [BubbleInspectorDependency]
    let outgoingDependencies: [BubbleInspectorDependency]
}

struct BubbleNetworkScene {
    let graph: BubbleGraph
    let summary: BubbleGraphSummary
    let inspector: BubbleInspectorContext?
}
