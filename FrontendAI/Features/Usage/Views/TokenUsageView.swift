import SwiftUI
import SwiftData

struct TokenUsageView: View {
    @Query private var bots: [BotModel]
    @Query private var histories: [ChatHistory]

    var body: some View {
        let rows = TokenUsageRow.makeRows(bots: bots, histories: histories)
        let totalTokens = rows.reduce(0) { $0 + $1.tokenCount }
        let totalMessages = rows.reduce(0) { $0 + $1.messageCount }
        let userTokens = rows.reduce(0) { $0 + $1.userTokenCount }
        let replyTokens = rows.reduce(0) { $0 + $1.replyTokenCount }

        List {
            Section {
                VStack(alignment: .leading, spacing: UsageStyle.spacing) {
                    UsageHero(
                        eyebrow: "Estimated tokens", value: totalTokens.formatted(),
                        description: "The text in your saved conversations, measured in tokens.",
                        systemImage: "text.word.spacing"
                    )
                    if totalMessages > 0 {
                        Divider()
                        UsageMetricPair(
                            firstTitle: "Avg. per message", firstValue: (totalTokens / totalMessages).formatted(),
                            secondTitle: "Saved messages", secondValue: totalMessages.formatted()
                        )
                    }
                }
                .listRowInsets(UsageStyle.rowInsets)
            } footer: {
                Text("Estimated from saved text, including reply variants. Provider billing may differ: requests can also include instructions and conversation context.")
            }

            if totalMessages == 0 {
                ContentUnavailableView(
                    "No Token Usage", systemImage: "text.word.spacing",
                    description: Text("Send a message to see how tokens are distributed across your conversations.")
                )
                .listRowBackground(Color.clear)
            } else {
                Section {
                    UsageSplitView(
                        firstTitle: "Your messages", firstValue: userTokens.formatted(),
                        secondTitle: "Character replies", secondValue: replyTokens.formatted(),
                        firstShare: totalTokens > 0 ? Double(userTokens) / Double(totalTokens) : 0,
                        hasValues: totalTokens > 0
                    )
                    .listRowInsets(UsageStyle.rowInsets)
                } header: {
                    UsageSectionHeading(title: "Where tokens go", subtitle: "Your writing and the replies it receives")
                }

                Section {
                    ForEach(rows) { row in
                        let share = totalTokens > 0 ? Double(row.tokenCount) / Double(totalTokens) : 0
                        let average = row.messageCount > 0 ? row.tokenCount / row.messageCount : 0
                        UsageCharacterRow(
                            bot: row.bot, title: row.title, value: row.tokenCount.formatted(),
                            detail: "\(share.formatted(.percent.precision(.fractionLength(0)))) of tokens · \(average.formatted()) per message",
                            share: share
                        )
                        .listRowInsets(UsageStyle.rowInsets)
                    }
                } header: {
                    UsageSectionHeading(title: "Tokens by character", subtitle: "Ranked by estimated token count")
                }
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.top, UsageStyle.spacing, for: .scrollContent)
        .navigationTitle("Token Usage")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        TokenUsageView()
    }
    .modelContainer(UsagePreviewData.container)
}

#Preview("Empty") {
    NavigationStack {
        TokenUsageView()
    }
    .modelContainer(UsagePreviewData.makeContainer(empty: true))
}

#endif
