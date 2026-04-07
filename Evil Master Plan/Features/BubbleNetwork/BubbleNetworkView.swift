import SwiftUI
import SwiftData

struct BubbleNetworkView: View {
    @Query private var projects: [Project]
    @Query private var dependencies: [Dependency]
    @Query private var preferences: [ViewPreferences]

    var body: some View {
        GeometryReader { proxy in
            let canvasWidth = max(proxy.size.width - 48, 900)
            let projection = PlanningProjectionFactory.bubbleNetwork(
                projects: projects,
                dependencies: dependencies,
                sizing: preferences.first?.bubbleSizingCriterion ?? .priority,
                canvasWidth: canvasWidth
            )

            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 20) {
                    PanelCard(title: "Bubble Network", subtitle: "Node size already follows a real preference instead of a fixed mock size.") {
                        Picker("Bubble Size", selection: bubbleSizingBinding) {
                            ForEach(BubbleSizingCriterion.allCases) { criterion in
                                Text(criterion.title).tag(criterion)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    ZStack {
                        ForEach(projection.edges) { edge in
                            DependencyEdgeView(edge: edge)
                        }

                        ForEach(projection.nodes) { node in
                            BubbleNodeView(node: node)
                                .position(node.center)
                        }
                    }
                    .frame(width: projection.canvasSize.width, height: projection.canvasSize.height)
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(.ultraThinMaterial.opacity(0.82))
                    )
                }
                .padding(24)
            }
        }
        .navigationTitle("Bubble Network")
    }

    private var bubbleSizingBinding: Binding<BubbleSizingCriterion> {
        Binding(
            get: { preferences.first?.bubbleSizingCriterion ?? .priority },
            set: { newValue in
                preferences.first?.bubbleSizingCriterion = newValue
            }
        )
    }
}

private struct DependencyEdgeView: View {
    let edge: BubbleEdgeProjection

    var body: some View {
        Path { path in
            path.move(to: edge.start)
            let controlY = min(edge.start.y, edge.end.y) - 40
            path.addCurve(
                to: edge.end,
                control1: CGPoint(x: edge.start.x, y: controlY),
                control2: CGPoint(x: edge.end.x, y: controlY)
            )
        }
        .stroke(styleColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: dashPattern))
    }

    private var styleColor: Color {
        switch edge.type {
        case .finishToStart:
            AppTheme.accent
        case .startToStart:
            AppTheme.projectColor(.cyan)
        case .finishToFinish:
            AppTheme.projectColor(.lime)
        }
    }

    private var dashPattern: [CGFloat] {
        edge.type == .finishToStart ? [] : [8, 8]
    }
}

#Preview {
    NavigationStack {
        BubbleNetworkView()
    }
    .modelContainer(PreviewContainer.shared)
}
