import SwiftUI
import Charts

struct CacheDistributionView: View {
    let rows: [CacheRow]

    var body: some View {
        Chart {
            ForEach(rows.enumerated(), id: \.element.id) { index, row in
                BarMark(
                    x: .value("Storage", row.byteCount),
                    y: .value("Saved chats", "Storage")
                )
                .foregroundStyle(index == 0 ? UsageStyle.accent : Color.secondary.opacity(index == 1 ? 0.45 : 0.2))
                .accessibilityLabel(row.title)
                .accessibilityValue("\(CacheByteFormatter.string(for: row.byteCount)), \(row.percentText)")
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(height: 20)
        .clipShape(.rect(cornerRadius: 6))

        if let largest = rows.first {
            Text("\(Text(largest.title).foregroundStyle(.primary)) accounts for \(Text(largest.percentText).foregroundStyle(.primary)) of your saved chat storage.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
