//  ChatView.swift
//  FrontendAI
//
//  Rewritten for iOS 17 / Xcode 16.4
//  Оптимизации: 1) reference‑based сообщения, 4) обрезка ленты, 5) сохранение по окончании стрима,
//  6) вибрация через async/await
//

import SwiftUI
import SwiftData
import UIKit

// MARK: – Chat‑message model (ObservableObject вместо struct)
final class ChatMessageModel: ObservableObject, Identifiable {
    private struct ThinkingParserState {
        enum Mode {
            case undecided
            case normal
            case inThinking
            case afterThinking
        }

        private static let openTag = "<think>"
        private static let closeTag = "</think>"

        var mode: Mode = .undecided
        var pending: String = ""
        var displayContent: String = ""
        var thinkingContent: String = ""
        var hasLeadingThink: Bool = false

        mutating func consume(_ chunk: String) {
            guard !chunk.isEmpty else { return }

            switch mode {
            case .undecided:
                pending.append(chunk)
                resolveUndecidedMode()
            case .normal, .afterThinking:
                displayContent.append(chunk)
            case .inThinking:
                consumeThinkingChunk(chunk)
            }
        }

        mutating func resolveUndecidedMode() {
            guard !pending.isEmpty else { return }

            if Self.openTag.hasPrefix(pending), pending.count < Self.openTag.count {
                return
            }

            if pending.hasPrefix(Self.openTag) {
                hasLeadingThink = true
                mode = .inThinking

                let remainder = String(pending.dropFirst(Self.openTag.count))
                pending.removeAll(keepingCapacity: true)

                if !remainder.isEmpty {
                    consumeThinkingChunk(remainder)
                }
                return
            }

            mode = .normal
            displayContent.append(pending)
            pending.removeAll(keepingCapacity: true)
        }

        mutating func consumeThinkingChunk(_ chunk: String) {
            let incoming = pending + chunk
            pending.removeAll(keepingCapacity: true)

            if let closeRange = incoming.range(of: Self.closeTag) {
                thinkingContent.append(contentsOf: incoming[..<closeRange.lowerBound])
                mode = .afterThinking

                let remainder = incoming[closeRange.upperBound...]
                if !remainder.isEmpty {
                    displayContent.append(contentsOf: remainder)
                }
                return
            }

            let overlap = Self.longestClosingTagOverlap(incoming)
            if overlap > 0 {
                let safeEnd = incoming.index(incoming.endIndex, offsetBy: -overlap)
                thinkingContent.append(contentsOf: incoming[..<safeEnd])
                pending = String(incoming[safeEnd...])
            } else {
                thinkingContent.append(incoming)
            }
        }

        static func parsed(from raw: String) -> ThinkingParserState {
            var state = ThinkingParserState()
            state.consume(raw)
            return state
        }

        private static func longestClosingTagOverlap(_ text: String) -> Int {
            let maxLength = min(closeTag.count - 1, text.count)
            guard maxLength > 0 else { return 0 }

            for length in stride(from: maxLength, through: 1, by: -1) {
                let suffix = text.suffix(length)
                if closeTag.hasPrefix(String(suffix)) {
                    return length
                }
            }
            return 0
        }
    }

    private struct VariantStorage {
        var rawContent: String
        var displayContent: String
        var thinkingContent: String
        var hasLeadingThink: Bool
        var parserState: ThinkingParserState
        var thinkingStartedAt: Date?
        var thinkingClosedAt: Date?

        init(rawContent: String) {
            let parsed = ThinkingParserState.parsed(from: rawContent)
            self.rawContent = rawContent
            self.displayContent = parsed.displayContent
            self.thinkingContent = parsed.thinkingContent
            self.hasLeadingThink = parsed.hasLeadingThink
            self.parserState = parsed
            self.thinkingStartedAt = nil
            self.thinkingClosedAt = nil
        }

        mutating func appendChunk(_ chunk: String) {
            let now = Date()

            rawContent.append(chunk)
            parserState.consume(chunk)

            if parserState.hasLeadingThink && thinkingStartedAt == nil {
                thinkingStartedAt = now
            }
            if parserState.mode == .afterThinking && thinkingClosedAt == nil {
                thinkingClosedAt = now
            }

            displayContent = parserState.displayContent
            thinkingContent = parserState.thinkingContent
            hasLeadingThink = parserState.hasLeadingThink
        }

