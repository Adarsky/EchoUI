import SwiftUI
import Foundation

extension ChatView {
        // MARK: - Generation flow
        func stopGeneration() {
            generationTask?.cancel()
            activeGenerationID = nil
            streamingReply?.finalizeThinkingNow()
            streamingReply?.setStreaming(false)
            if let streamingReply,
               streamingReply.content.isEmpty,
               !streamingReply.hasThinkingContent {
                if !streamingReply.discardEmptyCurrentVariant() {
                    messages.removeAll { $0.id == streamingReply.id }
                }
            }
            isThinking = false
            isGenerating = false
            generationTask = nil
            streamingReply = nil
            saveChatHistory()
        }

        func sendMessage() {
            guard generationTask == nil, !isGenerating else { return }
            guard let server = apiManager.selectedServer else {
                showMissingAPIAlert = true; return
            }
            if server.migrateAPIKeyToKeychainIfNeeded() {
                try? modelContext.save()
            }
            guard !inputText.isEmpty else { return }
            let submittedText = inputText
            let config = ServerConfig(
                type: server.type,
                baseURL: server.baseURL,
                selectedModel: CharacterGenerationSettings.resolvedModel(
                    for: currentBotModel,
                    server: server
                ),
                apiKey: server.apiKey,
                allowInsecureTLS: server.allowInsecureTLS,
                customCACertificateData: server.customCACertificateData,
                thinkingEffort: CharacterGenerationSettings.resolvedThinkingEffort(
                    for: currentBotModel,
                    botID: botID,
                    server: server
                )
            )

            let userMessage = ChatMessageModel(content: submittedText, isUser: true)
            withTransaction(.init(animation: nil)) { messages.append(userMessage) }
            inputText = ""
            clearSavedDraft()

            let payload = buildPayload(dummyUser: true)
            let replyID = UUID()
            let placeholder = ChatMessageModel(id: replyID, content: "", isUser: false)
            placeholder.setStreaming(true)
            messages.append(placeholder)
            streamingReply = placeholder
            isThinking = false
            isGenerating = true
            let generationID = UUID()
            activeGenerationID = generationID

            generationTask = Task {
                await streamReply(
                    payload: payload,
                    config: config,
                    replyID: replyID,
                    generationID: generationID
                )
            }
        }

        @MainActor
        func regenerateMessage(for message: ChatMessageModel) {
            guard generationTask == nil, !isGenerating else { return }
            guard let server = apiManager.selectedServer else {
                showMissingAPIAlert = true; return
            }
            if server.migrateAPIKeyToKeychainIfNeeded() {
                try? modelContext.save()
            }
            let config = ServerConfig(
                type: server.type,
                baseURL: server.baseURL,
                selectedModel: CharacterGenerationSettings.resolvedModel(
                    for: currentBotModel,
                    server: server
                ),
                apiKey: server.apiKey,
                allowInsecureTLS: server.allowInsecureTLS,
                customCACertificateData: server.customCACertificateData,
                thinkingEffort: CharacterGenerationSettings.resolvedThinkingEffort(
                    for: currentBotModel,
                    botID: botID,
                    server: server
                )
            )
            guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }

            let replyID = message.id
            let payload = buildPayload(upTo: index, dummyUser: true)

            messages[index].touchTimestamp()
            messages[index].addNewVariant()
            messages[index].setStreaming(true)
            isThinking = false
            isGenerating = true
            streamingReply = messages[index]
            let generationID = UUID()
            activeGenerationID = generationID

            generationTask = Task {
                await streamReply(
                    payload: payload,
                    config: config,
                    replyID: replyID,
                    generationID: generationID
                )
            }
        }

        @MainActor
        func switchVariant(for id: UUID, direction: Int) {
            guard !isGenerating else { return }
            guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
            messages[index].switchVariant(offset: direction)
            saveChatHistory()
        }

        // MARK: - Streaming helper
        private func streamReply(
            payload: [ChatPayloadMessage],
            config: ServerConfig,
            replyID: UUID,
            generationID: UUID
        ) async {
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

                    let shouldFinish = await MainActor.run {
                        handleStreamEvent(
                            event,
                            replyID: replyID,
                            generationID: generationID
                        )
                    }
                    if shouldFinish {
                        let reachedTerminalEvent: Bool
                        switch event {
                        case .failed, .finished:
                            reachedTerminalEvent = true
                        case .chunk:
                            reachedTerminalEvent = false
                        }

                        await MainActor.run {
                            finishGenerationIfActive(
                                replyID: replyID,
                                generationID: generationID,
                                reachedTerminalEvent: reachedTerminalEvent
                            )
                        }
                        return
                    }
                }

                await MainActor.run {
                    finishGenerationIfActive(
                        replyID: replyID,
                        generationID: generationID,
                        reachedTerminalEvent: false
                    )
                }
            } onCancel: {
                cancelEventStream()
            }
        }

        @MainActor
        private func handleStreamEvent(
            _ event: ChatReplyStreamEvent,
            replyID: UUID,
            generationID: UUID
        ) -> Bool {
            guard activeGenerationID == generationID else { return true }

            switch event {
            case let .chunk(chunk):
                applyStreamChunk(chunk, for: replyID)
                return false
            case let .failed(failure):
                if let index = messages.firstIndex(where: { $0.id == replyID }) {
                    messages[index].setFailure(failure)
                }
                isThinking = false
                return true
            case .finished:
                return true
            }
        }

        @MainActor
        private func finishGenerationIfActive(
            replyID: UUID,
            generationID: UUID,
            reachedTerminalEvent: Bool
        ) {
            guard activeGenerationID == generationID else { return }

            let reply = if let streamingReply, streamingReply.id == replyID {
                streamingReply
            } else {
                messages.first(where: { $0.id == replyID })
            }

            if let reply {
                reply.finalizeThinkingNow()

                if !reachedTerminalEvent, reply.failure == nil {
                    reply.setFailure(
                        ChatReplyFailure(
                            kind: .connectionInterrupted,
                            message: "The reply stream ended unexpectedly. Try again."
                        )
                    )
                } else if reply.failure == nil,
                          reply.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    reply.setFailure(
                        ChatReplyFailure(
                            kind: .unknown,
                            message: "The server finished without returning a reply. Try again."
                        )
                    )
                } else {
                    reply.setStreaming(false)
                }
            }

            isThinking = false
            isGenerating = false
            activeGenerationID = nil
            generationTask = nil
            streamingReply = nil
            saveChatHistory()
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
            let greeting = currentGreeting
            let messagesBeforeReply: ArraySlice<ChatMessageModel>
            if let limit {
                messagesBeforeReply = messages.prefix(upTo: limit)
            } else {
                messagesBeforeReply = messages[...]
            }
            let contextMessages = messagesBeforeReply.suffix(maxContextMessages)
            let hasGreeting = contextMessages.contains {
                !$0.isUser && CharacterTextFormatting.normalized($0.content) == greeting
            }

            var payload: [ChatPayloadMessage] = []

            if !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                payload.append(.init(role: "system", content: systemPrompt))
            }
            if dummyUser { payload.append(.init(role: "user", content: ".")) }
            if !greeting.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !hasGreeting {
                payload.append(.init(role: "assistant", content: greeting))
            }

            payload += contextMessages.compactMap { message in
                guard let content = message.contentForConversation else { return nil }
                return ChatPayloadMessage(
                    role: message.isUser ? "user" : "assistant",
                    content: content
                )
            }

            return payload
        }
}
