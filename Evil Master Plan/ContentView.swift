import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selection: AppDestination? = .dashboard
    @State private var didBootstrap = false
    @State private var bootstrapError: String?

    var body: some View {
        AppShellView(selection: $selection)
            .fontDesign(.rounded)
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
