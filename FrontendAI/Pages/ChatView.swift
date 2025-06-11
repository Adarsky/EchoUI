import SwiftUI
import SwiftData
import UIKit

struct ChatView: View {
    let bot: Bot
    let botID: UUID
    
    struct ChatMessage: Identifiable {
        let id: UUID
        var allVariants: [String]
        let isUser: Bool
        var currentIndex: Int = 0
        
        var content: String {
            allVariants[safe: currentIndex] ?? ""
        }
        
        init(id: UUID = UUID(), content: String, isUser: Bool) {
            self.id = id
            self.allVariants = [content]
            self.isUser = isUser
        }
    }
    
    @State private var messages: [ChatMessage] = []
    @State private var showChatBotSheet = false
    @State private var inputText: String = ""
    @State private var currentHistory: ChatHistory?
    @State private var isViewingHistory: Bool = false
    @State private var showAPIMissingAlert = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var apiManager: APIManager
    @Environment(PersonaManager.self) var personaManager
    @Query private var allBots: [BotModel]
    @State private var savedBotModel: BotModel?
    @AppStorage("showAvatars") private var showAvatars: Bool = true
    @State private var isManualHistoryLoad = false
    @State private var streamingReply: ChatMessage?
    @State private var isGenerating: Bool = false
    @State private var generationTask: Task<Void, Never>? = nil
    @State private var showCursor: Bool = true
    @State private var alertMessage: String?
    @State private var showAlertBanner: Bool = false
    @State private var inputTextHeight: CGFloat = 40
    @FocusState private var isTextFieldFocused: Bool
    @State private var showMissingAPIAlert = false
    @State private var openSettings = false

    
    
    
    var currentSystemPrompt: String {
        let personaPrompt = personaManager.activePersona?.systemPrompt ?? ""
        return [personaPrompt, bot.subtitle].filter { !$0.isEmpty }.joined(separator: "\n\n")
    }
    
