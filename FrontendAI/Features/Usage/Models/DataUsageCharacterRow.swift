import Foundation

struct DataUsageCharacterRow: Identifiable {
    let id: UUID
    let bot: BotModel?
    let byteCount: Int
    let messageCount: Int
    let totalBytes: Int

    var title: String {
        bot?.name ?? "Deleted character"
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
