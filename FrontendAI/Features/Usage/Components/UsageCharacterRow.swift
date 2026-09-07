import SwiftUI

struct UsageCharacterRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let bot: BotModel?
    let title: String
    let value: String
    let detail: String
    let share: Double
    var rank: Int? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let rank {
                Text(rank.formatted(.number.precision(.integerLength(2))))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: 24, minHeight: 40)
                    .accessibilityLabel("Rank \(rank)")
            } else {
                UsageAvatar(bot: bot)
            }

            VStack(alignment: .leading, spacing: UsageStyle.compactSpacing) {
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
                layout {
                    Text(title)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(value)
                        .font(.subheadline.weight(.medium).monospacedDigit())
                        .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: true)
                }
                UsageShareBar(share: share)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
