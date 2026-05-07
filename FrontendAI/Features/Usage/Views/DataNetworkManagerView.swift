import SwiftUI
import SwiftData
import Charts

struct DataNetworkManagerView: View {
    @Query private var bots: [BotModel]
    @Query private var histories: [ChatHistory]

    @State private var selectedPeriod: DataUsagePeriod = .month

    private var usagePoints: [DataUsagePoint] {
        DataUsagePoint.makePoints(bots: bots, histories: histories)
    }

    private var filteredPoints: [DataUsagePoint] {
        let interval = selectedPeriod.interval(containing: Date())
        return usagePoints.filter { interval.contains($0.date) }
    }

    private var chartBuckets: [DataUsageBucket] {
        selectedPeriod.buckets(for: filteredPoints, now: Date())
    }

    private var characterRows: [DataUsageCharacterRow] {
        DataUsageCharacterRow.makeRows(from: filteredPoints)
    }

    var body: some View {
        List {
            Section {
                if filteredPoints.isEmpty {
                    ContentUnavailableView(
                        "No Data Usage",
                        systemImage: "antenna.radiowaves.left.and.right",
                        description: Text("Chat traffic will appear here.")
                    )
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 24)
                } else {
                    DataUsageChart(
                        buckets: chartBuckets,
                        period: selectedPeriod
                    )
                    .frame(height: 260)
                }

                Picker("Period", selection: $selectedPeriod) {
                    ForEach(DataUsagePeriod.allCases) { period in
                        Text(period.title).tag(period)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Characters") {
                if characterRows.isEmpty {
                    Text("No usage in this period")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(characterRows) { row in
                        DataUsageCharacterRowView(row: row)
                    }
                }
            }
        }
        .navigationTitle("Data Usage")
    }
}

private struct DataUsageChart: View {
    let buckets: [DataUsageBucket]
    let period: DataUsagePeriod

    var body: some View {
        Chart(buckets) { bucket in
            BarMark(
                x: .value("Month", bucket.date, unit: period.chartUnit),
                y: .value("Usage", bucket.byteCount)
            )
            .foregroundStyle(.blue.gradient)
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: period.desiredXAxisMarks)) {
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: period.axisDateFormat)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisTick()
                if let byteCount = value.as(Int.self) {
                    AxisValueLabel(CacheByteFormatter.string(for: byteCount))
                }
            }
        }
    }
}

private struct DataUsageCharacterRowView: View {
    let row: DataUsageCharacterRow

    var body: some View {
        HStack(spacing: 12) {
            avatar
                .resizable()
                .scaledToFill()
                .frame(width: 38, height: 38)
                .clipShape(Circle())
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(row.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(CacheByteFormatter.string(for: row.byteCount))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: row.share)
                    .progressViewStyle(.linear)
                    .tint(.blue)

                Text("\(row.messageCount.formatted()) messages")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 5)
    }

    private var avatar: Image {
        row.bot?.avatarImage ?? Image(systemName: "questionmark.circle.fill")
    }
}

private enum DataUsagePeriod: String, CaseIterable, Identifiable {
    case day
    case week
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day:
            return "Day"
        case .week:
            return "Week"
        case .month:
            return "Month"
        case .year:
            return "Year"
        }
    }

    var dateComponent: Calendar.Component {
        switch self {
        case .day:
            return .day
        case .week:
            return .weekOfYear
        case .month:
            return .month
        case .year:
            return .year
        }
    }

    var bucketComponent: Calendar.Component {
        switch self {
        case .day:
            return .hour
        case .week, .month:
            return .day
        case .year:
            return .month
        }
    }

    var chartUnit: Calendar.Component {
        bucketComponent
    }

    var desiredXAxisMarks: Int {
        switch self {
        case .day:
            return 6
        case .week:
            return 7
        case .month:
            return 6
        case .year:
            return 12
        }
    }

    var axisDateFormat: Date.FormatStyle {
        switch self {
        case .day:
            return .dateTime.hour()
        case .week, .month:
            return .dateTime.day()
        case .year:
            return .dateTime.month(.abbreviated)
        }
    }

    func interval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: dateComponent, for: date) ?? DateInterval(start: date, end: date)
    }

    func buckets(
        for points: [DataUsagePoint],
        now: Date,
        calendar: Calendar = .current
    ) -> [DataUsageBucket] {
        let interval = interval(containing: now, calendar: calendar)
        var bucketsByDate: [Date: Int] = [:]

        var bucketDate = bucketStart(for: interval.start, calendar: calendar)
        while bucketDate <= now {
            bucketsByDate[bucketDate] = 0
            guard let nextDate = calendar.date(byAdding: bucketComponent, value: 1, to: bucketDate) else {
                break
            }
            bucketDate = nextDate
        }

        for point in points {
            let date = bucketStart(for: point.date, calendar: calendar)
            bucketsByDate[date, default: 0] += point.byteCount
        }

        return bucketsByDate
            .map { DataUsageBucket(date: $0.key, byteCount: $0.value) }
            .sorted { $0.date < $1.date }
    }

    private func bucketStart(for date: Date, calendar: Calendar) -> Date {
        switch self {
        case .day:
            return calendar.dateInterval(of: .hour, for: date)?.start ?? date
        case .week, .month:
            return calendar.startOfDay(for: date)
        case .year:
            return calendar.dateInterval(of: .month, for: date)?.start ?? date
        }
    }
}

