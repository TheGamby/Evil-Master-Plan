import SwiftUI
import SwiftData

struct DependenciesView: View {
    @Query private var projects: [Project]
    @Query private var dependencies: [Dependency]
    @Query private var preferences: [VisualizationPreferences]

    private var rows: [DependencyRowProjection] {
        PlanningProjectionFactory.dependencyRows(
            projects: projects,
            dependencies: dependencies,
            showsOnlyHighPriorityProjects: preferences.first?.showsOnlyHighPriorityProjects ?? false
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PanelCard(title: "Dependency Map", subtitle: "A simple arrow-first readout, prepared for richer critical-path logic later.") {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle("High-priority projects only", isOn: highPriorityOnlyBinding)

                        HStack(spacing: 16) {
                            MetricCard(
                                title: "Links",
                                value: "\(rows.count)",
                                systemImage: "arrow.triangle.branch",
                                tint: AppTheme.accent
                            )
                            MetricCard(
                                title: "Projects",
                                value: "\(visibleProjectCount)",
                                systemImage: "square.stack.3d.up.fill",
                                tint: AppTheme.projectColor(.cobalt)
                            )
                        }
                    }
                }

                PanelCard(title: "Relationships", subtitle: "Every link references shared project/step identifiers instead of a dedicated dependency-only dataset.") {
                    if rows.isEmpty {
                        EmptyStateView(
                            title: "No Dependencies Yet",
                            message: "Add links between projects or steps to sequence work across views.",
                            systemImage: "arrow.triangle.swap"
                        )
                    } else {
                        VStack(spacing: 14) {
                            ForEach(rows) { row in
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(alignment: .center, spacing: 12) {
                                        DependencyEndpointView(title: row.sourceTitle, subtitle: row.sourceSubtitle)
                                        Image(systemName: "arrow.right")
                                            .foregroundStyle(AppTheme.accent)
                                        DependencyEndpointView(title: row.targetTitle, subtitle: row.targetSubtitle)
                                        Spacer()
                                        Text(row.type.title)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }

                                    if !row.note.isEmpty {
                                        Text(row.note)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(16)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Dependencies")
    }

    private var highPriorityOnlyBinding: Binding<Bool> {
        Binding(
            get: { preferences.first?.showsOnlyHighPriorityProjects ?? false },
            set: { preferences.first?.showsOnlyHighPriorityProjects = $0 }
        )
    }

    private var visibleProjectCount: Int {
        if preferences.first?.showsOnlyHighPriorityProjects == true {
            return projects.filter(\.isHighPriority).count
        }
        return projects.count
    }
}

private struct DependencyEndpointView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        DependenciesView()
    }
    .modelContainer(PreviewContainer.shared)
}
