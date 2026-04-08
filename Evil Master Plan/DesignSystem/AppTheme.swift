import SwiftUI

enum AppColorTheme: String, Codable, CaseIterable, Identifiable {
    case emberDusk
    case terminalGreen
    case cobaltNight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .emberDusk:
            "Ember Dusk"
        case .terminalGreen:
            "Terminal Green"
        case .cobaltNight:
            "Cobalt Night"
        }
    }

    var subtitle: String {
        switch self {
        case .emberDusk:
            "Orange glow on deep graphite"
        case .terminalGreen:
            "Phosphor green on near-black"
        case .cobaltNight:
            "Electric blue on midnight navy"
        }
    }
}

struct AppThemePalette {
    let style: AppColorTheme
    let accent: Color
    let canvasColors: [Color]
    let sidebarColors: [Color]
    let panelTop: Color
    let panelBottom: Color
    let insetTop: Color
    let insetBottom: Color
    let selectionTop: Color
    let selectionBottom: Color
    let chromeStroke: Color
    let subtleStroke: Color
    let primaryText: Color
    let secondaryText: Color
    let mutedText: Color
    let shadow: Color
    let ideaColor: Color
    let activeColor: Color
    let pausedColor: Color
    let blockedColor: Color
    let doneColor: Color
    let lowPriorityColor: Color
    let mediumPriorityColor: Color
    let highPriorityColor: Color
    let projectPalette: [ProjectColorToken: Color]

