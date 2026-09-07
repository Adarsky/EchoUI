import SwiftUI

struct UsageSplitView: View {
    let firstTitle: String
    let firstValue: String
    let secondTitle: String
    let secondValue: String
    let firstShare: Double
    var hasValues = true

    var body: some View {
        VStack(alignment: .leading, spacing: UsageStyle.spacing) {
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 5)
                    .fill(hasValues ? UsageStyle.secondaryAccent : Color.secondary.opacity(0.2))
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(UsageStyle.accent)
                            .frame(width: geometry.size.width * min(max(firstShare, 0), 1))
                    }
                    .clipShape(.rect(cornerRadius: 5))
            }
            .frame(height: 10)
            .accessibilityHidden(true)
            UsageMetricPair(
                firstTitle: firstTitle, firstValue: firstValue,
                secondTitle: secondTitle, secondValue: secondValue,
                firstTint: UsageStyle.accent, secondTint: UsageStyle.secondaryAccent
            )
        }
    }
}
