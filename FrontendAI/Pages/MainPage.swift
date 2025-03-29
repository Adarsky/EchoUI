import SwiftUI
import Foundation
import SwiftData

struct MainPage: View {
    // Sheets
    @State private var showSheetSettings = false
    @State private var showSheetAccount = false

    // Навигация
    @State private var selectedBot: BotModel? = nil
    @State private var selectedBotForEdit: BotModel? = nil
    @State private var navigateToChat = false
    @State private var showCreatePage = false

    // Удаление
    @State private var botToDelete: BotModel? = nil
    @State private var showDeleteAlert = false

    @State public var Endpoint: String = ""
    @State private var MessageLength: Int = 2048

    @Query var bots: [BotModel]
    @Environment(\.modelContext) var modelContext

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

                // Список ботов
                List {
                    ForEach(bots) { bot in
                        ChatListRow(
                            title: bot.name,
                            subtitle: formattedPreview(for: bot),
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

            // Навигация
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

        // Шторки
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
    }
}


// MARK: -- Some dummy functions

func formattedPreview(for bot: BotModel) -> String {
    // Пример: заглушка, позже подставим реальные сообщения
    let lastMessage = "This is a response from \(bot.name)" // <- сюда можно вставить последнее из БД

    // Префикс
    let prefix = Bool.random() ? "You: " : "\(bot.name): " // Заменить на реальное условие

    // Финальный текст
    let full = prefix + lastMessage

    // Если текст длинный — обрежем
    if full.count > 20 {
        let index = full.index(full.startIndex, offsetBy: 20)
        return String(full[..<index]) + "..."
    } else {
        return full
    }
}


//MARK: -- END OF BASE CODE

struct BottomSheetTestView_Previews: PreviewProvider {
    static var previews: some View {
        MainPage()
    }
}
