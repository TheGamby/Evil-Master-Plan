import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [VisualizationPreferences]
    @State private var navigation = AppNavigationModel()
    @State private var didBootstrap = false
    @State private var bootstrapError: String?

    var body: some View {
        let theme = currentTheme

        AppShellView(selection: selection)
            .fontDesign(.rounded)
            .environment(navigation)
            .environment(\.appTheme, theme)
            .tint(theme.accent)
            .preferredColorScheme(.dark)
            .task {
                await bootstrapIfNeeded()
            }
            .alert("Bootstrap Failed", isPresented: bootstrapErrorBinding) {
                Button("OK", role: .cancel) {
                    bootstrapError = nil
                }
            } message: {
                Text(bootstrapError ?? "Unknown error")
            }
    }

    private var currentTheme: AppThemePalette {
        let selectedTheme = preferences.first?.appColorTheme ?? AppTheme.defaultStyle
        return AppTheme.palette(for: selectedTheme)
    }

    private var selection: Binding<AppDestination?> {
        Binding(
            get: { navigation.selection },
            set: { navigation.selection = $0 }
        )
    }

    private var bootstrapErrorBinding: Binding<Bool> {
        Binding(
            get: { bootstrapError != nil },
            set: { isPresented in
                if !isPresented {
                    bootstrapError = nil
                }
            }
        )
    }

    @MainActor
    private func bootstrapIfNeeded() async {
        guard !didBootstrap else {
            return
        }

        didBootstrap = true

        do {
            try DataBootstrapper.seedIfNeeded(in: modelContext)
        } catch {
            bootstrapError = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewContainer.shared)
}
