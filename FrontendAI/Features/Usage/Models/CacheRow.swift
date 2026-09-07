import Foundation

struct CacheRow: Identifiable {
    let id: UUID
    let bot: BotModel?
    let histories: [ChatHistory]
    let byteCount: Int
    let totalBytes: Int

    var title: String {
        bot?.name ?? "Deleted character"
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
