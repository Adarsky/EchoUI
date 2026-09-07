import SwiftUI
import SwiftData

struct StatsView: View {
    @Query private var bots: [BotModel]
    @Query private var histories: [ChatHistory]

    var body: some View {
        let rows = CharacterStatsRow.makeRows(bots: bots, histories: histories)
        let totalMessages = rows.reduce(0) { $0 + $1.messageCount }
        let activity = UsageActivityDay.lastWeek(histories: histories)

        List {
            Section {
                VStack(alignment: .leading, spacing: UsageStyle.spacing) {
                    UsageHero(
                        eyebrow: "Your conversations", value: totalMessages.formatted(),
                        description: "Messages exchanged across your saved chats.",
                        systemImage: "bubble.left.and.bubble.right"
                    )
                    if !rows.isEmpty {
                        Divider()
                        UsageMetricPair(
                            firstTitle: "Characters", firstValue: rows.count.formatted(),
                            secondTitle: "Saved chats", secondValue: histories.count.formatted()
                        )
                    }
                }
                .listRowInsets(UsageStyle.rowInsets)
            }

            if rows.isEmpty {
                ContentUnavailableView(
                    "No Conversations Yet", systemImage: "person.2",
                    description: Text("Start a chat to discover your most talked-to characters and activity patterns.")
                )
                .listRowBackground(Color.clear)
            } else {
                Section {
                    UsageActivityChart(days: activity)
                        .listRowInsets(UsageStyle.rowInsets)
                } header: {
                    UsageSectionHeading(title: "Your rhythm", subtitle: "Message activity over the last 7 days")
                }

                Section {
                    ForEach(rows.enumerated(), id: \.element.id) { index, row in
                        let share = totalMessages > 0 ? Double(row.messageCount) / Double(totalMessages) : 0
                        UsageCharacterRow(
                            bot: row.bot, title: row.title, value: "\(row.messageCount.formatted()) messages",
                            detail: "\(row.historyCount.formatted()) chats · \(share.formatted(.percent.precision(.fractionLength(0)))) of activity",
                            share: share, rank: index + 1
                        )
                        .listRowInsets(UsageStyle.rowInsets)
                    }
                } header: {
                    UsageSectionHeading(title: "Most talked to", subtitle: "All saved conversations · Ranked by messages")
                } footer: {
                    Text("Statistics reflect chats currently saved on this device. Deleting a chat also removes it from these totals.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.top, UsageStyle.spacing, for: .scrollContent)
        .navigationTitle("Character Stats")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        StatsView()
    }
    .modelContainer(UsagePreviewData.container)
}

#Preview("Empty") {
    NavigationStack {
        StatsView()
    }
    .modelContainer(UsagePreviewData.makeContainer(empty: true))
}

#endif
