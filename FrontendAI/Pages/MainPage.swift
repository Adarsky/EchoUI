import SwiftUI
import Foundation
import SwiftData

struct MainPage: View {
    // Sheets
    @State private var showSheetSettings = false
    @State private var showSheetAccount = false


    @State private var selectedBot: BotModel? = nil
    @State private var selectedBotForEdit: BotModel? = nil
    @State private var navigateToChat = false
    @State private var showCreatePage = false


    @State private var botToDelete: BotModel? = nil
    @State private var showDeleteAlert = false
    @AppStorage("showMainHubAPIStatus") private var showMainHubAPIStatus = true

    @State public var Endpoint: String = ""
    @State private var MessageLength: Int = 2048

    @Query var bots: [BotModel]
    @Environment(\.modelContext) var modelContext
    
    @EnvironmentObject var apiManager: APIManager
    @Query var servers: [APIServer]
    
    @Namespace var MainPageGlassEffect
    
    private var activeServerName: String {
        apiManager.selectedServer?.name ?? "No API"
    }
    
    private var displayedServerName: String {
        guard activeServerName.count > 12 else { return activeServerName }
        return String(activeServerName.prefix(12)) + "…"
    }
    
    private var isAPIServerOnline: Bool {
        apiManager.selectedServer?.isOnline ?? false
    }
    
    private var apiStatusText: String {
        isAPIServerOnline ? "Online" : "Offline"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                GlassEffectContainer () {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Echo UI")
                                .font(.title)
                                .bold()
                            if showMainHubAPIStatus {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(isAPIServerOnline ? Color.green : Color.red)
                                        .frame(width: 8, height: 8)
                                    Text("\(displayedServerName) • \(apiStatusText)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            showCreatePage = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.glass)
                        .glassEffectUnion(id: 1, namespace: MainPageGlassEffect)
                        
                        Button {
                            showSheetAccount = true
                        } label: {
                            Image(systemName: "person.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.glass)
                        .glassEffectUnion(id: 1, namespace: MainPageGlassEffect)
                        
                        Button {
                            showSheetSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.glass)
                        .glassEffectUnion(id: 2, namespace: MainPageGlassEffect)
                        
                    }
                }
                .padding()

                List {
                    ForEach(bots) { bot in
                        let preview = latestChatPreview(for: bot, in: modelContext)
                        ChatListRow(
                            title: bot.name,
                            subtitle: preview.subtitle,
                            date: preview.dateText,
                            isPinned: bot.isPinned,
                            avatarImage: bot.avatarImage
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedBot = bot
                            navigateToChat = true
                        }
                        .swipeActions(edge: .trailing) {
                            Button {
                                selectedBotForEdit = bot
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.orange)

                            Button(role: .destructive) {
                                botToDelete = bot
                                showDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .alert("Are you sure you want to delete this bot?", isPresented: $showDeleteAlert, presenting: botToDelete) { bot in
                    Button("Yes, delete", role: .destructive) {
                        modelContext.delete(bot)
                        try? modelContext.save()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: { bot in
                    Text("Bot \(bot.name) will be destroyed.")
                }

                Spacer()
            }

            .navigationDestination(isPresented: $navigateToChat) {
                if let bot = selectedBot {
                    ChatView(bot: bot.asBot())
                }
            }
            .navigationDestination(item: $selectedBotForEdit) { bot in
                EditBotView(bot: bot)
            }
            .navigationDestination(isPresented: $showCreatePage) {
                CreateBotView()
            }
        }

        .sheet(isPresented: $showSheetAccount) {
            AccountSheetView(isPresented: $showSheetAccount)
        }
        .sheet(isPresented: $showSheetSettings) {
            SettingsSheetView(
                isPresented: $showSheetSettings,
                messageLength: $MessageLength,
                endpoint: $Endpoint,
                showAPIStatus: $showMainHubAPIStatus
            )
        }
        .onAppear {
            apiManager.restoreLastSelectedServer(from: servers)
            
            if let server = apiManager.selectedServer {
                Task {
                    await apiManager.ping(server: server, modelContext: modelContext)
                }
            }
        }
    }
}

private struct ChatPreviewData {
    let subtitle: String
    let dateText: String
}

private func latestChatPreview(for bot: BotModel, in context: ModelContext) -> ChatPreviewData {
    let botID = bot.id
    let descriptor = FetchDescriptor<ChatHistory>(
        predicate: #Predicate { $0.botID == botID }
    )

    guard
        let histories = try? context.fetch(descriptor),
        !histories.isEmpty
    else {
        return ChatPreviewData(subtitle: "No messages yet", dateText: bot.date)
    }

    let latest: (message: ChatMessageEntity, date: Date)? = histories.compactMap { history in
        guard let message = history.messages.sorted(by: { $0.index < $1.index }).last else { return nil }
        let messageDate = message.timestamp ?? history.date
        return (message: message, date: messageDate)
    }
    .max(by: { $0.date < $1.date })

    guard let latest else {
        return ChatPreviewData(subtitle: "No messages yet", dateText: bot.date)
    }

    let prefix = latest.message.isUser ? "You: " : "\(bot.name): "
    let content = latest.message.text
    let full = prefix + content
    let subtitle = full.count > 40 ? String(full.prefix(40)) + "…" : full
    let dateText = latest.date.formatted(date: .abbreviated, time: .omitted)
    return ChatPreviewData(subtitle: subtitle, dateText: dateText)
}



//MARK: -- END OF BASE CODE

#Preview {
    MainPage()
        .modelContainer(
            for: [
                BotModel.self,
                APIServer.self,
                ChatHistory.self,
                ChatMessageEntity.self,
                PersonaModel.self
            ],
            inMemory: true
        )
        .environmentObject(APIManager())
        .environment(PersonaManager())
}
