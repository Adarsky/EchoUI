import Foundation
import SwiftData

extension ChatView {
        private var lastOpenedHistoryDefaultsKey: String {
            "lastOpenedChatHistory.\(botID.uuidString.lowercased())"
        }

        // MARK: - History (load/save)
        func loadHistory() {
            Task { @MainActor in
                resetInitialMessagePositioning()
                savedBotModel = allBots.first(where: { $0.id == botID })
                do {
                    let descriptor = FetchDescriptor<ChatHistory>(
                        predicate: #Predicate { $0.botID == botID },
                        sortBy: [SortDescriptor(\.date, order: .reverse)]
                    )
                    let histories = try modelContext.fetch(descriptor)
                    if let history = historyToOpen(from: histories) {
                        currentHistory = history
                        applyPersonaOverride(from: history)
                        rememberOpenedHistory(history)
                        messages = restoredMessages(from: history)
                        refreshActiveAppearance()
                    } else {
                        chatPersonaID = nil
                        hasChatPersonaOverride = false
                        messages.append(ChatMessageModel(content: bot.greeting, isUser: false))
                        refreshActiveAppearance()
                    }
                } catch {
                    print("⚠️ Load failed: \(error)")
                    streamingReply = nil
                }
            }
        }

        @MainActor
        func saveChatHistory() {
            let persistableMessages = messages.filter(\.hasPersistableVariant)
            guard !persistableMessages.isEmpty else { return }

            var existingEntitiesByID: [UUID: ChatMessageEntity] = [:]
            for entity in currentHistory?.messages ?? [] {
                existingEntitiesByID[entity.id] = entity
            }

            let entities: [ChatMessageEntity] = persistableMessages.enumerated().compactMap { index, msg in
                guard let values = msg.persistenceValues(includeVariants: !msg.isUser) else {
                    return nil
                }

                if let entity = existingEntitiesByID[msg.id] {
                    entity.text = values.text
                    entity.isUser = msg.isUser
                    entity.index = index
                    entity.timestamp = msg.timestamp
                    entity.variants = values.variants
                    entity.currentVariantIndex = values.currentVariantIndex
                    return entity
                }

                return ChatMessageEntity(
                    id: msg.id,
                    text: values.text,
                    isUser: msg.isUser,
                    index: index,
                    timestamp: msg.timestamp,
                    variants: values.variants,
                    currentVariantIndex: values.currentVariantIndex
                )
            }

            if let history = currentHistory {
                ChatHistoryPersistence.replaceMessages(
                    in: history,
                    with: entities,
                    context: modelContext
                )
                history.date = .now
                history.personaID = chatPersonaID
                history.hasPersonaOverride = hasChatPersonaOverride
                rememberOpenedHistory(history)
            } else if let realBotModel = savedBotModel {
                let new = ChatHistory(
                    messages: entities,
                    bot: realBotModel,
                    personaID: chatPersonaID,
                    hasPersonaOverride: hasChatPersonaOverride
                )
                modelContext.insert(new)
                currentHistory = new
                rememberOpenedHistory(new)
            }
            do {
                try modelContext.save()
            } catch {
                alertMessage = "Could not save this chat. Your current messages remain open so you can try again."
                showAlertBanner = true
            }
        }

        @MainActor
        func loadSelectedHistory(_ history: ChatHistory) {
            resetInitialMessagePositioning()
            currentHistory = history
            applyPersonaOverride(from: history)
            rememberOpenedHistory(history)
            messages = restoredMessages(from: history)
            isManualHistoryLoad = true
            refreshActiveAppearance()
        }

        @MainActor
        private func restoredMessages(from history: ChatHistory) -> [ChatMessageModel] {
            history.messages
                .sorted { $0.index < $1.index }
                .compactMap { entity in
                    let message = ChatMessageModel(
                        id: entity.id,
                        content: entity.text,
                        isUser: entity.isUser,
                        timestamp: entity.timestamp ?? history.date,
                        variants: entity.variants,
                        currentIndex: entity.currentVariantIndex ?? 0,
                        restorePersistedFailures: true
                    )

                    return message.isDiscardableEmptyAssistantPlaceholder ? nil : message
                }
        }

        private func historyToOpen(from histories: [ChatHistory]) -> ChatHistory? {
            guard !histories.isEmpty else { return nil }
            guard let storedIdentifier = UserDefaults.standard.string(forKey: lastOpenedHistoryDefaultsKey) else {
                return histories.first
            }
            return histories.first { $0.selectionIdentifier == storedIdentifier } ?? histories.first
        }

        private func rememberOpenedHistory(_ history: ChatHistory) {
            guard let identifier = history.selectionIdentifier else { return }
            UserDefaults.standard.set(identifier, forKey: lastOpenedHistoryDefaultsKey)
        }

        @MainActor
        private func applyPersonaOverride(from history: ChatHistory) {
            chatPersonaID = history.personaID
            hasChatPersonaOverride = history.hasPersonaOverride
        }
}
