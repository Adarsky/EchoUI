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
    let id: UUID
    let isUser: Bool

    @Published private(set) var variants: [String]
    @Published var currentIndex: Int = 0

    var content: String {
        guard variants.indices.contains(currentIndex) else { return variants.first ?? "" }
        return variants[currentIndex]
    }

    var allVariants: [String] { variants }
    var hasMultipleVariants: Bool { variants.count > 1 }

    init(id: UUID = UUID(), content: String, isUser: Bool) {
        self.id = id
        self.isUser = isUser
        self.variants = [content]
    }

    @MainActor
    func appendChunk(_ chunk: String, to variant: Int) {
        guard variants.indices.contains(variant) else { return }
        variants[variant].append(contentsOf: chunk)
    }

    @MainActor
    func addNewVariant() {
        variants.append("")
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
        variants[currentIndex] = text
    }

}

// MARK: – Chat view
struct ChatView: View {
    let bot: Bot
    let botID: UUID

    private let maxVisibleMessages = 300

    @State private var messages: [ChatMessageModel] = []
    @State private var showChatBotSheet = false
    @State private var inputText: String = ""
    @State private var currentHistory: ChatHistory?
    @State private var isViewingHistory = false
    @State private var isManualHistoryLoad = false
    @State private var streamingReply: ChatMessageModel?
    @State private var isGenerating = false
    @State private var generationTask: Task<Void, Never>? = nil

    @State private var alertMessage: String?
    @State private var showAlertBanner = false
    @State private var showMissingAPIAlert = false
    @State private var openSettings = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var apiManager: APIManager
    @Environment(PersonaManager.self) private var personaManager
    @Query private var allBots: [BotModel]
    @State private var savedBotModel: BotModel?
    @AppStorage("showAvatars") private var showAvatars = true

    init(bot: Bot) {
        self.bot = bot
        self.botID = bot.id
    }

    var currentSystemPrompt: String {
        let personaPrompt = personaManager.activePersona?.systemPrompt ?? ""
        return [personaPrompt, bot.subtitle].filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

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
                ChatHeaderBar(
                    bot: bot,
                    botID: botID,
                    showChatBotSheet: $showChatBotSheet,
                    isViewingHistory: $isViewingHistory,
                    onNewChat: startNewChat
                )
                List {
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
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 12, trailing: 0))
                    }
                }
                .listStyle(.plain)
                .scrollDismissesKeyboard(.interactively)
                .padding(15)

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
        .environment(\.bot, bot)
        .environment(\.showAvatars, showAvatars)
        .environment(\.personaManager, personaManager)
        .environment(\.isGenerating, isGenerating)
        .environment(\.showCursor, true)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if !isManualHistoryLoad { loadHistory() } }
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
        isGenerating = true

        // 3. async request
        generationTask = Task {
            await streamReply(payload: payload, server: server, replyID: replyID)
        }
    }

    @MainActor
    private func regenerateMessage(for message: ChatMessageModel) {
        guard let server = apiManager.selectedServer else {
            showMissingAPIAlert = true; return
        }
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }

        let replyID = message.id
        let payload = buildPayload(upTo: index, dummyUser: true)

        messages[index].addNewVariant()
        isGenerating = true
        streamingReply = messages[index]

        generationTask = Task {
            await streamReply(payload: payload, server: server, replyID: replyID)
        }
    }

    @MainActor
    private func switchVariant(for id: UUID, direction: Int) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].switchVariant(offset: direction)
    }

    // MARK: – Streaming helper
    private func streamReply(payload: [ChatPayloadMessage], server: APIServer, replyID: UUID) async {
        do {
            _ = try await APIService.sendMessage(
                messages: payload,
                server: server,
                onStream: { chunk in
                    Task { @MainActor in
                        if let idx = messages.firstIndex(where: { $0.id == replyID }) {
                            let variant = messages[idx].currentIndex
                            messages[idx].appendChunk(chunk, to: variant)
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
            }
        }

        // end‑of‑stream
        await MainActor.run {
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
