import Foundation
import SwiftData

@Model
class ChatHistory {
    @Attribute
    var historyID: UUID?

    @Attribute
    var parentHistoryID: UUID?

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
        historyID: UUID = UUID(),
        parentHistoryID: UUID? = nil,
        messages: [ChatMessageEntity],
        date: Date = .now,
        bot: BotModel,
        personaID: UUID? = nil,
        hasPersonaOverride: Bool = false
    ) {
        self.historyID = historyID
        self.parentHistoryID = parentHistoryID
        self.messages = messages
        self.date = date
        self.bot = bot
        self.botID = bot.id
        self.personaID = personaID
        self.hasPersonaOverride = hasPersonaOverride
    }

    @discardableResult
    func ensureHistoryID() -> UUID {
        if let historyID {
            return historyID
        }

        let generatedID = UUID()
        historyID = generatedID
        return generatedID
    }

    var selectionIdentifier: String? {
        messages
            .min(by: { $0.index < $1.index })?
            .id
            .uuidString
            ?? historyID?.uuidString
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
    static func createBranch(
        from parent: ChatHistory,
        throughMessageID messageID: UUID,
        context: ModelContext
    ) -> ChatHistory? {
        let orderedMessages = parent.messages.sorted { $0.index < $1.index }
        guard
            let selectedIndex = orderedMessages.firstIndex(where: { $0.id == messageID }),
            !orderedMessages[selectedIndex].isUser
        else {
            return nil
        }

        let copiedMessages = orderedMessages[...selectedIndex].enumerated().map { index, message in
            ChatMessageEntity(
                text: message.text,
                isUser: message.isUser,
                index: index,
                timestamp: message.timestamp,
                variants: message.variants,
                currentVariantIndex: message.currentVariantIndex
            )
        }

        let branch = ChatHistory(
            parentHistoryID: parent.ensureHistoryID(),
            messages: copiedMessages,
            bot: parent.bot,
            personaID: parent.personaID,
            hasPersonaOverride: parent.hasPersonaOverride
        )
        context.insert(branch)
        return branch
    }

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
        if let deletedHistoryID = history.historyID,
           let allHistories = try? context.fetch(FetchDescriptor<ChatHistory>()) {
            for child in allHistories where child.parentHistoryID == deletedHistoryID {
                child.parentHistoryID = nil
            }
        }

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