    init(bot: Bot) {
        self.bot = bot
        self.botID = bot.id
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
                headerBar
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { msg in
                            MessageRow(
                                msg: msg,
                                messages: $messages,
                                regenerate: regenerateMessage,
                                switchVariant: switchVariant
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                inputBar
            }
        }
        .environment(\.bot, bot)
        .environment(\.showAvatars, showAvatars)
        .environment(\.personaManager, personaManager)
        .environment(\.streamingReply, streamingReply)
        .environment(\.isGenerating, isGenerating)
        .environment(\.showCursor, showCursor)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !isManualHistoryLoad {
                loadHistory()
            }
        }
        .onDisappear(perform: saveChatHistory)
        .sheet(isPresented: $openSettings) {
            APIManagerView(selectedServer: $apiManager.selectedServer)
                .environmentObject(apiManager)
        }
        .alert("No API server selected", isPresented: $showMissingAPIAlert) {
            Button("Settings") {
                openSettings = true
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please select or configure an API endpoint to continue.")
        }
    }
    
    
    var headerBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.headline)
            }
            Spacer()
            HStack(spacing: 8) {
                if let data = bot.avatarData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                } else {
                    Image(systemName: bot.avatarSystemName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .foregroundColor(bot.iconColor)
                }
                Text(bot.name)
                    .font(.headline)
            }
            Spacer()
            Button {
                showChatBotSheet = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
            }
            .sheet(isPresented: $showChatBotSheet) {
                ChatBotSheetView(
                    bot: bot,
                    onNewChat: {
                        saveChatHistory()
                        messages = []
                        currentHistory = nil
                        messages.append(ChatMessage(content: bot.greeting, isUser: false))
                        showChatBotSheet = false
                    },
                    onViewHistory: {
                        showChatBotSheet = false
                        isViewingHistory = true
                    }
                )
            }
            .navigationDestination(isPresented: $isViewingHistory) {
                ChatHistoryListView(botID: botID, botName: bot.name) { selectedHistory in
                    loadSelectedHistory(selectedHistory)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.15))
    }
    
    var inputBar: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.gray.opacity(0.10))
                .frame(height: 64)
                .overlay(
                    HStack {
                        TextField("Message \(bot.name)", text: $inputText, axis: .vertical)
                            .focused($isTextFieldFocused)
                            .foregroundColor(.primary)
                            .padding(12)

                        Spacer()

                        if isGenerating {
                            Button {
                                generationTask?.cancel()
                                isGenerating = false
                                generationTask = nil
                                if let id = streamingReply?.id,
                                   let _ = messages.firstIndex(where: { $0.id == id }) {
                                    streamingReply = nil
                                    saveChatHistory()
                                }
                            } label: {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.red)
                                    .padding(.trailing, 12)
                            }
                        } else {
                            Button {
                                if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    sendMessage()
                                }
                            } label: {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.blue)
                                    .padding(.trailing, 12)
                            }
                        }
                    }
                )
                .padding(.horizontal)
                .padding(.bottom, 10)
        }
    }




    private func sendMessage() {
        
        guard let server = apiManager.selectedServer else {
            showMissingAPIAlert = true
            return
        }

        guard !inputText.isEmpty else { return }

        let userMessage = ChatMessage(content: inputText, isUser: true)
        withAnimation { messages.append(userMessage) }
        inputText = ""

        let systemPrompt = currentSystemPrompt
        let greeting = bot.greeting
        let dummyUser = ChatPayloadMessage(role: "user", content: "")
        let historyPayload: [ChatPayloadMessage] = messages.map {
            ChatPayloadMessage(role: $0.isUser ? "user" : "assistant", content: $0.content)
        }

        let hasGreeting = messages.contains(where: { !$0.isUser && $0.allVariants.contains(greeting) })

        var payload: [ChatPayloadMessage] = []
        if !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload.append(.init(role: "system", content: systemPrompt))
        }
        payload.append(dummyUser)
        if !hasGreeting {
            payload.append(.init(role: "assistant", content: greeting))
        }
        payload += historyPayload

        print("📤 Payload being sent to API:")
        for msg in payload {
            print("[\(msg.role)] \(msg.content)")
        }

        let replyID = UUID()
        let streamBuffer = ActorIsolated("")
        streamingReply = ChatMessage(id: replyID, content: "", isUser: false)
        messages.append(streamingReply!)
        
        startGentleVibration()
        isGenerating = true
        startGentleVibration()

        generationTask = Task {
            do {
                _ = try await APIService.sendMessage(
                    messages: payload,
                    server: server,
                    onStream: { chunk in
                        DispatchQueue.main.async {
                            if let index = messages.firstIndex(where: { $0.id == replyID }) {
                                let variant = messages[index].currentIndex
                                messages[index].allVariants[variant] += chunk
                            }
                        }
                    }
                )
                endVibrationEffect()
            } catch {
                print("❌ API Error: \(error.localizedDescription)")
                await MainActor.run {
                    if let index = messages.firstIndex(where: { $0.id == replyID }) {
                        messages[index].allVariants[0] = "⚠️ Error: \(error.localizedDescription)"
                    }
                }
            }

            isGenerating = false
            generationTask = nil
            streamingReply = nil
            saveChatHistory()
        }
    }



    private func regenerateMessage(for message: ChatMessage) {
        
        guard let server = apiManager.selectedServer else {
            showMissingAPIAlert = true
            return
        }

        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        
        let replyID = message.id

        let systemPrompt = currentSystemPrompt
        let greeting = bot.greeting
        let dummyUser = ChatPayloadMessage(role: "user", content: "")
        let historyBefore = messages.prefix(upTo: index)

        let hasGreeting = messages.contains { !$0.isUser && $0.content == greeting }

        var payload: [ChatPayloadMessage] = []
        if !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload.append(.init(role: "system", content: systemPrompt))
        }
        payload.append(dummyUser)
        if !hasGreeting {
            payload.append(.init(role: "assistant", content: greeting))
        }
        payload += historyBefore.map {
            ChatPayloadMessage(role: $0.isUser ? "user" : "assistant", content: $0.content)
        }

        messages[index].allVariants.append("")
        messages[index].currentIndex = messages[index].allVariants.count - 1
        
        startGentleVibration()
        isGenerating = true
        streamingReply = messages[index]

        let streamBuffer = ActorIsolated("")

        generationTask = Task {
            do {
                _ = try await APIService.sendMessage(
                    messages: payload,
                    server: server,
                    onStream: { chunk in
                        DispatchQueue.main.async {
                            if let index = messages.firstIndex(where: { $0.id == replyID }) {
                                let variant = messages[index].currentIndex
                                messages[index].allVariants[variant] += chunk
                            }
                        }
                    }
                )
                endVibrationEffect()
            } catch {
                print("❌ API Error: \(error.localizedDescription)")
                await MainActor.run {
                    if let index = messages.firstIndex(where: { $0.id == replyID }) {
                        messages[index].allVariants[0] = "⚠️ Error: \(error.localizedDescription)"
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
        let count = messages[index].allVariants.count
        var newIndex = messages[index].currentIndex + direction
        newIndex = max(0, min(count - 1, newIndex))
        messages[index].currentIndex = newIndex
    }

    private func currentMessage(for id: UUID) -> ChatMessage? {
        messages.first(where: { $0.id == id })
    }

    private func loadHistory() {
        Task {
            savedBotModel = allBots.first(where: { $0.id == botID })
            do {
                let descriptor = FetchDescriptor<ChatHistory>(predicate: #Predicate { $0.botID == botID }, sortBy: [SortDescriptor(\.date, order: .reverse)])
                let histories = try modelContext.fetch(descriptor)
                if let last = histories.first {
                    currentHistory = last
                    messages = last.messages.sorted(by: { $0.index < $1.index }).map { ChatMessage(content: $0.text, isUser: $0.isUser) }
                } else {
                    messages.append(ChatMessage(content: bot.greeting, isUser: false))
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
            .map { ChatMessage(content: $0.text, isUser: $0.isUser) }
        isManualHistoryLoad = true
    }
    
    private func showError(_ message: String) {
        alertMessage = message
        showAlertBanner = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation {
                showAlertBanner = false
            }
        }
    }
    
    private func startGentleVibration(interval: TimeInterval = 0.1) {
        let feedbackSequence: [UIImpactFeedbackGenerator.FeedbackStyle] = [
            .heavy,   // ≈ 1.0
            .medium,  // ≈ 0.7
            .light,   // ≈ 0.5
        ]

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

            let style = feedbackSequence[currentIndex]
            let generator = UIImpactFeedbackGenerator(style: style)
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

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = 20
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
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

    ChatView(bot: previewBot)
        .environmentObject(APIManager())
        .environment(PersonaManager())
}

