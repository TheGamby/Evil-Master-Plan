import SwiftUI

struct BubbleNodeView: View {
    @Environment(\.appTheme) private var theme
    let node: BubbleNode

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                if node.isBlocked {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.bold))
                }

                if node.priority.isHighPriority {
                    Image(systemName: "bolt.fill")
                        .font(.caption.weight(.bold))
                }
            }
            .foregroundStyle(theme.primaryText)

            Text(node.title)
                .font(node.kind == .project ? .headline.weight(.semibold) : .subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(3)

            if let subtitle = node.subtitle, !subtitle.isEmpty {
                Text(subtitle.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            Text(node.progress, format: .percent.precision(.fractionLength(0)))
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.primaryText)
        }
        .padding(12)
        .frame(width: node.radius * 2, height: node.radius * 2)
        .background(
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            theme.projectColor(node.colorToken).opacity(node.isDimmed ? 0.42 : 0.96),
                            theme.projectColor(node.colorToken).opacity(node.isDimmed ? 0.16 : 0.36),
                        ],
                        center: .center,
                        startRadius: 12,
                        endRadius: node.radius
                    )
                )
        )
        .overlay(
            Circle()
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .overlay(alignment: .bottom) {
            if node.kind == .milestone {
                Image(systemName: "diamond.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(theme.primaryText)
                    .padding(.bottom, 8)
            }
        }
        .shadow(color: theme.projectColor(node.colorToken).opacity(node.isDimmed ? 0.06 : 0.28), radius: node.isSelected ? 26 : 18, x: 0, y: 12)
        .opacity(node.isDimmed ? 0.42 : 1)
        .scaleEffect(node.isSelected ? 1.03 : (node.isFocused ? 1.01 : 1))
    }

    private var borderColor: Color {
        if node.isSelected {
            return theme.primaryText
        }
        if node.isFocused {
            return theme.accent.opacity(0.88)
        }
        if node.isBlocked {
            return theme.statusColor(.blocked).opacity(0.84)
        }
        if node.isConnectedToSelection {
            return theme.secondaryText.opacity(0.58)
        }
        return theme.subtleStroke
    }

    private var borderWidth: CGFloat {
        if node.isSelected {
            return 3
        }
        if node.isFocused || node.isBlocked {
            return 2
        }
        return 1
    }
}
