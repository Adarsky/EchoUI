import SwiftUI

struct UsageMetricPair: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let firstTitle: String
    let firstValue: String
    let secondTitle: String
    let secondValue: String
    var firstTint: Color = .primary
    var secondTint: Color = .primary

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: UsageStyle.spacing))
            : AnyLayout(HStackLayout(alignment: .top, spacing: UsageStyle.spacing))
        layout {
            UsageMetric(title: firstTitle, value: firstValue, tint: firstTint)
            UsageMetric(title: secondTitle, value: secondValue, tint: secondTint)
        }
    }
}
