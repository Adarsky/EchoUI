import Foundation

struct TokenUsageRow: Identifiable {
    let id: UUID
    let bot: BotModel?
    let tokenCount: Int
    let messageCount: Int
    let userTokenCount: Int
    let replyTokenCount: Int

    var title: String {
        bot?.name ?? "Deleted character"
    }

    static func makeRows(bots: [BotModel], histories: [ChatHistory]) -> [TokenUsageRow] {
        let groupedHistories = Dictionary(grouping: histories, by: \.botID)
        let botsByID = Dictionary(uniqueKeysWithValues: bots.map { ($0.id, $0) })

        return groupedHistories.map { botID, histories in
            let messages = histories.flatMap(\.messages)
            var userTokens = 0
            var replyTokens = 0
            for message in messages {
                let count = TokenUsageEstimator.estimatedTokenCount(for: message)
                if message.isUser { userTokens += count } else { replyTokens += count }
            }
            return TokenUsageRow(
                id: botID,
                bot: botsByID[botID],
                tokenCount: userTokens + replyTokens,
                messageCount: messages.count,
                userTokenCount: userTokens,
                replyTokenCount: replyTokens
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
