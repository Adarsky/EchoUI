import SwiftUI
import SwiftData

struct StatsView: View {
    @Query private var bots: [BotModel]
    @Query private var histories: [ChatHistory]

    private var rows: [CharacterStatsRow] {
        CharacterStatsRow.makeRows(bots: bots, histories: histories)
    }

    private var totalMessages: Int {
        rows.reduce(0) { $0 + $1.messageCount }
    }

    var body: some View {
        List {
            Section {
                if rows.isEmpty {
                    ContentUnavailableView(
                        "No Character Statistics",
                        systemImage: "person.2.slash",
                        description: Text("Saved chat history will appear here.")
                    )
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 24)
                } else if let topRow = rows.first {
                    CharacterStatsHeroRow(row: topRow)
                }
            } header: {
                Text("Most used overall")
            }

            Section("Characters") {
                ForEach(rows) { row in
                    CharacterStatsRowView(row: row, totalMessages: totalMessages)
                }
            }
        }
        .navigationTitle("Character Stats")
    }
}

private struct CharacterStatsHeroRow: View {
    let row: CharacterStatsRow

    var body: some View {
        HStack(spacing: 14) {
            avatar
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)

                Text("\(row.messageCount.formatted()) messages total")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var avatar: Image {
        row.bot?.avatarImage ?? Image(systemName: "questionmark.circle.fill")
    }
}

private struct CharacterStatsRowView: View {
    let row: CharacterStatsRow
    let totalMessages: Int

    private var share: Double {
        guard totalMessages > 0 else { return 0 }
        return Double(row.messageCount) / Double(totalMessages)
    }

    var body: some View {
        HStack(spacing: 12) {
            avatar
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(row.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(row.messageCount.formatted())
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: share)
                    .progressViewStyle(.linear)
                    .tint(.blue)

                Text("\(row.historyCount.formatted()) chats")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var avatar: Image {
        row.bot?.avatarImage ?? Image(systemName: "questionmark.circle.fill")
    }
}

private struct CharacterStatsRow: Identifiable {
    let id: UUID
    let bot: BotModel?
    let historyCount: Int
    let messageCount: Int

    var title: String {
        bot?.name ?? "Deleted Bot"
    }

    static func makeRows(bots: [BotModel], histories: [ChatHistory]) -> [CharacterStatsRow] {
        let groupedHistories = Dictionary(grouping: histories, by: \.botID)
        let botsByID = Dictionary(uniqueKeysWithValues: bots.map { ($0.id, $0) })

        return groupedHistories.map { botID, histories in
            CharacterStatsRow(
                id: botID,
                bot: botsByID[botID],
                historyCount: histories.count,
                messageCount: histories.reduce(0) { $0 + $1.messages.count }
            )
        }
        .sorted {
            if $0.messageCount == $1.messageCount {
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return $0.messageCount > $1.messageCount
        }
    }
}

#Preview("Stats") {
    NavigationStack {
        StatsView()
    }
    .modelContainer(statsPreviewModelContainer)
}

@MainActor
private let statsPreviewModelContainer: ModelContainer = {
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
        )
    ]

    for bot in bots {
        context.insert(bot)
    }

    for index in 0..<8 {
        let bot = bots[index % bots.count]
        let repeatedText = String(repeating: "Example message payload. ", count: 2 + index)
        context.insert(
            ChatHistory(
                messages: [
                    ChatMessageEntity(text: repeatedText, isUser: true, index: 0),
                    ChatMessageEntity(text: "\(repeatedText)\(repeatedText)", isUser: false, index: 1)
                ],
                date: .now,
                bot: bot
            )
        )
    }

    try? context.save()
    return container
}()
