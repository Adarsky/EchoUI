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

    @State public var Endpoint: String = ""
    @State private var MessageLength: Int = 2048

    @Query var bots: [BotModel]
    @Environment(\.modelContext) var modelContext
    
    @EnvironmentObject var apiManager: APIManager
    @Query var servers: [APIServer]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Echo UI")
                        .font(.title)
                        .bold()
                    
                    Spacer()
                    
                    Button {
                        showCreatePage = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }

                    Button {
                        showSheetSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                    }

                    Button {
                        showSheetAccount = true
                    } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.title3)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.10))

                List {
                    ForEach(bots) { bot in
                        ChatListRow(
                            title: bot.name,
                            subtitle: latestMessageText(for: bot, in: modelContext),
                            date: bot.date,
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
                endpoint: $Endpoint
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

func latestMessageText(for bot: BotModel, in context: ModelContext) -> String {
    let botID = bot.id
    let descriptor = FetchDescriptor<ChatHistory>(
        predicate: #Predicate { $0.botID == botID },
        sortBy: [SortDescriptor(\.date, order: .reverse)]
    )

    guard let lastHistory = try? context.fetch(descriptor).first,
          let lastMessage = lastHistory.messages.sorted(by: { $0.index < $1.index }).last else {
        return "No messages yet"
    }

    let prefix = lastMessage.isUser ? "You: " : "\(bot.name): "
    let content = lastMessage.text
    let full = prefix + content
    return full.count > 40 ? String(full.prefix(40)) + "…" : full
}



//MARK: -- END OF BASE CODE

struct BottomSheetTestView_Previews: PreviewProvider {
    static var previews: some View {
        MainPage()
    }
}
