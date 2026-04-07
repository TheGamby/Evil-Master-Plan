import Foundation

enum AppDestination: String, CaseIterable, Identifiable, Hashable {
    case dashboard
    case projects
    case bubbleNetwork
    case gantt
    case dependencies
    case inbox
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            "Dashboard"
        case .projects:
            "Projects"
        case .bubbleNetwork:
            "Bubble Network"
        case .gantt:
            "Gantt"
        case .dependencies:
            "Dependencies"
        case .inbox:
            "Inbox"
        case .settings:
            "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:
            "sparkles.rectangle.stack"
        case .projects:
            "list.bullet.rectangle.portrait"
        case .bubbleNetwork:
            "point.3.connected.trianglepath.dotted"
        case .gantt:
            "chart.bar.xaxis"
        case .dependencies:
            "arrow.triangle.branch"
        case .inbox:
            "tray.and.arrow.down"
        case .settings:
            "slider.horizontal.3"
        }
    }

    var subtitle: String {
        switch self {
        case .dashboard:
            "Focus and movement"
        case .projects:
            "Plan the work"
        case .bubbleNetwork:
            "See structure at a glance"
        case .gantt:
            "Map timing"
        case .dependencies:
            "Track sequencing"
        case .inbox:
            "Capture fast"
        case .settings:
            "Tune visualization"
        }
    }
}
