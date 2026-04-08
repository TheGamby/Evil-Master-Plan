import SwiftUI

struct BubbleGraphCanvasView: View {
    let graph: BubbleGraph
    let onSelect: (UUID) -> Void

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                ForEach(graph.groups) { group in
                    BubbleGroupBackdropView(group: group)
                }

                ForEach(graph.edges) { edge in
                    if let source = nodesByID[edge.sourceNodeID], let target = nodesByID[edge.targetNodeID] {
                        BubbleEdgeView(edge: edge, source: source, target: target)
                    }
                }

                ForEach(graph.nodes) { node in
                    Button {
                        onSelect(node.id)
                    } label: {
                        BubbleNodeView(node: node)
                    }
                    .buttonStyle(.plain)
                    .position(node.position)
                    .accessibilityLabel(node.title)
                    .accessibilityHint(node.kind == .project ? "Select project bubble" : "Select focused step bubble")
                }
            }
            .frame(width: graph.canvasSize.width, height: graph.canvasSize.height, alignment: .topLeading)
            .padding(20)
        }
    }

    private var nodesByID: [UUID: BubbleNode] {
        Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, $0) })
    }
}

private struct BubbleGroupBackdropView: View {
    @Environment(\.appTheme) private var theme
    let group: BubbleGroup

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(theme.insetBottom.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(theme.subtleStroke, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(group.title)
                    .font(.headline)
                    .foregroundStyle(theme.primaryText)
                Text("\(group.nodeCount) nodes")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(18)
        }
        .frame(width: group.frame.width, height: group.frame.height)
        .position(x: group.frame.midX, y: group.frame.midY)
    }
}

private struct BubbleEdgeView: View {
    @Environment(\.appTheme) private var theme
    let edge: BubbleEdge
    let source: BubbleNode
    let target: BubbleNode

    var body: some View {
        let curve = edgeCurve

        Path { path in
            path.move(to: curve.start)
            path.addCurve(to: curve.end, control1: curve.control1, control2: curve.control2)
        }
        .stroke(
            styleColor.opacity(edge.isHighlighted ? 0.96 : (source.isDimmed || target.isDimmed ? 0.12 : 0.34)),
            style: StrokeStyle(
                lineWidth: edge.isHighlighted ? 3.2 : CGFloat(1.6 + edge.weight),
                lineCap: .round,
                dash: edge.type == .finishToStart ? [] : [8, 7]
            )
        )
    }

    private var styleColor: Color {
        switch edge.type {
        case .finishToStart:
            theme.accent
        case .startToStart:
            theme.projectColor(.cyan)
        case .finishToFinish:
            theme.projectColor(.lime)
        }
    }

    private var edgeCurve: (start: CGPoint, end: CGPoint, control1: CGPoint, control2: CGPoint) {
        let vector = CGPoint(x: target.position.x - source.position.x, y: target.position.y - source.position.y)
        let distance = max(hypot(vector.x, vector.y), 1)
        let unit = CGPoint(x: vector.x / distance, y: vector.y / distance)
        let start = CGPoint(
            x: source.position.x + unit.x * source.radius * 0.72,
            y: source.position.y + unit.y * source.radius * 0.72
        )
        let end = CGPoint(
            x: target.position.x - unit.x * target.radius * 0.72,
            y: target.position.y - unit.y * target.radius * 0.72
        )
        let bend = max(36, min(distance * 0.18, 110))
        let control1 = CGPoint(x: start.x, y: start.y - bend)
        let control2 = CGPoint(x: end.x, y: end.y - bend)
        return (start, end, control1, control2)
    }
}
