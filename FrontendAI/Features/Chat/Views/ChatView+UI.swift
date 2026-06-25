import SwiftUI
import UIKit

extension ChatView {
    var messagesScrollView: some View {
        ChatScreenControllerRepresentable(
            model: chatScreenModel,
            bindings: chatScreenBindings,
            actions: chatScreenActions
        )
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var chatScreenModel: ChatScreenModel {
        ChatScreenModel(
            messages: messages,
            appearance: activeChatAppearance,
            header: ChatScreenModel.Header(
                bot: bot,
                botID: botID,
                chatAppearanceID: currentChatAppearanceID,
                currentChatTokenCount: currentChatTokenCount,
                tokenWindow: currentTokenWindow,
                personas: personas,
                currentPersona: currentPersona,
                globalPersona: personaManager.activePersona,
                hasPersonaOverride: hasChatPersonaOverride,
                apiManager: apiManager
            ),
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
            inputText: $inputText,
            showChatBotSheet: $showChatBotSheet,
            isViewingHistory: $isViewingHistory
        )
    }

    private var chatScreenActions: ChatScreenActions {
        ChatScreenActions(
            navigation: ChatScreenActions.Navigation(
                dismiss: { dismiss() }
            ),
            header: ChatScreenActions.Header(
                startNewChat: startNewChatTapped,
                selectPersona: setActiveChatPersona,
                useGlobalPersona: clearChatPersonaOverride
            ),
            messages: ChatScreenActions.Messages(
                regenerate: regenerateMessage,
                switchVariant: switchVariant,
                delete: deleteMessage
            ),
            composer: ChatScreenActions.Composer(
                send: sendMessage,
                stop: stopGeneration
            )
        )
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
        let messageTokens = messages.reduce(0) { $0 + TokenUsageEstimator.estimatedTokenCount(for: $1) }
        let greetingTokens = shouldInjectGreetingIntoPayload ? TokenUsageEstimator.estimatedTokenCount(for: bot.greeting) : 0

        return systemPromptTokens + greetingTokens + messageTokens
    }

    var currentTokenWindow: Int? {
        guard
            let selectedServer = apiManager.selectedServer,
            selectedServer.type == .openrouter
        else {
            return nil
        }

        let selectedModelID = selectedServer.selectedModel
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !selectedModelID.isEmpty else { return nil }

        return APIModelCatalogCache
            .cachedOpenRouterModels(for: selectedServer.baseURL)?
            .first { $0.id.lowercased() == selectedModelID }?
            .contextLength
    }

    private var shouldInjectGreetingIntoPayload: Bool {
        !bot.greeting.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !messages.contains { !$0.isUser && $0.content == bot.greeting }
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
        saveChatHistory()
        resetInitialMessagePositioning()
        messages.removeAll()
        currentHistory = nil
        chatPersonaID = persona?.id
        self.hasChatPersonaOverride = hasPersonaOverride
        messages.append(ChatMessageModel(content: bot.greeting, isUser: false))
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
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }

        messages.remove(at: index)
        saveChatHistory()
    }
}

#Preview {
    let previewBot = Bot(
        id: UUID(),
        name: "PreviewBot",
        avatarSystemName: "brain.head.profile",
        iconColor: .blue,
        subtitle: "Helpful assistant",
        date: "24.09.2020",
        isPinned: false,
        greeting: "Hello, how can I help you today?",
        avatarData: nil
    )
    let previewMessages: [ChatMessageModel] = [
        ChatMessageModel(content: "Hey, can you help me plan my week?", isUser: true),
        ChatMessageModel(content: "Absolutely. What are your top 3 priorities this week?", isUser: false),
        ChatMessageModel(content: "Ship onboarding UI, clean up tech debt, and prepare demo notes.", isUser: true),
        ChatMessageModel(content: "Great set. Want a day-by-day schedule or a priority matrix first?", isUser: false),
        ChatMessageModel(content: "Day-by-day please.", isUser: true),
        ChatMessageModel(content: "Monday: scope + blockers. Tuesday: core UI. Wednesday: polish and tests.", isUser: false),
        ChatMessageModel(content: "Continue.", isUser: true),
        ChatMessageModel(content: "Thursday: bugfix and edge cases. Friday: demo run-through and release prep.", isUser: false),
        ChatMessageModel(content: "Can you add buffer time?", isUser: true),
        ChatMessageModel(content: "Yes. Add two 45-minute buffers on Tue and Thu for unexpected issues.", isUser: false),
        ChatMessageModel(content: "Also remind me to write release notes.", isUser: true),
        ChatMessageModel(content: "Added: Friday 10:00 AM release notes draft, 2:00 PM final pass.", isUser: false),
        ChatMessageModel(content: "What should I cut if I slip a day?", isUser: true),
        ChatMessageModel(content: "Cut non-critical animations first, then defer low-risk refactors.", isUser: false),
        ChatMessageModel(content: "Give me a quick standup format.", isUser: true),
        ChatMessageModel(content: "Yesterday, Today, Blockers, Risks. Keep each section to one sentence.", isUser: false),
        ChatMessageModel(content: "Nice. Can you summarize all this in 5 bullets?", isUser: true),
        ChatMessageModel(content: "1) Focus on onboarding UI.\n2) Timebox tech debt.\n3) Add buffer slots.\n4) Prepare demo early.\n5) Ship with clear release notes.", isUser: false),
        ChatMessageModel(content: "Looks good. Add a motivational line.", isUser: true),
        ChatMessageModel(content: "Progress beats perfection. Ship small, improve fast.", isUser: false),
        ChatMessageModel(content: "Thanks!", isUser: true),
        ChatMessageModel(content: "Anytime. I can also generate a checklist if you want.", isUser: false)
    ]

    ChatView(bot: previewBot, previewMessages: previewMessages)
        .environmentObject(APIManager())
        .environment(PersonaManager())
}
