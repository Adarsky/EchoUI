import Foundation
import SwiftData

@MainActor
enum ChatHistoryWriter {
    static func save(
        messages: [ChatMessageModel],
        history: ChatHistory?,
        bot: BotModel?,
        personaID: UUID?,
        hasPersonaOverride: Bool,
        context: ModelContext,
        saveContext: (ModelContext) throws -> Void = { try $0.save() }
    ) throws -> ChatHistory? {
        let persistableMessages = messages.filter(\.hasPersistableVariant)
        guard !persistableMessages.isEmpty || history != nil else { return nil }
        guard let bot = history?.bot ?? bot else {
            throw CocoaError(.validationMissingMandatoryProperty)
        }
        let previousState = history.map(Snapshot.init)

        do {
            var existingEntitiesByID: [UUID: ChatMessageEntity] = [:]
            for entity in history?.messages ?? [] {
                existingEntitiesByID[entity.id] = entity
            }
            let entities = persistableMessages.enumerated().compactMap { index, message -> ChatMessageEntity? in
                guard let values = message.persistenceValues(includeVariants: !message.isUser) else { return nil }
                let entity = existingEntitiesByID[message.id] ?? ChatMessageEntity(
                    id: message.id, text: values.text, isUser: message.isUser, index: index
                )
                entity.text = values.text
                entity.index = index
                entity.timestamp = message.timestamp
                entity.variants = values.variants
                entity.currentVariantIndex = values.currentVariantIndex
                return entity
            }

            let savedHistory: ChatHistory
            if let history {
                ChatHistoryPersistence.replaceMessages(in: history, with: entities, context: context)
                savedHistory = history
            } else {
                savedHistory = ChatHistory(messages: entities, bot: bot)
                context.insert(savedHistory)
            }
            savedHistory.ensureHistoryID()
            savedHistory.date = .now
            savedHistory.personaID = personaID
            savedHistory.hasPersonaOverride = hasPersonaOverride
            context.processPendingChanges()
            try saveContext(context)
            return savedHistory
        } catch {
            context.rollback()
            // SwiftData can leave the registered relationship array cached
            // after rollback. Restore the caller's objects as well as the store.
            previousState?.restore()
            throw error
        }
    }

    private struct Snapshot {
        let history: ChatHistory
        let historyID: UUID?
        let date: Date
        let personaID: UUID?
        let hasPersonaOverride: Bool
        let messages: [MessageSnapshot]

        init(_ history: ChatHistory) {
            self.history = history
            historyID = history.historyID
            date = history.date
            personaID = history.personaID
            hasPersonaOverride = history.hasPersonaOverride
            messages = history.messages.map(MessageSnapshot.init)
        }

        func restore() {
            history.historyID = historyID
            history.date = date
            history.personaID = personaID
            history.hasPersonaOverride = hasPersonaOverride
            history.messages = messages.map(\.entity)
            for message in messages { message.restore() }
        }
    }

    private struct MessageSnapshot {
        let entity: ChatMessageEntity
        let text: String
        let index: Int
        let timestamp: Date?
        let variants: [String]?
        let currentVariantIndex: Int?

        init(_ entity: ChatMessageEntity) {
            self.entity = entity
            text = entity.text
            index = entity.index
            timestamp = entity.timestamp
            variants = entity.variants
            currentVariantIndex = entity.currentVariantIndex
        }

        func restore() {
            entity.text = text
            entity.index = index
            entity.timestamp = timestamp
            entity.variants = variants
            entity.currentVariantIndex = currentVariantIndex
        }
    }
}
