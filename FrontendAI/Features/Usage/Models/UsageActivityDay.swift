import Foundation

struct UsageActivityDay: Identifiable {
    let date: Date
    let messageCount: Int
    var id: Date { date }

    static func lastWeek(histories: [ChatHistory], now: Date = .now, calendar: Calendar = .current) -> [Self] {
        let today = calendar.startOfDay(for: now)
        let dates = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0 - 6, to: today) }
        guard let start = dates.first else { return [] }
        var counts: [Date: Int] = [:]
        for history in histories {
            for message in history.messages {
                let date = message.timestamp ?? history.date
                guard date >= start, date <= now else { continue }
                counts[calendar.startOfDay(for: date), default: 0] += 1
            }
        }
        return dates.map { Self(date: $0, messageCount: counts[$0, default: 0]) }
    }
}
