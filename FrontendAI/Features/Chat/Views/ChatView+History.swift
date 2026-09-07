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
                        messages.append(ChatMessageModel(content: currentGreeting, isUser: false))
                        refreshActiveAppearance()
                    }
                } catch {
                    print("⚠️ Load failed: \(error)")
                    streamingReply = nil
                }
            }
        }

        @MainActor
        @discardableResult
        func saveChatHistory() -> Bool {
            if isPreviewSeeded { return true }
            savedBotModel = currentBotModel
            do {
                currentHistory = try ChatHistoryWriter.save(
                    messages: messages,
                    history: currentHistory,
                    bot: savedBotModel,
                    personaID: chatPersonaID,
                    hasPersonaOverride: hasChatPersonaOverride,
                    context: modelContext
                )
                if let currentHistory {
                    rememberOpenedHistory(currentHistory)
                }
                return true
            } catch {
                notification = .error(
                    "Couldn’t save chat",
                    message: "Your current messages remain open so you can try again."
                )
                return false
            }
        }

        @MainActor
        func branchChat(at messageID: UUID) {
            guard !isGenerating else { return }
            guard let selectedMessage = messages.first(where: { $0.id == messageID }),
                  !selectedMessage.isUser else {
                return
            }

            if savedBotModel == nil {
                savedBotModel = allBots.first(where: { $0.id == botID })
            }
            guard saveChatHistory() else { return }

            guard let parent = currentHistory,
                  let branch = ChatHistoryPersistence.createBranch(
                    from: parent,
                    throughMessageID: messageID,
                    context: modelContext
                  ) else {
                notification = .error(
                    "Couldn’t branch chat",
                    message: "Please wait for the message to finish and try again."
                )
                return
            }

            do {
                try modelContext.save()
            } catch {
                ChatHistoryPersistence.delete(branch, context: modelContext)
                notification = .error(
                    "Couldn’t save branch",
                    message: "The original chat is unchanged. Please try again."
                )
                return
            }

            resetInitialMessagePositioning()
            currentHistory = branch
            applyPersonaOverride(from: branch)
            rememberOpenedHistory(branch)
            messages = restoredMessages(from: branch)
            isManualHistoryLoad = true
            refreshActiveAppearance()
            notification = .branched
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
