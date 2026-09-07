import SwiftUI
import Charts

struct DataUsageChart: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var chartHeight = UsageStyle.chartHeight
    let buckets: [DataUsageBucket]
    let period: DataUsagePeriod
    @State private var selectedDate: Date?

    private var selectedBucket: DataUsageBucket? {
        guard let selectedDate else { return nil }
        return buckets.first {
            Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: period.chartUnit)
        }
    }

    private var highlightedBucket: DataUsageBucket? {
        selectedBucket ?? buckets.max { $0.byteCount < $1.byteCount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: UsageStyle.spacing) {
            Chart(buckets) { bucket in
                BarMark(
                    x: .value("Date", bucket.date, unit: period.chartUnit),
                    y: .value("Estimated traffic", bucket.byteCount), width: .ratio(0.6)
                )
                .foregroundStyle(UsageStyle.accent)
                .opacity(selectedBucket == nil || selectedBucket?.id == bucket.id ? 1 : 0.3)
                .cornerRadius(3)
                .accessibilityLabel(bucket.date.formatted(date: .abbreviated, time: period == .day ? .shortened : .omitted))
                .accessibilityValue(CacheByteFormatter.string(for: bucket.byteCount))
            }
            .chartXSelection(value: $selectedDate)
            .chartYScale(domain: 0...max(buckets.map(\.byteCount).max() ?? 0, 1))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: dynamicTypeSize.isAccessibilitySize ? 3 : period.desiredXAxisMarks)) {
                    AxisValueLabel(format: period.axisDateFormat)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                    if let byteCount = value.as(Int.self) {
                        AxisValueLabel(byteCount == 0 ? "0" : CacheByteFormatter.string(for: byteCount))
                    }
                }
            }
            .frame(height: chartHeight)
            if let bucket = highlightedBucket {
                Text("\(selectedBucket == nil ? "Peak" : "Selected"): \(bucket.date.formatted(period.detailDateFormat)) · \(CacheByteFormatter.string(for: bucket.byteCount))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .onChange(of: period) { selectedDate = nil }
    }
}
