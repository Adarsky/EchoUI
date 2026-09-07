import Foundation
import Testing
@testable import FrontendAI

struct UsageInsightsTests {
    @Test @MainActor
    func tokenBreakdownIncludesReplyVariantsAndDeletedCharacters() throws {
        let bot = makeBot()
        let history = ChatHistory(messages: [
            ChatMessageEntity(text: "12345678", isUser: true, index: 0),
            ChatMessageEntity(text: "1234", isUser: false, index: 1, variants: ["123456789012"])
        ], bot: bot)
        let row = try #require(TokenUsageRow.makeRows(bots: [], histories: [history]).first)
        #expect(row.bot == nil)
        #expect(row.userTokenCount == 2)
        #expect(row.replyTokenCount == 4)
        #expect(row.tokenCount == 6)
        #expect(row.messageCount == 2)
    }

    @Test @MainActor
    func weeklyActivityUsesMessageDatesAndFillsInactiveDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 5, hour: 12)))
        let sixDaysAgo = try #require(calendar.date(byAdding: .day, value: -6, to: now))
        let outsideWeek = try #require(calendar.date(byAdding: .day, value: -7, to: now))
        let future = now.addingTimeInterval(3600)
        let history = ChatHistory(messages: [
            ChatMessageEntity(text: "At start", isUser: true, index: 0, timestamp: sixDaysAgo),
            ChatMessageEntity(text: "Fallback to history", isUser: false, index: 1),
            ChatMessageEntity(text: "Too old", isUser: true, index: 2, timestamp: outsideWeek),
            ChatMessageEntity(text: "Future", isUser: false, index: 3, timestamp: future)
        ], date: now, bot: makeBot())
        let days = UsageActivityDay.lastWeek(histories: [history], now: now, calendar: calendar)
        #expect(days.count == 7)
        #expect(days.first?.messageCount == 1)
        #expect(days.last?.messageCount == 1)
        #expect(days.reduce(0) { $0 + $1.messageCount } == 2)
        #expect(days.count(where: { $0.messageCount == 0 }) == 5)
    }

    @Test @MainActor
    func trafficBucketsExcludeFutureAndOutOfPeriodMessages() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 5, hour: 12)))
        let start = DataUsagePeriod.month.interval(containing: now, calendar: calendar).start
        let botID = UUID()
        let points = [
            DataUsagePoint(botID: botID, bot: nil, date: start, byteCount: 100, isUser: true),
            DataUsagePoint(botID: botID, bot: nil, date: now, byteCount: 200, isUser: false),
            DataUsagePoint(botID: botID, bot: nil, date: start.addingTimeInterval(-1), byteCount: 400, isUser: true),
            DataUsagePoint(botID: botID, bot: nil, date: now.addingTimeInterval(3600), byteCount: 800, isUser: false)
        ]
        let buckets = DataUsagePeriod.month.buckets(for: points, now: now, calendar: calendar)
        #expect(buckets.count == 5)
        #expect(buckets.reduce(0) { $0 + $1.byteCount } == 300)
        #expect(buckets.first?.byteCount == 100)
        #expect(buckets.last?.byteCount == 200)
    }

    @MainActor
    private func makeBot() -> BotModel {
        BotModel(name: "Test", subtitle: "", date: "", avatarSystemName: "star", iconColorName: "blue", isPinned: false, greeting: "")
    }
}
