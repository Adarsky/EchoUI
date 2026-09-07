import SwiftUI
import Charts

struct UsageActivityChart: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var chartHeight = UsageStyle.chartHeight
    let days: [UsageActivityDay]

    var body: some View {
        VStack(alignment: .leading, spacing: UsageStyle.spacing) {
            UsageMetricPair(
                firstTitle: "Messages in 7 days", firstValue: days.reduce(0) { $0 + $1.messageCount }.formatted(),
                secondTitle: "Active days out of 7", secondValue: days.count(where: { $0.messageCount > 0 }).formatted()
            )
            Chart(days) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Messages", day.messageCount), width: .ratio(0.5)
                )
                .foregroundStyle(UsageStyle.accent)
                .cornerRadius(4)
                .accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted))
                .accessibilityValue("\(day.messageCount) messages")
            }
            .chartYScale(domain: 0...max(days.map(\.messageCount).max() ?? 0, 1))
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: dynamicTypeSize.isAccessibilitySize ? 2 : 1)) {
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                    AxisValueLabel()
                }
            }
            .frame(height: chartHeight)
        }
    }
}
