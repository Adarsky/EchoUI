import SwiftUI
import UIKit

extension ChatView {
    var messagesScrollView: some View {
        ChatScreenView(
            model: chatScreenModel,
            bindings: chatScreenBindings,
            actions: chatScreenActions
        )
    }

    private var chatScreenModel: ChatScreenModel {
        ChatScreenModel(
            messages: messages,
            botName: bot.name,
            appearance: activeChatAppearance,
            composer: ChatScreenModel.Composer(
                isGenerating: isGenerating,
                isThinking: isThinking,
                sendButtonStyle: currentInputBarSendButtonStyle,
                placeholder: "Message \(bot.name)"
            )
        )
    }

    private var chatScreenBindings: ChatScreenBindings {
        ChatScreenBindings(
            inputText: $inputText
        )
    }

    private var chatScreenActions: ChatScreenActions {
        ChatScreenActions(
            messages: ChatScreenActions.Messages(
                regenerate: regenerateMessage,
                switchVariant: switchVariant,
                edit: { _ in saveChatHistory() },
                delete: deleteMessage,
                branch: branchChat
            ),
            composer: ChatScreenActions.Composer(
                send: sendMessage,
                stop: stopGeneration
            )
        )
    }

    var navigationHeaderBar: some View {
        ChatHeaderBar(
            bot: bot,
            showCharacterProfile: $showCharacterProfile
        )
        .frame(maxWidth: 280)
    }

    var currentInputBarSendButtonStyle: ChatInputBarSendButtonStyle {
        ChatInputBarSendButtonStyle.value(
            from: UserDefaults.standard.string(forKey: ChatInputBarStorageKeys.sendButtonStyle)
                ?? ChatInputBarSendButtonStyle.defaultValue.rawValue
        )
    }

    func resetInitialMessagePositioning() {
        hasPositionedInitialMessages = false
        isPositioningInitialMessages = false
    }

    @ViewBuilder
    var chatBackground: some View {
        GeometryReader { geo in
            if let chatWallpaperImage {
                Image(uiImage: chatWallpaperImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .blur(radius: clampedChatWallpaperBlurRadius)
                    .clipped()
                    .overlay(
                        Color.black.opacity(activeChatAppearance.clampedWallpaperTintOpacity)
                            .frame(width: geo.size.width, height: geo.size.height)
                    )
            } else {
                Color(.systemBackground)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .ignoresSafeArea()
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .allowsHitTesting(false)
    }

    var clampedChatWallpaperBlurRadius: CGFloat {
        guard activeChatAppearance.wallpaperBlurEnabled else { return 0 }
        return CGFloat(activeChatAppearance.clampedWallpaperBlurRadius)
    }

    @MainActor
    func migrateLegacyWallpaperIfNeeded() {
        ChatAppearanceStore.migrateLegacyWallpaperIfNeeded()
    }

    var currentChatAppearanceID: String? {
        ChatAppearanceStore.chatID(botID: botID, firstMessageID: messages.first?.id)
    }

    var currentChatTokenCount: Int {
        let systemPromptTokens = TokenUsageEstimator.estimatedTokenCount(for: currentSystemPrompt)
        let contextMessages = messages.suffix(maxContextMessages)
        let messageTokens = contextMessages.reduce(0) {
            $0 + TokenUsageEstimator.estimatedTokenCount(for: $1)
        }
        let greetingTokens = shouldInjectGreetingIntoPayload ? TokenUsageEstimator.estimatedTokenCount(for: currentGreeting) : 0

        return systemPromptTokens + greetingTokens + messageTokens
    }

    var currentTokenWindow: Int? {
        guard
            let selectedServer = apiManager.selectedServer,
            selectedServer.type == .openrouter
        else {
            return nil
        }

        let selectedModelID = CharacterGenerationSettings.resolvedModel(
            for: currentBotModel,
            server: selectedServer
        )
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !selectedModelID.isEmpty else { return nil }

        return APIModelCatalogCache
            .cachedOpenRouterModels(for: selectedServer.baseURL)?
            .first { $0.id.lowercased() == selectedModelID }?
            .contextLength
    }

    private var shouldInjectGreetingIntoPayload: Bool {
        !currentGreeting.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !messages.suffix(maxContextMessages).contains {
                !$0.isUser && CharacterTextFormatting.normalized($0.content) == currentGreeting
            }
    }

    @MainActor
    func refreshActiveAppearance() {
        activeChatAppearance = ChatAppearanceStore.resolved(
            botID: botID,
            chatID: currentChatAppearanceID
        )
        refreshWallpaperImage()
    }

    @MainActor
    func refreshWallpaperImage() {
        chatWallpaperImage = ChatWallpaperStore.loadImage(from: activeChatAppearance.wallpaperPath)
    }

    // MARK: - Header helpers
    func startNewChatTapped() {
        if personas.isEmpty {
            performStartNewChat()
            return
        }
        showPersonaPickerForNewChat = true
    }

    func performStartNewChat(persona: PersonaModel? = nil, hasPersonaOverride: Bool = false) {
        if isGenerating {
            stopGeneration()
        }
        guard saveChatHistory() else { return }
        resetInitialMessagePositioning()
        messages.removeAll()
        currentHistory = nil
        chatPersonaID = persona?.id
        self.hasChatPersonaOverride = hasPersonaOverride
        messages.append(ChatMessageModel(content: currentGreeting, isUser: false))
        refreshActiveAppearance()
    }

    @MainActor
    func setActiveChatPersona(_ persona: PersonaModel?) {
        chatPersonaID = persona?.id
        hasChatPersonaOverride = true
        saveChatHistory()
    }

    @MainActor
    func clearChatPersonaOverride() {
        chatPersonaID = nil
        hasChatPersonaOverride = false
        saveChatHistory()
    }

    func deleteMessage(id: UUID) {
        guard !isGenerating else { return }
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }

        messages.remove(at: index)
        saveChatHistory()
    }
}
