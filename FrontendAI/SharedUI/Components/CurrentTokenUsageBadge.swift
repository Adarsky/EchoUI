import SwiftUI

struct CurrentTokenUsageBadge: View {
    let tokenUsageText: String
    let emphasisColor: Color?

    var body: some View {
        ZStack {
            if let emphasisColor {
                emphasisColor.opacity(0.14)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            HStack {
                Text("Current token usage:")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Text(tokenUsageText)
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .foregroundStyle(emphasisColor ?? .primary)
            }
            .padding(16)
        }
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current token usage")
        .accessibilityValue(tokenUsageText)
    }
}

#Preview {
    CurrentTokenUsageBadge(
        tokenUsageText: "12,480 / 128,000",
        emphasisColor: .green
    )
    .padding()
}
