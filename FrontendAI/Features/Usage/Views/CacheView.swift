import SwiftUI
import SwiftData
import Charts

struct CacheView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var bots: [BotModel]
    @Query private var histories: [ChatHistory]

    @State private var rowPendingDeletion: CacheRow?
    @State private var isShowingClearAllConfirmation = false

    private var rows: [CacheRow] {
        CacheRow.makeRows(bots: bots, histories: histories)
    }

    private var totalBytes: Int {
        rows.reduce(0) { $0 + $1.byteCount }
    }

    private var totalMessages: Int {
        rows.reduce(0) { $0 + $1.messageCount }
    }

    private var totalHistories: Int {
        rows.reduce(0) { $0 + $1.historyCount }
    }

    private var largestBytes: Int {
        rows.map(\.byteCount).max() ?? 0
    }

    var body: some View {
        List {
            Section() {


                if rows.isEmpty {
                    ContentUnavailableView(
                        "No Cached Chats",
                        systemImage: "tray",
                        description: Text("Saved chat histories will appear here.")
                    )
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 24)
                } else {
                    CacheSectorChart(rows: rows)
                        .frame(height: 300)
                }
                CacheSummaryView(
                    totalBytes: totalBytes,
                    totalHistories: totalHistories,
                    totalMessages: totalMessages,
                    largestBytes: largestBytes
                )
            }

            Section("Cache Per Chat") {
                ForEach(rows) { row in
                    NavigationLink {
                        if let bot = row.bot {
                            ChatHistoryListView(botID: bot.id, botName: bot.name)
                        } else {
                            OrphanedCacheDetailView(row: row)
                        }
                    } label: {
                        CacheRowView(row: row)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            rowPendingDeletion = row
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }

                Button(role: .destructive) {
                    isShowingClearAllConfirmation = true
                } label: {
                    Text("Clear All Cache")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .disabled(histories.isEmpty)
                .padding(2)
                .glassEffect(.regular.tint(.gray.opacity(0.2)).interactive())
            }
        }
        .navigationTitle("Cache Info")
        .alert("Delete this chat cache?", isPresented: isShowingDeleteRowConfirmation) {
            Button("Delete", role: .destructive) {
                if let rowPendingDeletion {
                    deleteHistories(rowPendingDeletion.histories)
                    self.rowPendingDeletion = nil
                }
            }
            Button("Cancel", role: .cancel) {
                rowPendingDeletion = nil
            }
        } message: {
            Text("This removes saved histories for \(rowPendingDeletion?.title ?? "this chat"). The bot itself is kept.")
        }
        .alert("Clear all cached chat histories?", isPresented: $isShowingClearAllConfirmation) {
            Button("Clear Cache", role: .destructive) {
                deleteHistories(histories)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes all saved chat histories. Bots, personas, and API settings are kept.")
        }
    }

    private var isShowingDeleteRowConfirmation: Binding<Bool> {
        Binding(
            get: { rowPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    rowPendingDeletion = nil
                }
            }
        )
    }

    private func deleteHistories(_ historiesToDelete: [ChatHistory]) {
        for history in historiesToDelete {
            modelContext.delete(history)
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to delete cached histories: \(error)")
        }
    }
}

private struct CacheSummaryView: View {
    let totalBytes: Int
    let totalHistories: Int
    let totalMessages: Int
    let largestBytes: Int

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
            GridRow {
                CacheSummaryMetric(
                    title: "Storage",
                    value: CacheByteFormatter.string(for: totalBytes),
                    iconName: "internaldrive"
                )
                CacheSummaryMetric(
                    title: "Chats",
                    value: totalHistories.formatted(),
                    iconName: "bubble.left.and.bubble.right"
                )
            }

