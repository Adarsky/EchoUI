//  ChatView+History.swift
//  FrontendAI

import Foundation
import SwiftData

extension ChatView {
        // MARK: – History (load/save)
        func loadHistory() {
            Task { @MainActor in
                didApplyInitialScrollPosition = false
                savedBotModel = allBots.first(where: { $0.id == botID })
                do {
                    let descriptor = FetchDescriptor<ChatHistory>(
                        predicate: #Predicate { $0.botID == botID },
                        sortBy: [SortDescriptor(\.date, order: .reverse)]
                    )
                    let histories = try modelContext.fetch(descriptor)
                    if let last = histories.first {
                        currentHistory = last
                        messages = last.messages
                            .sorted { $0.index < $1.index }
                            .map { entity in
                                ChatMessageModel(
                                    id: entity.id,
                                    content: entity.text,
                                    isUser: entity.isUser,
                                    timestamp: entity.timestamp ?? last.date,
                                    variants: entity.variants,
                                    currentIndex: entity.currentVariantIndex ?? 0
                                )
                            }
                    } else {
                        messages.append(ChatMessageModel(content: bot.greeting, isUser: false))
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
            } else if let realBotModel = savedBotModel {
                let new = ChatHistory(messages: entities, bot: realBotModel)
                modelContext.insert(new)
                currentHistory = new
            }
            try? modelContext.save()
        }

        @MainActor
        func loadSelectedHistory(_ history: ChatHistory) {
            didApplyInitialScrollPosition = false
            currentHistory = history
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
        }
}
