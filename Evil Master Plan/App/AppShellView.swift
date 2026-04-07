import SwiftUI

struct AppShellView: View {
    @Binding var selection: AppDestination?

    var body: some View {
        NavigationSplitView {
            AppSidebar(selection: $selection)
        } detail: {
            destinationView(for: selection ?? .dashboard)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(AppTheme.canvas.ignoresSafeArea())
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
    @Binding var selection: AppDestination?

    var body: some View {
        List(AppDestination.allCases, selection: $selection) { destination in
            NavigationLink(value: destination) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(destination.title)
                            .font(.headline)
                        Text(destination.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: destination.systemImage)
                        .foregroundStyle(AppTheme.accent)
                }
                .padding(.vertical, 4)
            }
            .tag(destination)
        }
#if os(macOS)
        .navigationSplitViewColumnWidth(min: 220, ideal: 240)
#endif
        .scrollContentBackground(.hidden)
        .background(AppTheme.sidebarBackground)
        .navigationTitle("Evil Master Plan")
    }
}
