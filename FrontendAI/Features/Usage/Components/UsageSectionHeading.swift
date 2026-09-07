import SwiftUI

struct UsageSectionHeading: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.primary)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
        }
        .textCase(nil)
        .padding(.bottom, UsageStyle.compactSpacing)
    }
}
