import SwiftUI

struct UsageHero: View {
    let eyebrow: String
    let value: String
    let description: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: UsageStyle.compactSpacing) {
            Label(eyebrow, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(UsageStyle.accent)
            Text(value)
                .font(.largeTitle.bold().monospacedDigit())
                .contentTransition(.numericText())
                .fixedSize(horizontal: false, vertical: true)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
