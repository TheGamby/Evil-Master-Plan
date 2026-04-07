import SwiftUI

struct BubbleNodeView: View {
    let node: BubbleNodeProjection

    var body: some View {
        VStack(spacing: 6) {
            Text(node.title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            Text(node.subtitle.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: node.radius * 2, height: node.radius * 2)
        .background(
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppTheme.projectColor(node.colorToken).opacity(0.95),
                            AppTheme.projectColor(node.colorToken).opacity(0.38),
                        ],
                        center: .center,
                        startRadius: 12,
                        endRadius: node.radius
                    )
                )
        )
        .overlay(
            Circle()
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: AppTheme.projectColor(node.colorToken).opacity(0.28), radius: 20, x: 0, y: 12)
    }
}
