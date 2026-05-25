import Foundation
import SwiftData

extension ChatView {
        private var lastOpenedHistoryDefaultsKey: String {
            "lastOpenedChatHistory.\(botID.uuidString.lowercased())"
        }

        // MARK: - History (load/save)
        func loadHistory() {
            Task { @MainActor in
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
                        messages = history.messages
                            .sorted { $0.index < $1.index }
                            .map { entity in
                                ChatMessageModel(
                                    id: entity.id,
                                    content: entity.text,
                                    isUser: entity.isUser,
                                    timestamp: entity.timestamp ?? history.date,
                                    variants: entity.variants,
                                    currentIndex: entity.currentVariantIndex ?? 0
                                )
                            }
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
            guard !messages.isEmpty else { return }
            let lastMessageID = messages.last?.id

            let entities = messages.enumerated().map { index, msg in
                let shouldSaveVariants = !msg.isUser && msg.id == lastMessageID
                let storedVariants: [String]?
                let storedCurrentVariantIndex: Int?

                if shouldSaveVariants, let (variants, currentIndex) = msg.persistableVariantsForLastMessage() {
                    storedVariants = variants
                    storedCurrentVariantIndex = currentIndex
                } else {
                    storedVariants = nil
                    storedCurrentVariantIndex = nil
                }

                return ChatMessageEntity(
                    id: msg.id,
                    text: msg.content,
                    isUser: msg.isUser,
                    index: index,
                    timestamp: msg.timestamp,
                    variants: storedVariants,
                    currentVariantIndex: storedCurrentVariantIndex
                )
            }

            if let history = currentHistory {
                history.messages = entities
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
            try? modelContext.save()
        }

        @MainActor
        func loadSelectedHistory(_ history: ChatHistory) {
            currentHistory = history
            applyPersonaOverride(from: history)
            rememberOpenedHistory(history)
            messages = history.messages
                .sorted { $0.index < $1.index }
                .map { entity in
                    ChatMessageModel(
                        id: entity.id,
                        content: entity.text,
                        isUser: entity.isUser,
                        timestamp: entity.timestamp ?? history.date,
                        variants: entity.variants,
                        currentIndex: entity.currentVariantIndex ?? 0
                    )
                }
            isManualHistoryLoad = true
            refreshActiveAppearance()
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