    var canvas: LinearGradient {
        LinearGradient(
            colors: canvasColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var sidebarBackground: LinearGradient {
        LinearGradient(
            colors: sidebarColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var panelBackground: LinearGradient {
        LinearGradient(
            colors: [panelTop, panelBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var insetBackground: LinearGradient {
        LinearGradient(
            colors: [insetTop, insetBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var selectedInsetBackground: LinearGradient {
        LinearGradient(
            colors: [selectionTop, selectionBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    func projectColor(_ token: ProjectColorToken) -> Color {
        projectPalette[token] ?? accent
    }

    func statusColor(_ status: ProjectStatus) -> Color {
        switch status {
        case .idea:
            ideaColor
        case .active:
            activeColor
        case .paused:
            pausedColor
        case .blocked:
            blockedColor
        case .done:
            doneColor
        }
    }

    func priorityColor(_ priority: PriorityLevel) -> Color {
        switch priority {
        case .low:
            lowPriorityColor
        case .medium:
            mediumPriorityColor
        case .high:
            highPriorityColor
        case .urgent:
            accent
        }
    }
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme.palette(for: AppTheme.defaultStyle)
}

extension EnvironmentValues {
    var appTheme: AppThemePalette {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

enum AppTheme {
    static let defaultStyle: AppColorTheme = .emberDusk

    static func palette(for style: AppColorTheme) -> AppThemePalette {
        switch style {
        case .emberDusk:
            AppThemePalette(
                style: style,
                accent: Color(red: 0.96, green: 0.42, blue: 0.27),
                canvasColors: [
                    Color(red: 0.05, green: 0.06, blue: 0.10),
                    Color(red: 0.09, green: 0.10, blue: 0.15),
                    Color(red: 0.07, green: 0.07, blue: 0.12),
                ],
                sidebarColors: [
                    Color(red: 0.11, green: 0.12, blue: 0.17),
                    Color(red: 0.07, green: 0.07, blue: 0.11),
                ],
                panelTop: Color(red: 0.18, green: 0.19, blue: 0.25).opacity(0.96),
                panelBottom: Color(red: 0.11, green: 0.12, blue: 0.16).opacity(0.96),
                insetTop: Color(red: 0.15, green: 0.16, blue: 0.21).opacity(0.96),
                insetBottom: Color(red: 0.10, green: 0.11, blue: 0.15).opacity(0.96),
                selectionTop: Color(red: 0.27, green: 0.16, blue: 0.12).opacity(0.98),
                selectionBottom: Color(red: 0.16, green: 0.11, blue: 0.11).opacity(0.98),
                chromeStroke: .white.opacity(0.10),
                subtleStroke: .white.opacity(0.06),
                primaryText: .white.opacity(0.96),
                secondaryText: .white.opacity(0.72),
                mutedText: .white.opacity(0.54),
                shadow: Color.black.opacity(0.32),
                ideaColor: Color(red: 0.73, green: 0.76, blue: 0.83),
                activeColor: Color(red: 0.42, green: 0.88, blue: 0.62),
                pausedColor: Color(red: 0.95, green: 0.73, blue: 0.22),
                blockedColor: Color(red: 0.95, green: 0.37, blue: 0.34),
                doneColor: Color(red: 0.36, green: 0.78, blue: 0.91),
                lowPriorityColor: Color(red: 0.52, green: 0.60, blue: 0.78),
                mediumPriorityColor: Color(red: 0.47, green: 0.80, blue: 0.70),
                highPriorityColor: Color(red: 0.98, green: 0.74, blue: 0.28),
                projectPalette: [
                    .ember: Color(red: 0.97, green: 0.47, blue: 0.28),
                    .cyan: Color(red: 0.24, green: 0.71, blue: 0.88),
                    .lime: Color(red: 0.66, green: 0.82, blue: 0.34),
                    .cobalt: Color(red: 0.39, green: 0.52, blue: 0.98),
                    .rose: Color(red: 0.92, green: 0.42, blue: 0.60),
                ]
            )
        case .terminalGreen:
            AppThemePalette(
                style: style,
                accent: Color(red: 0.42, green: 0.95, blue: 0.52),
                canvasColors: [
                    Color(red: 0.02, green: 0.05, blue: 0.04),
                    Color(red: 0.03, green: 0.08, blue: 0.05),
                    Color(red: 0.02, green: 0.04, blue: 0.03),
                ],
                sidebarColors: [
                    Color(red: 0.04, green: 0.09, blue: 0.07),
                    Color(red: 0.03, green: 0.05, blue: 0.04),
                ],
                panelTop: Color(red: 0.08, green: 0.15, blue: 0.11).opacity(0.97),
                panelBottom: Color(red: 0.04, green: 0.09, blue: 0.07).opacity(0.97),
                insetTop: Color(red: 0.07, green: 0.13, blue: 0.10).opacity(0.97),
                insetBottom: Color(red: 0.03, green: 0.08, blue: 0.06).opacity(0.97),
                selectionTop: Color(red: 0.10, green: 0.23, blue: 0.14).opacity(0.99),
                selectionBottom: Color(red: 0.04, green: 0.12, blue: 0.08).opacity(0.99),
                chromeStroke: Color(red: 0.54, green: 0.99, blue: 0.66).opacity(0.14),
                subtleStroke: .white.opacity(0.05),
                primaryText: Color(red: 0.88, green: 1.00, blue: 0.90),
                secondaryText: Color(red: 0.69, green: 0.89, blue: 0.73),
                mutedText: Color(red: 0.55, green: 0.73, blue: 0.60),
                shadow: Color.black.opacity(0.34),
                ideaColor: Color(red: 0.58, green: 0.86, blue: 0.64),
                activeColor: Color(red: 0.42, green: 0.95, blue: 0.52),
                pausedColor: Color(red: 0.97, green: 0.82, blue: 0.38),
                blockedColor: Color(red: 1.00, green: 0.48, blue: 0.34),
                doneColor: Color(red: 0.42, green: 0.88, blue: 0.86),
                lowPriorityColor: Color(red: 0.43, green: 0.69, blue: 0.55),
                mediumPriorityColor: Color(red: 0.58, green: 0.88, blue: 0.62),
                highPriorityColor: Color(red: 0.95, green: 0.85, blue: 0.36),
                projectPalette: [
                    .ember: Color(red: 0.92, green: 0.76, blue: 0.34),
                    .cyan: Color(red: 0.38, green: 0.91, blue: 0.84),
                    .lime: Color(red: 0.54, green: 0.98, blue: 0.48),
                    .cobalt: Color(red: 0.48, green: 0.82, blue: 0.70),
                    .rose: Color(red: 0.83, green: 0.92, blue: 0.52),
                ]
            )
        case .cobaltNight:
            AppThemePalette(
                style: style,
                accent: Color(red: 0.34, green: 0.64, blue: 0.99),
                canvasColors: [
                    Color(red: 0.03, green: 0.06, blue: 0.11),
                    Color(red: 0.06, green: 0.09, blue: 0.16),
                    Color(red: 0.03, green: 0.05, blue: 0.09),
                ],
                sidebarColors: [
                    Color(red: 0.08, green: 0.11, blue: 0.18),
                    Color(red: 0.04, green: 0.06, blue: 0.10),
                ],
                panelTop: Color(red: 0.12, green: 0.16, blue: 0.26).opacity(0.96),
                panelBottom: Color(red: 0.07, green: 0.10, blue: 0.17).opacity(0.96),
                insetTop: Color(red: 0.10, green: 0.14, blue: 0.22).opacity(0.96),
                insetBottom: Color(red: 0.06, green: 0.09, blue: 0.15).opacity(0.96),
                selectionTop: Color(red: 0.10, green: 0.19, blue: 0.34).opacity(0.99),
                selectionBottom: Color(red: 0.07, green: 0.10, blue: 0.18).opacity(0.99),
                chromeStroke: Color(red: 0.51, green: 0.74, blue: 1.00).opacity(0.16),
                subtleStroke: .white.opacity(0.05),
                primaryText: .white.opacity(0.96),
                secondaryText: Color(red: 0.76, green: 0.84, blue: 0.96),
                mutedText: Color(red: 0.58, green: 0.66, blue: 0.82),
                shadow: Color.black.opacity(0.34),
                ideaColor: Color(red: 0.70, green: 0.77, blue: 0.90),
                activeColor: Color(red: 0.48, green: 0.90, blue: 0.70),
                pausedColor: Color(red: 0.96, green: 0.74, blue: 0.28),
                blockedColor: Color(red: 0.97, green: 0.43, blue: 0.38),
                doneColor: Color(red: 0.45, green: 0.86, blue: 0.98),
                lowPriorityColor: Color(red: 0.54, green: 0.62, blue: 0.86),
                mediumPriorityColor: Color(red: 0.47, green: 0.79, blue: 0.90),
                highPriorityColor: Color(red: 0.78, green: 0.84, blue: 1.00),
                projectPalette: [
                    .ember: Color(red: 0.98, green: 0.59, blue: 0.34),
                    .cyan: Color(red: 0.37, green: 0.78, blue: 0.98),
                    .lime: Color(red: 0.54, green: 0.88, blue: 0.61),
                    .cobalt: Color(red: 0.40, green: 0.58, blue: 0.99),
                    .rose: Color(red: 0.83, green: 0.52, blue: 0.95),
                ]
            )
        }
    }
}
