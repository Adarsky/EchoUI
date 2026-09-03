import Foundation
import SwiftData

@Model
class ChatHistory {
    @Attribute
    var messages: [ChatMessageEntity]
    
    @Attribute
    var date: Date
    
    @Relationship
    var bot: BotModel
    
    @Attribute
    var botID: UUID
    
    @Attribute
    var personaID: UUID?
    
    @Attribute
    var hasPersonaOverride: Bool = false

    init(
        messages: [ChatMessageEntity],
        date: Date = .now,
        bot: BotModel,
        personaID: UUID? = nil,
        hasPersonaOverride: Bool = false
    ) {
        self.messages = messages
        self.date = date
        self.bot = bot
        self.botID = bot.id
        self.personaID = personaID
        self.hasPersonaOverride = hasPersonaOverride
    }

    var selectionIdentifier: String? {
        messages
            .min(by: { $0.index < $1.index })?
            .id
            .uuidString
    }
}

@Model
class ChatMessageEntity: Identifiable {
    var id: UUID
    var text: String
    var isUser: Bool
    var index: Int
    var timestamp: Date?
    var variants: [String]?
    var currentVariantIndex: Int?

    init(
        id: UUID = UUID(),
        text: String,
        isUser: Bool,
        index: Int,
        timestamp: Date? = nil,
        variants: [String]? = nil,
        currentVariantIndex: Int? = nil
    ) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.index = index
        self.timestamp = timestamp
        self.variants = variants
        self.currentVariantIndex = currentVariantIndex
    }

    var displayText: String {
        ChatStoredVariant.restored(
            from: text,
            migrateLegacyError: !isUser
        )
        .displayText
    }
}

enum ChatHistoryPersistence {
    @MainActor
    static func replaceMessages(
        in history: ChatHistory,
        with messages: [ChatMessageEntity],
        context: ModelContext
    ) {
        let retainedObjects = Set(messages.map(ObjectIdentifier.init))
        let removedMessages = history.messages.filter {
            !retainedObjects.contains(ObjectIdentifier($0))
        }

        history.messages = messages
        for message in removedMessages {
            context.delete(message)
        }
    }

    @MainActor
    static func delete(_ history: ChatHistory, context: ModelContext) {
        let messages = history.messages
        context.delete(history)
        for message in messages {
            context.delete(message)
        }
    }

    @MainActor
    static func deleteHistories(for botID: UUID, context: ModelContext) throws {
        let descriptor = FetchDescriptor<ChatHistory>(
            predicate: #Predicate { $0.botID == botID }
        )
        for history in try context.fetch(descriptor) {
            delete(history, context: context)
        }
    }

    @MainActor
    static func deleteAllHistoriesAndMessages(context: ModelContext) throws {
        for history in try context.fetch(FetchDescriptor<ChatHistory>()) {
            context.delete(history)
        }
        for message in try context.fetch(FetchDescriptor<ChatMessageEntity>()) {
            context.delete(message)
        }
    }
}