        var thinkingStatusText: String {
            guard hasLeadingThink else { return "thinking" }
            guard let started = thinkingStartedAt, let ended = thinkingClosedAt else { return "thinking" }

            let totalSeconds = max(0, Int(ended.timeIntervalSince(started).rounded(.down)))
            if totalSeconds < 60 {
                return "thought for \(totalSeconds) \(pluralized(totalSeconds, singular: "second"))"
            }

            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            if seconds > 0 {
                return "thought for \(minutes) \(pluralized(minutes, singular: "minute")) and \(seconds) \(pluralized(seconds, singular: "second"))"
            }

            return "thought for \(minutes) \(pluralized(minutes, singular: "minute"))"
        }

        private func pluralized(_ value: Int, singular: String) -> String {
            value == 1 ? singular : "\(singular)s"
        }

        mutating func finalizeThinkingIfNeeded(at date: Date) {
            guard hasLeadingThink else { return }
            guard thinkingClosedAt == nil else { return }
            if thinkingStartedAt == nil {
                thinkingStartedAt = date
            }
            thinkingClosedAt = date
        }

        var isThinkingInProgress: Bool {
            hasLeadingThink && thinkingClosedAt == nil
        }
    }

    let id: UUID
    let isUser: Bool

    @Published private var variants: [VariantStorage]
    @Published var currentIndex: Int = 0

    var content: String {
        guard variants.indices.contains(currentIndex) else { return variants.first?.displayContent ?? "" }
        return variants[currentIndex].displayContent
    }

    var thinkingContent: String {
        guard variants.indices.contains(currentIndex) else { return variants.first?.thinkingContent ?? "" }
        return variants[currentIndex].thinkingContent
    }

    var hasThinkingContent: Bool {
        guard variants.indices.contains(currentIndex) else { return variants.first?.hasLeadingThink ?? false }
        return variants[currentIndex].hasLeadingThink
    }

    var thinkingStatusText: String {
        guard variants.indices.contains(currentIndex) else { return variants.first?.thinkingStatusText ?? "thinking" }
        return variants[currentIndex].thinkingStatusText
    }

    var isThinkingInProgress: Bool {
        guard variants.indices.contains(currentIndex) else { return variants.first?.isThinkingInProgress ?? false }
        return variants[currentIndex].isThinkingInProgress
    }

    var allVariants: [String] { variants.map(\.displayContent) }
    var hasMultipleVariants: Bool { variants.count > 1 }

    init(id: UUID = UUID(), content: String, isUser: Bool) {
        self.id = id
        self.isUser = isUser
        self.variants = [VariantStorage(rawContent: content)]
    }

    @MainActor
    func appendChunk(_ chunk: String, to variant: Int) {
        guard variants.indices.contains(variant) else { return }
        variants[variant].appendChunk(chunk)
    }

    @MainActor
    func addNewVariant() {
        variants.append(VariantStorage(rawContent: ""))
        currentIndex = variants.count - 1
    }

    @MainActor
    func switchVariant(offset: Int) {
        guard !variants.isEmpty else { return }
        currentIndex = (currentIndex + offset + variants.count) % variants.count
    }
    
    @MainActor
    func replaceCurrentVariant(with text: String) {
        guard variants.indices.contains(currentIndex) else { return }
        variants[currentIndex] = VariantStorage(rawContent: text)
    }

    @MainActor
    func finalizeThinkingNow() {
        guard variants.indices.contains(currentIndex) else { return }
        variants[currentIndex].finalizeThinkingIfNeeded(at: Date())
    }

}

// MARK: – Chat view
struct ChatView: View {
    let bot: Bot
    let botID: UUID
    private let isPreviewSeeded: Bool

    private let maxVisibleMessages = 300
    private let topMessagesInset: CGFloat = 100
    private let BottomMessagesInset: CGFloat = 70

    @State private var messages: [ChatMessageModel] = []
    @State private var showChatBotSheet = false
    @State private var inputText: String = ""
    @State private var currentHistory: ChatHistory?
    @State private var isViewingHistory = false
    @State private var isManualHistoryLoad = false
    @State private var streamingReply: ChatMessageModel?
    @State private var isGenerating = false
    @State private var isThinking = false
    @State private var generationTask: Task<Void, Never>? = nil

    @State private var alertMessage: String?
    @State private var showAlertBanner = false
    @State private var showMissingAPIAlert = false
    @State private var openSettings = false
    @State private var didApplyInitialScrollPosition = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var apiManager: APIManager
    @Environment(PersonaManager.self) private var personaManager
    @Query private var allBots: [BotModel]
    @State private var savedBotModel: BotModel?
    @AppStorage(ChatAppearanceStorageKeys.wallpaperPath) private var chatWallpaperPath = ""
    @AppStorage(ChatAppearanceStorageKeys.wallpaperBase64) private var legacyChatWallpaperBase64 = ""
    @State private var chatWallpaperImage: UIImage?

