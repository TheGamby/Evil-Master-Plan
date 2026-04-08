import SwiftUI

struct AppShellView: View {
    @Environment(\.appTheme) private var theme
    @Binding var selection: AppDestination?

    var body: some View {
        NavigationSplitView {
            AppSidebar(selection: $selection)
        } detail: {
            destinationView(for: selection ?? .dashboard)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(theme.canvas.ignoresSafeArea())
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func destinationView(for destination: AppDestination) -> some View {
        switch destination {
        case .dashboard:
            DashboardView()
        case .projects:
            ProjectsView()
        case .bubbleNetwork:
            BubbleNetworkView()
        case .gantt:
            GanttView()
        case .dependencies:
            DependenciesView()
        case .inbox:
            InboxView()
        case .settings:
            SettingsView()
        }
    }
}

private struct AppSidebar: View {
    @Environment(\.appTheme) private var theme
    @Binding var selection: AppDestination?

    var body: some View {
        List(AppDestination.allCases, selection: $selection) { destination in
            NavigationLink(value: destination) {
                AppSidebarRow(
                    destination: destination,
                    isSelected: selection == destination
                )
            }
            .tag(destination)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
#if os(macOS)
        .navigationSplitViewColumnWidth(min: 220, ideal: 240)
#endif
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(theme.sidebarBackground)
        .navigationTitle("Evil Master Plan")
    }
}

private struct AppSidebarRow: View {
    @Environment(\.appTheme) private var theme
    let destination: AppDestination
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: destination.systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(isSelected ? theme.accent : theme.accent.opacity(0.9))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(destination.title)
                    .font(.headline)
                    .foregroundStyle(theme.primaryText)
                Text(destination.subtitle)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? theme.selectionBottom.opacity(0.9) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? theme.accent.opacity(0.35) : .clear, lineWidth: 1)
        )
    }
}
