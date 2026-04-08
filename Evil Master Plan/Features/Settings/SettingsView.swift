import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var preferences: [VisualizationPreferences]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if let preferences = preferences.first {
                    PanelCard(title: "Visualization Preferences", subtitle: "Persisted in SwiftData so the app can evolve without inventing separate preference silos.") {
                        VStack(alignment: .leading, spacing: 16) {
                            Picker("App Theme", selection: binding(preferences, for: \.appColorTheme, default: AppTheme.defaultStyle)) {
                                ForEach(AppColorTheme.allCases) { theme in
                                    Text(theme.title).tag(theme)
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("Bubble Sizing", selection: binding(preferences, for: \.bubbleSizingCriterion)) {
                                ForEach(BubbleSizingCriterion.allCases) { criterion in
                                    Text(criterion.title).tag(criterion)
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("Bubble Grouping", selection: binding(preferences, for: \.bubbleGroupingMode, default: .status)) {
                                ForEach(BubbleGroupingMode.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("Timeline Scale", selection: binding(preferences, for: \.timelineScale, default: .week)) {
                                ForEach(TimelineScale.allCases) { scale in
                                    Text(scale.title).tag(scale)
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("Default Project Sort", selection: binding(preferences, for: \.projectSortCriterion)) {
                                ForEach(ProjectSortCriterion.allCases) { criterion in
                                    Text(criterion.title).tag(criterion)
                                }
                            }
                            .pickerStyle(.menu)

                            Toggle("Show completed items in timelines", isOn: binding(preferences, for: \.showsCompletedItems))
                            Toggle("Limit planning views to high-priority projects", isOn: binding(preferences, for: \.showsOnlyHighPriorityProjects))
                        }
                    }
                } else {
                    EmptyStateView(
                        title: "Preferences Are Missing",
                        message: "The bootstrapper should create one shared preferences record automatically.",
                        systemImage: "slider.horizontal.3"
                    )
                }

                PanelCard(title: "Cloud Sync Preparation", subtitle: "The data model is containerized centrally, but CloudKit stays off until capabilities are enabled in Xcode.") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("The current app runs locally with SwiftData only.")
                        Text("When you're ready, enable the iCloud capability with CloudKit in the app target and then opt into `.automatic` CloudKit configuration from `PersistenceController`.")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
        .navigationTitle("Settings")
    }

    private func binding<Value>(_ preferences: VisualizationPreferences, for keyPath: ReferenceWritableKeyPath<VisualizationPreferences, Value>) -> Binding<Value> {
        Binding(
            get: { preferences[keyPath: keyPath] },
            set: { preferences[keyPath: keyPath] = $0 }
        )
    }

    private func binding<Value>(_ preferences: VisualizationPreferences, for keyPath: ReferenceWritableKeyPath<VisualizationPreferences, Value?>, default defaultValue: Value) -> Binding<Value> {
        Binding(
            get: { preferences[keyPath: keyPath] ?? defaultValue },
            set: { preferences[keyPath: keyPath] = $0 }
        )
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(PreviewContainer.shared)
}
