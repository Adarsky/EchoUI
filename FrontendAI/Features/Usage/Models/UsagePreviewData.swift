#if DEBUG
import SwiftData
import Foundation

@MainActor
enum UsagePreviewData {
    static let container: ModelContainer = makeContainer()

    static func makeContainer(empty: Bool = false) -> ModelContainer {
        let schema = Schema([
            BotModel.self, ChatHistory.self, ChatFolder.self, ChatMessageEntity.self, APIServer.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: schema, configurations: [configuration]) else {
            fatalError("Could not create the usage preview container.")
        }
        guard !empty else { return container }
        let context = container.mainContext
        let names = ["Design Lead", "Swift Mentor", "Travel Planner", "Writing Partner", "Book Club", "Everyday Ideas"]
        let icons = ["paintpalette", "swift", "airplane", "pencil", "book", "lightbulb"]
        let bots = zip(names, icons).map { name, icon in
            BotModel(name: name, subtitle: "", date: "", avatarSystemName: icon, iconColorName: "teal", isPinned: false, greeting: "Hello")
        }
        for bot in bots { context.insert(bot) }
        for index in 0..<42 {
            let botIndex = index % bots.count
            let date = Calendar.current.date(byAdding: .day, value: -(index % 21), to: .now) ?? .now
            let text = String(repeating: "A thoughtful conversation about design, ideas, and everyday questions. ", count: (6 - botIndex) * 5)
            let messages = (0..<(2 + (index % 5) * 2)).map { messageIndex in
                ChatMessageEntity(
                    text: messageIndex.isMultiple(of: 2) ? "Can you help me explore this idea?" : text,
                    isUser: messageIndex.isMultiple(of: 2), index: messageIndex, timestamp: date
                )
            }
            context.insert(ChatHistory(messages: messages, date: date, bot: bots[botIndex]))
        }
        try? context.save()
        return container
    }
}
#endif
