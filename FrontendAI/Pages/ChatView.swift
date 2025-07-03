//
//  ChatView.swift
//  FrontendAI
//
//  Created by macbook on 30.03.2025.
//

import SwiftUI
import SwiftData
import UIKit

struct ChatView: View {
    // MARK: – Входные данные
    let bot: Bot
    let botID: UUID

    // MARK: – Состояния
    @State private var messages: [ChatMessageModel] = []
    @State private var showChatBotSheet = false
    @State private var inputText: String = ""
    @State private var currentHistory: ChatHistory?
    @State private var isViewingHistory: Bool = false
    @State private var isManualHistoryLoad = false
    @State private var streamingReply: ChatMessageModel?
    @State private var isGenerating: Bool = false
    @State private var generationTask: Task<Void, Never>? = nil
    @State private var showCursor: Bool = true
    @State private var alertMessage: String?
    @State private var showAlertBanner: Bool = false
    @State private var showMissingAPIAlert = false
    @State private var openSettings = false

    // MARK: – Env
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var apiManager: APIManager
    @Environment(PersonaManager.self) var personaManager
    @Query private var allBots: [BotModel]
    @State private var savedBotModel: BotModel?
    @AppStorage("showAvatars") private var showAvatars: Bool = true

    // MARK: – Init
    init(bot: Bot) {
        self.bot = bot
        self.botID = bot.id
    }

    // MARK: – Calculated
    var currentSystemPrompt: String {
        let personaPrompt = personaManager.activePersona?.systemPrompt ?? ""
        return [personaPrompt, bot.subtitle].filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    // MARK: – Body
    var body: some View {
        ZStack {
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
                // Header
                ChatHeaderBar(
                    bot: bot,
                    botID: botID,
                    showChatBotSheet: $showChatBotSheet,
                    isViewingHistory: $isViewingHistory,
                    onNewChat: {
                        saveChatHistory()
                        messages = []
                        currentHistory = nil
                        messages.append(ChatMessageModel(content: bot.greeting, isUser: false))
                    }
                )

                // Messages list
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { msg in
                            MessageRow(
                                msg: msg,
                                regenerate: regenerateMessage,
                                switchVariant: switchVariant
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                // Input bar
                ChatInputBar(
                    inputText: $inputText,
                    isGenerating: $isGenerating,
                    placeholder: "Message \(bot.name)",
                    onSend: sendMessage,
                    onStop: stopGeneration
                )
            }
        }
        // Env-proxies
        .environment(\.bot, bot)
        .environment(\.showAvatars, showAvatars)
        .environment(\.personaManager, personaManager)
        .environment(\.isGenerating, isGenerating)
        .environment(\.showCursor, showCursor)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !isManualHistoryLoad { loadHistory() }
        }
        .onDisappear(perform: saveChatHistory)
        .sheet(isPresented: $openSettings) {
            APIManagerView(selectedServer: $apiManager.selectedServer)
                .environmentObject(apiManager)
        }
        .alert("No API server selected", isPresented: $showMissingAPIAlert) {
            Button("Settings") { openSettings = true }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please select or configure an API endpoint to continue.")
        }
        .navigationDestination(isPresented: $isViewingHistory) {
            ChatHistoryListView(botID: botID, botName: bot.name) { selectedHistory in
                loadSelectedHistory(selectedHistory)
            }
        }
    }

    // MARK: – Actions

    /// Завершить стрим и отменить Task.
    private func stopGeneration() {
        generationTask?.cancel()
        isGenerating = false
        generationTask = nil
        if streamingReply != nil {
            streamingReply = nil
            saveChatHistory()
        }
    }

    private func sendMessage() {
        guard let server = apiManager.selectedServer else {
            showMissingAPIAlert = true
            return
        }

        guard !inputText.isEmpty else { return }

        let userMessage = ChatMessageModel(content: inputText, isUser: true)
        withAnimation { messages.append(userMessage) }
        inputText = ""

        let payload = buildPayload(dummyUser: true)
        let replyID = UUID()
        streamingReply = ChatMessageModel(id: replyID, content: "", isUser: false)
        messages.append(streamingReply!)

        startGentleVibration()
        isGenerating = true

        generationTask = Task {
            do {
                _ = try await APIService.sendMessage(
                    messages: payload,
                    server: server,
                    onStream: { chunk in
                        DispatchQueue.main.async {
                            if let index = messages.firstIndex(where: { $0.id == replyID }) {
                                let variant = messages[index].currentIndex
                                messages[index].appendChunk(chunk, to: variant)
                            }
                        }
                    }
                )
                endVibrationEffect()
            } catch {
                print("❌ API Error: \(error.localizedDescription)")
                await MainActor.run {
                    if let index = messages.firstIndex(where: { $0.id == replyID }) {
                        messages[index].appendChunk("⚠️ Error: \(error.localizedDescription)", to: 0)
                    }
                }
            }

            isGenerating = false
            generationTask = nil
            streamingReply = nil
            saveChatHistory()
        }
    }

    private func regenerateMessage(for message: ChatMessageModel) {
        guard let server = apiManager.selectedServer else {
            showMissingAPIAlert = true
            return
        }

        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        let replyID = message.id

        let payload = buildPayload(upTo: index, dummyUser: true)

        messages[index].addNewVariant()
        startGentleVibration()
        isGenerating = true
        streamingReply = messages[index]

        generationTask = Task {
            do {
                _ = try await APIService.sendMessage(
                    messages: payload,
                    server: server,
                    onStream: { chunk in
                        DispatchQueue.main.async {
                            if let idx = messages.firstIndex(where: { $0.id == replyID }) {
                                let variant = messages[idx].currentIndex
                                messages[idx].appendChunk(chunk, to: variant)
                            }
                        }
                    }
                )
                endVibrationEffect()
            } catch {
                print("❌ API Error: \(error.localizedDescription)")
                await MainActor.run {
                    if let idx = messages.firstIndex(where: { $0.id == replyID }) {
                        messages[idx].appendChunk("⚠️ Error: \(error.localizedDescription)", to: 0)
                    }
                }
            }

            isGenerating = false
            generationTask = nil
            streamingReply = nil
            saveChatHistory()
        }
    }

    private func switchVariant(for id: UUID, direction: Int) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].switchVariant(offset: direction)
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

