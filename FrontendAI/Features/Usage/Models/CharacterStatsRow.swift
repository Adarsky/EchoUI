import Foundation

struct CharacterStatsRow: Identifiable {
    let id: UUID
    let bot: BotModel?
    let historyCount: Int
    let messageCount: Int

    var title: String {
        bot?.name ?? "Deleted character"
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