            GridRow {
                CacheSummaryMetric(
                    title: "Messages",
                    value: totalMessages.formatted(),
                    iconName: "text.bubble"
                )
                CacheSummaryMetric(
                    title: "Largest",
                    value: CacheByteFormatter.string(for: largestBytes),
                    iconName: "chart.bar.xaxis"
                )
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CacheSummaryMetric: View {
    let title: String
    let value: String
    let iconName: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CacheSectorChart: View {
    let rows: [CacheRow]

    private var totalBytes: Int {
        rows.reduce(0) { $0 + $1.byteCount }
    }

    private var chartSlices: [CacheChartSlice] {
        CacheChartSlice.makeSlices(from: rows)
    }

    var body: some View {
        ZStack {
            Chart(chartSlices) { slice in
                SectorMark(
                    angle: .value("Storage", slice.byteCount),
                    innerRadius: .ratio(0.62),
                    angularInset: 1.5
                )
                .foregroundStyle(by: .value("Chat", slice.title))
                .annotation(position: .overlay) {
                    if slice.share >= 0.12 {
                        Text(slice.percentText)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.white)
                    }
                }
            }
            .chartLegend(position: .bottom, alignment: .center, spacing: 8)

            VStack(spacing: 2) {
                Text(CacheByteFormatter.string(for: totalBytes))
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
        }
    }
}

private struct CacheRowView: View {
    let row: CacheRow

    var body: some View {
        HStack(spacing: 12) {
            avatar
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(row.detailText)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(CacheByteFormatter.string(for: row.byteCount))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var avatar: Image {
        row.bot?.avatarImage ?? Image(systemName: "questionmark.circle.fill")
    }
}

private struct OrphanedCacheDetailView: View {
    let row: CacheRow

    var body: some View {
        List {
            Section("Saved Histories") {
                ForEach(row.histories) { history in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(history.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.headline)

                        Text("\(history.messages.count) messages")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle(row.title)
    }
}

private struct CacheChartSlice: Identifiable {
    let id: String
    let title: String
    let byteCount: Int
    let totalBytes: Int

    var share: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(byteCount) / Double(totalBytes)
    }

    var percentText: String {
        share.formatted(.percent.precision(.fractionLength(0)))
    }

    static func makeSlices(from rows: [CacheRow]) -> [CacheChartSlice] {
        let totalBytes = rows.reduce(0) { $0 + $1.byteCount }
        let visibleRows = rows.prefix(5)
        var slices = visibleRows.map {
            CacheChartSlice(
                id: $0.id.uuidString,
                title: $0.title,
                byteCount: $0.byteCount,
                totalBytes: totalBytes
            )
        }

        let otherBytes = rows.dropFirst(5).reduce(0) { $0 + $1.byteCount }
        if otherBytes > 0 {
            slices.append(
                CacheChartSlice(
                    id: "others",
                    title: "Others",
                    byteCount: otherBytes,
                    totalBytes: totalBytes
                )
            )
        }

        return slices
    }
}

private struct CacheRow: Identifiable {
    let id: UUID
    let bot: BotModel?
    let histories: [ChatHistory]
    let byteCount: Int
    let totalBytes: Int

    var title: String {
        bot?.name ?? "Deleted Bot"
    }

    var historyCount: Int {
        histories.count
    }

    var messageCount: Int {
        histories.reduce(0) { $0 + $1.messages.count }
    }

    var share: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(byteCount) / Double(totalBytes)
    }

    var percentText: String {
        share.formatted(.percent.precision(.fractionLength(0)))
    }

    var detailText: String {
        "\(historyCount.formatted()) chats, \(messageCount.formatted()) messages"
    }

    static func makeRows(bots: [BotModel], histories: [ChatHistory]) -> [CacheRow] {
        let groupedHistories = Dictionary(grouping: histories, by: \.botID)
        let botsByID = Dictionary(uniqueKeysWithValues: bots.map { ($0.id, $0) })
        let totalBytes = groupedHistories.values.reduce(0) { partialResult, histories in
            partialResult + histories.reduce(0) { $0 + CacheEstimator.estimatedByteCount(for: $1) }
        }

        return groupedHistories.map { botID, histories in
            let byteCount = histories.reduce(0) { $0 + CacheEstimator.estimatedByteCount(for: $1) }
            return CacheRow(
                id: botID,
                bot: botsByID[botID],
                histories: histories.sorted { $0.date > $1.date },
                byteCount: byteCount,
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

enum CacheByteFormatter {
    static func string(for byteCount: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(byteCount))
    }
}

enum CacheEstimator {
    static func estimatedByteCount(for history: ChatHistory) -> Int {
        var byteCount = 64
        byteCount += MemoryLayout<UUID>.size
        byteCount += history.messages.reduce(0) { $0 + estimatedByteCount(for: $1) }
        return byteCount
    }

    private static func estimatedByteCount(for message: ChatMessageEntity) -> Int {
        var byteCount = 64
        byteCount += message.text.utf8.count
        byteCount += MemoryLayout<UUID>.size
        byteCount += MemoryLayout<Int>.size
        byteCount += MemoryLayout<Bool>.size

        if let variants = message.variants {
            byteCount += variants.reduce(0) { $0 + $1.utf8.count }
        }

        return byteCount
    }
}

#Preview {
    NavigationStack {
        CacheView()
    }
    .modelContainer(cachePreviewModelContainer)
}

@MainActor
private let cachePreviewModelContainer: ModelContainer = {
    let schema = Schema([
        BotModel.self,
        ChatHistory.self,
        ChatFolder.self,
        ChatMessageEntity.self
    ])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [configuration])
    let context = container.mainContext

    let bots = [
        BotModel(
            name: "Yoga Assistant",
            subtitle: "Wellness planning",
            date: "Apr 29, 2026",
            avatarSystemName: "figure.yoga",
            iconColorName: "green",
            isPinned: false,
            greeting: "Ready for practice?"
        ),
        BotModel(
            name: "Helpful Assistant",
            subtitle: "Daily work",
            date: "Apr 28, 2026",
            avatarSystemName: "sparkles",
            iconColorName: "blue",
            isPinned: true,
            greeting: "How can I help?"
        )
    ]

    for bot in bots {
        context.insert(bot)
    }

    context.insert(
        ChatHistory(
            messages: [
                ChatMessageEntity(text: "Build a morning routine", isUser: true, index: 0, timestamp: .now),
                ChatMessageEntity(text: "Start with five minutes of breathing, then add mobility work.", isUser: false, index: 1, timestamp: .now)
            ],
            bot: bots[0]
        )
    )

    context.insert(
        ChatHistory(
            messages: [
                ChatMessageEntity(text: "Summarize this release note", isUser: true, index: 0, timestamp: .now),
                ChatMessageEntity(text: "The update improves local cache visibility and cleanup.", isUser: false, index: 1, timestamp: .now)
            ],
            bot: bots[1]
        )
    )

    try? context.save()
    return container
}()
