import SwiftUI

struct EmptyStateView: View {
    @Environment(\.appTheme) private var theme
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(theme.accent)

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.primaryText)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .appInsetCard()
    }
}