        if dummyUser {
            payload.append(.init(role: "user", content: ""))
        }

        if !hasGreeting {
            payload.append(.init(role: "assistant", content: greeting))
        }

        let slice: [ChatMessageModel] = {
            if let limit = limit {
                return Array(messages.prefix(upTo: limit))
            } else {
                return messages
            }
        }()

        payload += slice.map {
            ChatPayloadMessage(role: $0.isUser ? "user" : "assistant", content: $0.content)
        }

        return payload
    }

    // MARK: – History (load/save)

    private func loadHistory() {
        Task {
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
                        .sorted(by: { $0.index < $1.index })
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

    private func loadSelectedHistory(_ history: ChatHistory) {
        currentHistory = history
        messages = history.messages
            .sorted(by: { $0.index < $1.index })
            .map { ChatMessageModel(content: $0.text, isUser: $0.isUser) }
        isManualHistoryLoad = true
    }

    // MARK: – Alerts

    private func showError(_ message: String) {
        alertMessage = message
        showAlertBanner = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation { showAlertBanner = false }
        }
    }

    // MARK: – Вибрация

    private func startGentleVibration(interval: TimeInterval = 0.1) {
        let feedbackSequence: [UIImpactFeedbackGenerator.FeedbackStyle] = [.heavy, .medium, .light]
        var currentIndex = 0

        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            guard isGenerating else {
                timer.invalidate()
                return
            }

            if currentIndex >= feedbackSequence.count {
                timer.invalidate()
                return
            }

            let generator = UIImpactFeedbackGenerator(style: feedbackSequence[currentIndex])
            generator.prepare()
            generator.impactOccurred()

            currentIndex += 1
        }
    }

    private func endVibrationEffect() {
        let soft = UIImpactFeedbackGenerator(style: .light)
        let strong = UIImpactFeedbackGenerator(style: .medium)

        soft.prepare()
        strong.prepare()

        soft.impactOccurred() // тук
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            strong.impactOccurred() // дук
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

    ChatView(bot: previewBot)
        .environmentObject(APIManager())
        .environment(PersonaManager())
}
