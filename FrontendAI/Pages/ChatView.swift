import SwiftUI
import SwiftData

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
            VStack(spacing: 0) {
                headerBar
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { msg in
                            if msg.isUser {
                                HStack(spacing: 6) {
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text(msg.content)
                                            .padding()
                                            .background(Color.blue)
                                            .cornerRadius(12)
                                            .foregroundColor(.white)
                                    }
                                    if showAvatars {
                                        if let avatar = personaManager.activePersona?.avatarData, let image = UIImage(data: avatar) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 32, height: 32)
                                                .clipShape(Circle())
                                        } else {
                                            Image(systemName: "person.fill")
                                                .resizable()
                                                .frame(width: 32, height: 32)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                                .contextMenu {
                                    Button("Copy") {
                                        UIPasteboard.general.string = msg.content
                                    }
                                    Button("Edit") {}
                                    Button("Delete", role: .destructive) {
                                        messages.removeAll { $0.id == msg.id }
                                    }
                                }
                            } else {
                                HStack(alignment: .bottom, spacing: 6) {
                                    if showAvatars {
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
                                    }

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(msg.content)
                                            .padding()
                                            .background(Color.gray.opacity(0.2))
                                            .cornerRadius(12)

                                        HStack(spacing: 8) {
                                            Button {
                                                regenerateMessage(for: msg)
                                            } label: {
                                                Image(systemName: "arrow.trianglehead.counterclockwise.rotate.90")
                                            }

                                            Button {
                                                switchVariant(for: msg.id, direction: -1)
                                            } label: {
                                                Image(systemName: "arrow.left")
                                            }
                                            .disabled(currentMessage(for: msg.id)?.currentIndex == 0)

                                            Button {
                                                switchVariant(for: msg.id, direction: 1)
                                            } label: {
                                                Image(systemName: "arrow.right")
                                            }
                                            .disabled((currentMessage(for: msg.id)?.currentIndex ?? 0) >= (currentMessage(for: msg.id)?.allVariants.count ?? 1) - 1)
                                        }
                                    }
                                }
                                .contextMenu {
                                    Button("Copy") {
                                        UIPasteboard.general.string = msg.content
                                    }
                                    Button("Edit") {}
                                    Button("Delete", role: .destructive) {
                                        messages.removeAll { $0.id == msg.id }
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                inputBar
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !isManualHistoryLoad {
                loadHistory()
            }
        }
        .onDisappear(perform: saveChatHistory)
        .alert("No API server selected", isPresented: $showAPIMissingAlert) {
            Button("OK", role: .cancel) {}
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
        HStack(spacing: 12) {
            ZStack(alignment: .leading) {
                if inputText.isEmpty {
                    Text("Message \(bot.name)...")
                        .foregroundColor(.gray)
                }
                TextField("", text: $inputText)
                    .foregroundColor(.primary)
            }
            .padding(8)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)

            Button {
                if apiManager.selectedServer == nil {
                    showAPIMissingAlert = true
                } else {
                    sendMessage()
                }
            } label: {
                Image(systemName: "paperplane.fill")
            }
        }
        .padding()
    }

    private func sendMessage() {
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

        // 💡 Добавим greeting, только если он не в messages
        let hasGreeting = messages.contains { !$0.isUser && $0.content == greeting }

        var payload: [ChatPayloadMessage] = []

        if !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload.append(.init(role: "system", content: systemPrompt))
        }

        payload.append(dummyUser)

        if !hasGreeting {
            payload.append(.init(role: "assistant", content: greeting))
        }

        payload += historyPayload

        /// ✅ DEBUG PRINT
        print("📤 Payload being sent to API:")
        for msg in payload {
            print("[\(msg.role)] \(msg.content)")
        }

        Task {
            guard let server = apiManager.selectedServer else { return }
            do {
                let reply = try await APIService.sendMessage(messages: payload, server: server)
                withAnimation {
                    messages.append(ChatMessage(content: reply, isUser: false))
                }
                saveChatHistory()
            } catch {
                print("❌ API Error: \(error.localizedDescription)")
                messages.append(ChatMessage(content: "⚠️ Error: \(error.localizedDescription)", isUser: false))
                saveChatHistory()
            }
        }
    }





    private func regenerateMessage(for message: ChatMessage) {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }

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


        Task {
            guard let server = apiManager.selectedServer else { return }
            do {
                let reply = try await APIService.sendMessage(messages: payload, server: server)
                messages[index].allVariants.append(reply)
                messages[index].currentIndex = messages[index].allVariants.count - 1
                saveChatHistory()
            } catch {
                print("⚠️ Error regenerating: \(error.localizedDescription)")
            }
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


}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