private struct DataUsagePoint {
    let botID: UUID
    let bot: BotModel?
    let date: Date
    let byteCount: Int

    static func makePoints(bots: [BotModel], histories: [ChatHistory]) -> [DataUsagePoint] {
        let botsByID = Dictionary(uniqueKeysWithValues: bots.map { ($0.id, $0) })

        return histories.flatMap { history in
            history.messages.map { message in
                DataUsagePoint(
                    botID: history.botID,
                    bot: botsByID[history.botID],
                    date: message.timestamp ?? history.date,
                    byteCount: DataUsageEstimator.estimatedTrafficByteCount(for: message)
                )
            }
        }
    }
}

private struct DataUsageBucket: Identifiable {
    let date: Date
    let byteCount: Int

    var id: Date {
        date
    }
}

private struct DataUsageCharacterRow: Identifiable {
    let id: UUID
    let bot: BotModel?
    let byteCount: Int
    let messageCount: Int
    let totalBytes: Int

    var title: String {
        bot?.name ?? "Deleted Bot"
    }

    var share: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(byteCount) / Double(totalBytes)
    }

    static func makeRows(from points: [DataUsagePoint]) -> [DataUsageCharacterRow] {
        let totalBytes = points.reduce(0) { $0 + $1.byteCount }
        let groupedPoints = Dictionary(grouping: points, by: \.botID)

        return groupedPoints.map { botID, points in
            DataUsageCharacterRow(
                id: botID,
                bot: points.first?.bot,
                byteCount: points.reduce(0) { $0 + $1.byteCount },
                messageCount: points.count,
                totalBytes: totalBytes
            )
        }
        .sorted {
            if $0.byteCount == $1.byteCount {
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return $0.byteCount > $1.byteCount
        }
    }
}

private enum DataUsageEstimator {
    static func estimatedTrafficByteCount(for message: ChatMessageEntity) -> Int {
        var byteCount = 512
        byteCount += message.text.utf8.count

        if let variants = message.variants {
            byteCount += variants.reduce(0) { $0 + $1.utf8.count }
        }

        return byteCount
    }
}

#Preview {
    NavigationStack {
        DataNetworkManagerView()
    }
    .modelContainer(dataUsagePreviewModelContainer)
}

@MainActor
private let dataUsagePreviewModelContainer: ModelContainer = {
    let schema = Schema([
        BotModel.self,
        ChatHistory.self,
        ChatMessageEntity.self
    ])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [configuration])
    let context = container.mainContext

    let bots = [
        BotModel(
            name: "Design Lead",
            subtitle: "Product UI review",
            date: "Apr 29, 2026",
            avatarSystemName: "paintpalette.fill",
            iconColorName: "purple",
            isPinned: true,
            greeting: "Send screens or flows for review."
        ),
        BotModel(
            name: "Swift Mentor",
            subtitle: "iOS implementation notes",
            date: "Apr 28, 2026",
            avatarSystemName: "swift",
            iconColorName: "orange",
            isPinned: false,
            greeting: "Ask about SwiftUI and app structure."
        ),
        BotModel(
            name: "Travel Planner",
            subtitle: "Trip research",
            date: "Apr 27, 2026",
            avatarSystemName: "airplane.departure",
            iconColorName: "blue",
            isPinned: false,
            greeting: "Where are we going next?"
        )
    ]

    for bot in bots {
        context.insert(bot)
    }

    let calendar = Calendar.current
    let now = Date()
    for dayOffset in 0..<24 {
        let bot = bots[dayOffset % bots.count]
        let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) ?? now
        let repeatedText = String(repeating: "Usage payload sample. ", count: 8 + dayOffset % 6)
        context.insert(
            ChatHistory(
                messages: [
                    ChatMessageEntity(
                        text: "Can you process this request? \(repeatedText)",
                        isUser: true,
                        index: 0,
                        timestamp: calendar.date(byAdding: .minute, value: -3, to: date)
                    ),
                    ChatMessageEntity(
                        text: "Processed. \(repeatedText)\(repeatedText)",
                        isUser: false,
                        index: 1,
                        timestamp: date
                    )
                ],
                date: date,
                bot: bot
            )
        )
    }

    try? context.save()
    return container
}()
