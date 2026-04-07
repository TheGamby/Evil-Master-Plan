import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.96, green: 0.42, blue: 0.27)
    static let canvas = LinearGradient(
        colors: [
            Color(red: 0.08, green: 0.09, blue: 0.13),
            Color(red: 0.12, green: 0.13, blue: 0.19),
            Color(red: 0.06, green: 0.08, blue: 0.14),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let sidebarBackground = LinearGradient(
        colors: [
            Color(red: 0.12, green: 0.14, blue: 0.18),
            Color(red: 0.08, green: 0.09, blue: 0.13),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static func projectColor(_ token: ProjectColorToken) -> Color {
        switch token {
        case .ember:
            Color(red: 0.95, green: 0.44, blue: 0.26)
        case .cyan:
            Color(red: 0.22, green: 0.71, blue: 0.88)
        case .lime:
            Color(red: 0.58, green: 0.79, blue: 0.31)
        case .cobalt:
            Color(red: 0.32, green: 0.47, blue: 0.96)
        case .rose:
            Color(red: 0.90, green: 0.39, blue: 0.56)
        }
    }

    static func statusColor(_ status: ProjectStatus) -> Color {
        switch status {
        case .idea:
            Color.secondary
        case .active:
            Color(red: 0.30, green: 0.84, blue: 0.57)
        case .paused:
            Color(red: 0.95, green: 0.73, blue: 0.22)
        case .blocked:
            Color(red: 0.92, green: 0.31, blue: 0.31)
        case .done:
            Color(red: 0.29, green: 0.76, blue: 0.90)
        }
    }

    static func priorityColor(_ priority: PriorityLevel) -> Color {
        switch priority {
        case .low:
            Color(red: 0.45, green: 0.55, blue: 0.76)
        case .medium:
            Color(red: 0.42, green: 0.77, blue: 0.67)
        case .high:
            Color(red: 0.96, green: 0.68, blue: 0.25)
        case .urgent:
            accent
        }
    }
}
