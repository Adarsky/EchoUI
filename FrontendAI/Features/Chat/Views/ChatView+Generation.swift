import SwiftUI
import Foundation

extension ChatView {
        // MARK: - Generation flow
        func stopGeneration() {
            generationTask?.cancel()
            streamingReply?.finalizeThinkingNow()
            streamingReply?.setStreaming(false)
            isThinking = false
            isGenerating = false
            generationTask = nil
            streamingReply = nil
            saveChatHistory()
        }

        func sendMessage() {
            guard let server = apiManager.selectedServer else {
                showMissingAPIAlert = true; return
            }
            if server.migrateAPIKeyToKeychainIfNeeded() {
                try? modelContext.save()
            }
            guard !inputText.isEmpty else { return }
            let config = ServerConfig(
                type: server.type,
                baseURL: server.baseURL,
                selectedModel: server.selectedModel,
                apiKey: server.apiKey,
                allowInsecureTLS: server.allowInsecureTLS,
                customCACertificateData: server.customCACertificateData
            )

            // User picked a branch; previous alternative variants are no longer needed.
            pruneAssistantVariants(keepingMessageID: nil)

            let userMessage = ChatMessageModel(content: inputText, isUser: true)
            withTransaction(.init(animation: nil)) { messages.append(userMessage) }
            trimMessagesIfNeeded()
            inputText = ""

            let payload = buildPayload(dummyUser: true)
            let replyID = UUID()
            let placeholder = ChatMessageModel(id: replyID, content: "", isUser: false)
            placeholder.setStreaming(true)
            messages.append(placeholder)
            streamingReply = placeholder
            isThinking = false
            isGenerating = true

            generationTask = Task {
                await streamReply(payload: payload, config: config, replyID: replyID)
            }
        }

        @MainActor
        func regenerateMessage(for message: ChatMessageModel) {
            guard let server = apiManager.selectedServer else {
                showMissingAPIAlert = true; return
            }
            if server.migrateAPIKeyToKeychainIfNeeded() {
                try? modelContext.save()
            }
            let config = ServerConfig(
                type: server.type,
                baseURL: server.baseURL,
                selectedModel: server.selectedModel,
                apiKey: server.apiKey,
                allowInsecureTLS: server.allowInsecureTLS,
                customCACertificateData: server.customCACertificateData
            )
            guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }

            let replyID = message.id
            let payload = buildPayload(upTo: index, dummyUser: true)

            pruneAssistantVariants(keepingMessageID: replyID)
            messages[index].touchTimestamp()
            messages[index].addNewVariant()
            messages[index].setStreaming(true)
            isThinking = false
            isGenerating = true
            streamingReply = messages[index]

            generationTask = Task {
                await streamReply(payload: payload, config: config, replyID: replyID)
            }
        }

        @MainActor
        func switchVariant(for id: UUID, direction: Int) {
            guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
            messages[index].switchVariant(offset: direction)
            saveChatHistory()
        }

        // MARK: - Streaming helper
        private func streamReply(payload: [ChatPayloadMessage], config: ServerConfig, replyID: UUID) async {
            let clampedChunkFlushIntervalMs = ChatStreamingDefaults.clampedChunkFlushIntervalMs(streamChunkFlushIntervalMs)
            let eventStream = ChatReplyStreamService.makeEventStream(
                payload: payload,
                config: config,
                chunkFlushIntervalMs: clampedChunkFlushIntervalMs
            )
            let cancelEventStream = eventStream.cancel

            await withTaskCancellationHandler {
                for await event in eventStream.stream {
                    if Task.isCancelled { break }

                    await MainActor.run {
                        switch event {
                        case let .chunk(chunk):
                            applyStreamChunk(chunk, for: replyID)
                        case let .failed(message):
                            if let idx = messages.firstIndex(where: { $0.id == replyID }) {
                                let currentVariantIndex = messages[idx].currentIndex
                                messages[idx].appendChunk("⚠️ Error: \(message)", to: currentVariantIndex)
                                messages[idx].setStreaming(false)
                            }
                            isThinking = false
                        case .finished:
                            if let streamingReply, streamingReply.id == replyID {
                                streamingReply.setStreaming(false)
                            } else if let idx = messages.firstIndex(where: { $0.id == replyID }) {
                                messages[idx].setStreaming(false)
                            }
                            isThinking = false
                            isGenerating = false
                            generationTask = nil
                            streamingReply = nil
                            saveChatHistory()
                        }
                    }
                }
            } onCancel: {
                cancelEventStream()
            }
        }

        @MainActor
        private func applyStreamChunk(_ chunk: String, for replyID: UUID) {
            guard !chunk.isEmpty else { return }

            if let streamingReply, streamingReply.id == replyID {
                let variant = streamingReply.currentIndex
                streamingReply.appendChunk(chunk, to: variant)
                let thinkingNow = streamingReply.isThinkingInProgress
                if isThinking != thinkingNow {
                    isThinking = thinkingNow
                }
                return
            }

            guard let idx = messages.firstIndex(where: { $0.id == replyID }) else { return }
            let variant = messages[idx].currentIndex
            messages[idx].appendChunk(chunk, to: variant)
            let thinkingNow = messages[idx].isThinkingInProgress
            if isThinking != thinkingNow {
                isThinking = thinkingNow
            }
        }

        // MARK: - Payload builder
        private func buildPayload(upTo limit: Int? = nil, dummyUser: Bool = false) -> [ChatPayloadMessage] {
            let systemPrompt = currentSystemPrompt
            let greeting = bot.greeting
            let hasGreeting = messages.contains { !$0.isUser && $0.content == greeting }

            var payload: [ChatPayloadMessage] = []

            if !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                payload.append(.init(role: "system", content: systemPrompt))
            }
            if dummyUser { payload.append(.init(role: "user", content: ".")) }
            if !hasGreeting { payload.append(.init(role: "assistant", content: greeting)) }

            let slice: [ChatMessageModel] = {
                if let limit { Array(messages.prefix(upTo: limit)) } else { messages }
            }()
            payload += slice.map { ChatPayloadMessage(role: $0.isUser ? "user" : "assistant", content: $0.content) }

            return payload
        }

        // MARK: - Utils
        @MainActor
        private func pruneAssistantVariants(keepingMessageID: UUID?) {
            for message in messages where !message.isUser && message.id != keepingMessageID {
                message.keepOnlyCurrentVariant()
            }
        }

        private func trimMessagesIfNeeded() {
            if messages.count > maxVisibleMessages {
                messages.removeFirst(messages.count - maxVisibleMessages)
            }
        }
}
