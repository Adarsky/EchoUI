//
//  TokenUsageView.swift
//  FrontendAI
//
//  Created by macbook on 29.04.2026.
//

import SwiftUI
import SwiftData

struct TokenUsageView: View {
    @Query private var bots: [BotModel]
    @Query private var histories: [ChatHistory]

    private var rows: [TokenUsageRow] {
        TokenUsageRow.makeRows(bots: bots, histories: histories)
    }

    private var totalTokens: Int {
        rows.reduce(0) { $0 + $1.tokenCount }
    }

    var body: some View {
        List {
            Section {
                if rows.isEmpty {
                    ContentUnavailableView(
                        "No Token Usage",
                        systemImage: "text.word.spacing",
                        description: Text("Saved chat messages will appear here.")
                    )
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 24)
                } else {
                    TokenUsageSummaryView(
                        totalTokens: totalTokens,
                        totalMessages: rows.reduce(0) { $0 + $1.messageCount },
                        largestTokenCount: rows.map(\.tokenCount).max() ?? 0
                    )
                }
            }

            Section("Characters") {
                ForEach(rows) { row in
                    TokenUsageRowView(row: row, totalTokens: totalTokens)
                }
            }
        }
        .navigationTitle("Token Usage")
    }
}

private struct TokenUsageSummaryView: View {
    let totalTokens: Int
    let totalMessages: Int
    let largestTokenCount: Int

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
            GridRow {
                TokenUsageMetric(
                    title: "Tokens",
                    value: totalTokens.formatted(),
                    iconName: "t.square"
                )
                TokenUsageMetric(
                    title: "Messages",
                    value: totalMessages.formatted(),
                    iconName: "text.bubble"
                )
            }

            GridRow {
                TokenUsageMetric(
                    title: "Largest",
                    value: largestTokenCount.formatted(),
                    iconName: "chart.bar.xaxis"
                )
                TokenUsageMetric(
                    title: "Average",
                    value: averageTokens.formatted(),
                    iconName: "divide"
                )
            }
        }
        .padding(.vertical, 4)
    }

    private var averageTokens: Int {
        guard totalMessages > 0 else { return 0 }
        return totalTokens / totalMessages
    }
}

private struct TokenUsageMetric: View {
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

private struct TokenUsageRowView: View {
    let row: TokenUsageRow
    let totalTokens: Int

    private var share: Double {
        guard totalTokens > 0 else { return 0 }
        return Double(row.tokenCount) / Double(totalTokens)
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
                    Text(row.tokenCount.formatted())
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: share)
                    .progressViewStyle(.linear)
                    .tint(.blue)

                Text("\(row.messageCount.formatted()) messages")
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

private struct TokenUsageRow: Identifiable {
    let id: UUID
    let bot: BotModel?
    let tokenCount: Int
    let messageCount: Int

    var title: String {
        bot?.name ?? "Deleted Bot"
    }

    static func makeRows(bots: [BotModel], histories: [ChatHistory]) -> [TokenUsageRow] {
        let groupedHistories = Dictionary(grouping: histories, by: \.botID)
        let botsByID = Dictionary(uniqueKeysWithValues: bots.map { ($0.id, $0) })

        return groupedHistories.map { botID, histories in
            let messages = histories.flatMap(\.messages)
            return TokenUsageRow(
                id: botID,
                bot: botsByID[botID],
                tokenCount: messages.reduce(0) { $0 + TokenUsageEstimator.estimatedTokenCount(for: $1) },
                messageCount: messages.count
            )
        }
        .sorted {
            if $0.tokenCount == $1.tokenCount {
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return $0.tokenCount > $1.tokenCount
        }
    }
}

private enum TokenUsageEstimator {
    static func estimatedTokenCount(for message: ChatMessageEntity) -> Int {
        let textCount = estimatedTokenCount(for: message.text)
        let variantCount = message.variants?.reduce(0) { $0 + estimatedTokenCount(for: $1) } ?? 0
        return textCount + variantCount
    }

    private static func estimatedTokenCount(for text: String) -> Int {
        max(1, Int((Double(text.utf8.count) / 4.0).rounded(.up)))
    }
}

#Preview("Token Usage") {
    NavigationStack {
        TokenUsageView()
    }
    .modelContainer(tokenUsagePreviewModelContainer)
}

@MainActor
private let tokenUsagePreviewModelContainer: ModelContainer = {
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
