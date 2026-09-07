import Foundation

enum DataUsagePeriod: String, CaseIterable, Identifiable {
    case day
    case week
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day:
            return "Day"
        case .week:
            return "Week"
        case .month:
            return "Month"
        case .year:
            return "Year"
        }
    }

    var dateComponent: Calendar.Component {
        switch self {
        case .day:
            return .day
        case .week:
            return .weekOfYear
        case .month:
            return .month
        case .year:
            return .year
        }
    }

    var bucketComponent: Calendar.Component {
        switch self {
        case .day:
            return .hour
        case .week, .month:
            return .day
        case .year:
            return .month
        }
    }

    var chartUnit: Calendar.Component {
        bucketComponent
    }

    var desiredXAxisMarks: Int {
        switch self {
        case .day:
            return 6
        case .week:
            return 7
        case .month:
            return 6
        case .year:
            return 4
        }
    }

    var axisDateFormat: Date.FormatStyle {
        switch self {
        case .day:
            return .dateTime.hour()
        case .week, .month:
            return .dateTime.day()
        case .year:
            return .dateTime.month(.abbreviated)
        }
    }

    var detailDateFormat: Date.FormatStyle {
        switch self {
        case .day: .dateTime.hour().minute()
        case .week, .month: .dateTime.month(.abbreviated).day()
        case .year: .dateTime.month(.wide)
        }
    }

    func rangeDescription(now: Date) -> String {
        let start = interval(containing: now).start
        if self == .day {
            return "Today · \(now.formatted(date: .abbreviated, time: .omitted))"
        }
        return "\(start.formatted(date: .abbreviated, time: .omitted)) – \(now.formatted(date: .abbreviated, time: .omitted))"
    }

    func interval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: dateComponent, for: date) ?? DateInterval(start: date, end: date)
    }

    func buckets(
        for points: [DataUsagePoint],
        now: Date,
        calendar: Calendar = .current
    ) -> [DataUsageBucket] {
        let interval = interval(containing: now, calendar: calendar)
        var bucketsByDate: [Date: Int] = [:]

        var bucketDate = bucketStart(for: interval.start, calendar: calendar)
        while bucketDate <= now {
            bucketsByDate[bucketDate] = 0
            guard let nextDate = calendar.date(byAdding: bucketComponent, value: 1, to: bucketDate) else {
                break
            }
            bucketDate = nextDate
        }

        for point in points where point.date >= interval.start && point.date < interval.end && point.date <= now {
            let date = bucketStart(for: point.date, calendar: calendar)
            bucketsByDate[date, default: 0] += point.byteCount
        }

        return bucketsByDate
            .map { DataUsageBucket(date: $0.key, byteCount: $0.value) }
            .sorted { $0.date < $1.date }
    }

    private func bucketStart(for date: Date, calendar: Calendar) -> Date {
        switch self {
        case .day:
            return calendar.dateInterval(of: .hour, for: date)?.start ?? date
        case .week, .month:
            return calendar.startOfDay(for: date)
        case .year:
            return calendar.dateInterval(of: .month, for: date)?.start ?? date
        }
    }
}
