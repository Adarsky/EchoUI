import Foundation

struct DataUsagePoint {
    let botID: UUID
    let bot: BotModel?
    let date: Date
    let byteCount: Int
    let isUser: Bool

    static func makePoints(bots: [BotModel], histories: [ChatHistory]) -> [DataUsagePoint] {
        let botsByID = Dictionary(uniqueKeysWithValues: bots.map { ($0.id, $0) })

        return histories.flatMap { history in
            history.messages.map { message in
                DataUsagePoint(
                    botID: history.botID,
                    bot: botsByID[history.botID],
                    date: message.timestamp ?? history.date,
                    byteCount: DataUsageEstimator.estimatedTrafficByteCount(for: message),
                    isUser: message.isUser
                )
            }
        }
    }
}