    init(bot: Bot) {
        self.bot = bot
        self.botID = bot.id
        self.isPreviewSeeded = false
    }

    init(bot: Bot, previewMessages: [ChatMessageModel]) {
        self.bot = bot
        self.botID = bot.id
        self.isPreviewSeeded = true
        self._messages = State(initialValue: previewMessages)
    }

    var currentSystemPrompt: String {
        let personaPrompt = personaManager.activePersona?.systemPrompt ?? ""
        return [personaPrompt, bot.subtitle].filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    var body: some View {
        ZStack {
            chatBackground

            if showAlertBanner, let alertMessage {
                VStack {
                    Text(alertMessage)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.9))
                        .cornerRadius(12)
                        .padding(.top, 8)
                        .padding(.horizontal)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: showAlertBanner)
            }
            VStack(spacing: 0) {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { msg in
                                MessageRow(
                                    msg: msg,
                                    regenerate: regenerateMessage,
                                    switchVariant: switchVariant,
                                    onDelete: { id in
                                        if let i = messages.firstIndex(where: { $0.id == id }) {
                                            messages.remove(at: i)
                                            saveChatHistory()
                                        }
                                    }
                                )
                                .id(msg.id)
                            }
                        }
                        .padding(.top, topMessagesInset)
                        .padding(.bottom, BottomMessagesInset)
                        .padding(.horizontal, 15)
                        .padding(.bottom, 15)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onAppear {
                        scrollToLatestMessageIfNeeded(using: scrollProxy)
                    }
                    .onChange(of: messages.count) { _, _ in
                        scrollToLatestMessageIfNeeded(using: scrollProxy)
                    }
                }

