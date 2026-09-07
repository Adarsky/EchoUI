import SwiftUI
import SwiftData

struct DataNetworkManagerView: View {
    @Query private var bots: [BotModel]
    @Query private var histories: [ChatHistory]
    @State private var selectedPeriod: DataUsagePeriod = .month

    var body: some View {
        let now = Date.now
        let interval = selectedPeriod.interval(containing: now)
        let points = DataUsagePoint.makePoints(bots: bots, histories: histories)
            .filter { $0.date >= interval.start && $0.date < interval.end && $0.date <= now }
        let buckets = selectedPeriod.buckets(for: points, now: now)
        let rows = DataUsageCharacterRow.makeRows(from: points)
        let totalBytes = points.reduce(0) { $0 + $1.byteCount }
        let sentBytes = points.reduce(0) { $0 + ($1.isUser ? $1.byteCount : 0) }

        List {
            Section {
                VStack(alignment: .leading, spacing: UsageStyle.spacing) {
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(DataUsagePeriod.allCases) { period in
                            Text(period.title).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("usagePeriodPicker")
                    UsageHero(
                        eyebrow: "Estimated traffic", value: CacheByteFormatter.string(for: totalBytes),
                        description: selectedPeriod.rangeDescription(now: now), systemImage: "arrow.up.arrow.down"
                    )
                    if !points.isEmpty {
                        DataUsageChart(buckets: buckets, period: selectedPeriod)
                        Divider()
                        UsageMetricPair(
                            firstTitle: "Messages", firstValue: points.count.formatted(),
                            secondTitle: "Avg. per message",
                            secondValue: CacheByteFormatter.string(for: totalBytes / points.count)
                        )
                    }
                }
                .listRowInsets(UsageStyle.rowInsets)
            } footer: {
                Text("Estimated from saved message text and reply variants, plus an allowance per message. This is not a measurement of network transfers or cellular data.")
            }
            if points.isEmpty {
                ContentUnavailableView(
                    "No Activity This \(selectedPeriod.title)", systemImage: "chart.bar.xaxis",
                    description: Text("Choose a wider period or start a conversation to see estimated traffic.")
                )
                .listRowBackground(Color.clear)
            } else {
                Section {
                    UsageSplitView(
                        firstTitle: "Your messages", firstValue: CacheByteFormatter.string(for: sentBytes),
                        secondTitle: "Character replies", secondValue: CacheByteFormatter.string(for: totalBytes - sentBytes),
                        firstShare: totalBytes > 0 ? Double(sentBytes) / Double(totalBytes) : 0
                    )
                    .listRowInsets(UsageStyle.rowInsets)
                } header: {
                    UsageSectionHeading(title: "Traffic breakdown", subtitle: "Estimated data by message sender")
                }
                Section {
                    ForEach(rows) { row in
                        UsageCharacterRow(
                            bot: row.bot, title: row.title, value: CacheByteFormatter.string(for: row.byteCount),
                            detail: "\(row.messageCount.formatted()) messages · \(row.share.formatted(.percent.precision(.fractionLength(0)))) of traffic",
                            share: row.share
                        )
                        .listRowInsets(UsageStyle.rowInsets)
                    }
                } header: {
                    UsageSectionHeading(title: "Traffic by character", subtitle: "Largest first · Selected period")
                }
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.top, UsageStyle.spacing, for: .scrollContent)
        .navigationTitle("Data Usage")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview {
    NavigationStack { DataNetworkManagerView() }
        .modelContainer(UsagePreviewData.container)
}

#Preview("Empty") {
    NavigationStack { DataNetworkManagerView() }
        .modelContainer(UsagePreviewData.makeContainer(empty: true))
}

#endif