                // Input bar
            }
            VStack {
                    ZStack {
                        ChatHeaderBar(
                            bot: bot,
                            botID: botID,
                            showChatBotSheet: $showChatBotSheet,
                            isViewingHistory: $isViewingHistory,
                            onNewChat: startNewChat
                        )
                        .background(alignment: .top) {
                            GeometryReader { geo in
                                Rectangle()
                                    .fill(.ultraThickMaterial)
                                    .frame(height: geo.safeAreaInsets.top + 70)
                                    .mask(
                                        LinearGradient(
                                            gradient: Gradient(stops: [
                                                .init(color: .black, location: 0),
                                                .init(color: .clear, location: 1)
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .ignoresSafeArea(edges: .top)
                            }
                        }
                    }
                Spacer()
                ZStack {
                    ChatInputBar(
                        inputText: $inputText,
                        isGenerating: $isGenerating,
                        isThinking: $isThinking,
                        placeholder: "Message \(bot.name)",
                        onSend: sendMessage,
                        onStop: stopGeneration
                    )
                }
            }
            
        }
        .environment(\.bot, bot)
        .environment(\.personaManager, personaManager)
        .environment(\.isGenerating, isGenerating)
        .environment(\.showCursor, true)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            migrateLegacyWallpaperIfNeeded()
            refreshWallpaperImage()
            if !isManualHistoryLoad && !isPreviewSeeded {
                loadHistory()
            }
        }
        .onChange(of: chatWallpaperPath) { _, _ in
            refreshWallpaperImage()
        }
        .onDisappear { saveChatHistory() }
        .sheet(isPresented: $openSettings) {
            APIManagerView(selectedServer: $apiManager.selectedServer)
                .environmentObject(apiManager)
        }
        .alert("No API server selected", isPresented: $showMissingAPIAlert) {
            Button("Settings") { openSettings = true }
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please select or configure an API endpoint to continue.")
        }
        .navigationDestination(isPresented: $isViewingHistory) {
            ChatHistoryListView(botID: botID, botName: bot.name) { loadSelectedHistory($0) }
        }
    }

    @ViewBuilder
    private var chatBackground: some View {
        GeometryReader { geo in
            if let chatWallpaperImage {
                Image(uiImage: chatWallpaperImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .overlay(
                        Color.black.opacity(0.14)
                            .frame(width: geo.size.width, height: geo.size.height)
                    )
            } else {
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.systemGroupedBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .ignoresSafeArea()
    }

    @MainActor
    private func migrateLegacyWallpaperIfNeeded() {
        ChatWallpaperStore.migrateLegacyBase64IfNeeded(
            path: &chatWallpaperPath,
            legacyBase64: &legacyChatWallpaperBase64
        )
    }

    @MainActor
    private func refreshWallpaperImage() {
        chatWallpaperImage = ChatWallpaperStore.loadImage(from: chatWallpaperPath)
    }

    // MARK: – Header helpers
    private func startNewChat() {
        saveChatHistory()
        messages.removeAll()
        currentHistory = nil
        messages.append(ChatMessageModel(content: bot.greeting, isUser: false))
    }

    // MARK: – Generation flow
    private func stopGeneration() {
        generationTask?.cancel()
        streamingReply?.finalizeThinkingNow()
        isThinking = false
        isGenerating = false
        generationTask = nil
        streamingReply = nil
        saveChatHistory()
    }

    private func sendMessage() {
        guard let server = apiManager.selectedServer else {
            showMissingAPIAlert = true; return
        }
        guard !inputText.isEmpty else { return }
        let config = ServerConfig(
            type: server.type,
            baseURL: server.baseURL,
            selectedModel: server.selectedModel,
            apiKey: server.apiKey
        )

        // 1. append user message
        let userMessage = ChatMessageModel(content: inputText, isUser: true)
        withTransaction(.init(animation: nil)) { messages.append(userMessage) }
        trimMessagesIfNeeded()
        inputText = ""

        // 2. prepare payload & placeholder
        let payload = buildPayload(dummyUser: true)
        let replyID = UUID()
        let placeholder = ChatMessageModel(id: replyID, content: "", isUser: false)
        messages.append(placeholder)
        streamingReply = placeholder
        isThinking = false
        isGenerating = true

        // 3. async request
        generationTask = Task {
            await streamReply(payload: payload, config: config, replyID: replyID)
        }
    }

    @MainActor
    private func regenerateMessage(for message: ChatMessageModel) {
        guard let server = apiManager.selectedServer else {
            showMissingAPIAlert = true; return
        }
        let config = ServerConfig(
            type: server.type,
            baseURL: server.baseURL,
            selectedModel: server.selectedModel,
            apiKey: server.apiKey
        )
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }

        let replyID = message.id
        let payload = buildPayload(upTo: index, dummyUser: true)

        messages[index].addNewVariant()
        isThinking = false
        isGenerating = true
        streamingReply = messages[index]

        generationTask = Task {
            await streamReply(payload: payload, config: config, replyID: replyID)
        }
    }

    @MainActor
    private func switchVariant(for id: UUID, direction: Int) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].switchVariant(offset: direction)
    }

    // MARK: – Streaming helper
    private func streamReply(payload: [ChatPayloadMessage], config: ServerConfig, replyID: UUID) async {
        do {
            _ = try await APIService.sendMessage(
                messages: payload,
                config: config,
                onStream: { chunk in
                    Task { @MainActor in
                        if let idx = messages.firstIndex(where: { $0.id == replyID }) {
                            let variant = messages[idx].currentIndex
                            messages[idx].appendChunk(chunk, to: variant)
                            isThinking = messages[idx].isThinkingInProgress
                        }
                    }
                }
            )
        } catch {
            print("❌ API Error: \(error.localizedDescription)")
            await MainActor.run {
                if let idx = messages.firstIndex(where: { $0.id == replyID }) {
                    messages[idx].appendChunk("⚠️ Error: \(error.localizedDescription)", to: 0)
                }
                isThinking = false
            }
        }

        // end‑of‑stream
        await MainActor.run {
            isThinking = false
            isGenerating = false
            generationTask = nil
            streamingReply = nil
            saveChatHistory()
        }
    }

    // MARK: – Payload builder
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

    // MARK: – History (load/save)
    private func loadHistory() {
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
                        .map { ChatMessageModel(content: $0.text, isUser: $0.isUser) }
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
    private func saveChatHistory() {
        guard !messages.isEmpty else { return }

        let entities = messages.enumerated().map { index, msg in
            ChatMessageEntity(text: msg.content, isUser: msg.isUser, index: index)
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
    private func loadSelectedHistory(_ history: ChatHistory) {
        didApplyInitialScrollPosition = false
        currentHistory = history
        messages = history.messages
            .sorted { $0.index < $1.index }
            .map { ChatMessageModel(content: $0.text, isUser: $0.isUser) }
        isManualHistoryLoad = true
    }

    // MARK: – Alert helper
    @MainActor
    private func showError(_ message: String) {
        alertMessage = message
        showAlertBanner = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation { showAlertBanner = false }
        }
    }

    // MARK: – Utils
    private func trimMessagesIfNeeded() {
        if messages.count > maxVisibleMessages {
            messages.removeFirst(messages.count - maxVisibleMessages)
        }
    }

    @MainActor
    private func scrollToLatestMessageIfNeeded(using proxy: ScrollViewProxy) {
        guard !didApplyInitialScrollPosition else { return }
        guard let latestMessageID = messages.last?.id else { return }

        DispatchQueue.main.async {
            proxy.scrollTo(latestMessageID, anchor: .bottom)
            didApplyInitialScrollPosition = true
        }
    }
}

// MARK: – Preview
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
