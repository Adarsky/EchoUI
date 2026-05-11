import SwiftUI
import Foundation
import SwiftData

struct MainPage: View {
    @State private var showSheetSettings = false
    @State private var showSheetPersona = false
    @State private var selectedBot: BotModel? = nil
    @State private var selectedBotForEdit: BotModel? = nil
    @State private var navigateToChat = false
    @State private var showCreatePage = false
    @State private var showAPIpage = false


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
    
    private var apiConnectionStatus: APIConnectionStatus {
        apiManager.selectedServer?.connectionStatus ?? .offline
    }
    
    private var apiStatusText: String {
        apiConnectionStatus.displayName
    }

    private var apiStatusColor: Color {
        switch apiConnectionStatus {
        case .online:
            return .green
        case .warning:
            return .orange
        case .offline:
            return .red
        }
    }

    private var apiNavigationSubtitle: Text {
        var subtitle = AttributedString("● \(displayedServerName) • \(apiStatusText)")
        if let dotRange = subtitle.range(of: "●") {
            subtitle[dotRange].foregroundColor = apiStatusColor
        }
        return Text(subtitle)
    }

    private var pinnedBots: [BotModel] {
        bots
            .filter { $0.isPinned }
            .sorted {
                if $0.pinnedSortIndex == $1.pinnedSortIndex {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return $0.pinnedSortIndex < $1.pinnedSortIndex
            }
    }

    private var regularBots: [BotModel] {
        bots.filter { !$0.isPinned }
    }

    var body: some View {
        NavigationStack {
            homePage
                .overlay(alignment: .bottomTrailing) {
                    AddButton()
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                }
                .navigationTitle("Echo UI")
                .modifier(MainPageAPISubtitleModifier(
                    isVisible: showMainHubAPIStatus,
                    subtitle: apiNavigationSubtitle
                ))
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 16) {
                            Button {
                                showSheetPersona = true
                            } label: {
                                Image(systemName: "person.fill")
                            }
                            
                            Button {
                                showSheetSettings = true
                            } label: {
                                Image(systemName: "gearshape.fill")
                            }
                        }
                        .padding(5)
                    }
                }
        }
        .sheet(isPresented: $showSheetPersona) {
            PersonaSheetView(isPresented: $showSheetPersona)
        }
        .sheet(isPresented: $showSheetSettings) {
            SettingsSheetView(
                isPresented: $showSheetSettings,
                messageLength: $MessageLength,
                endpoint: $Endpoint,
                showAPIStatus: $showMainHubAPIStatus
            )
        }
        .sheet(isPresented: $showAPIpage) {
            APIManagerView(selectedServer: $apiManager.selectedServer)
        }
        .onAppear {
            var didMigrateLegacyKeys = false
            for server in servers {
                if server.migrateAPIKeyToKeychainIfNeeded() {
                    didMigrateLegacyKeys = true
                }
            }
            if didMigrateLegacyKeys {
                try? modelContext.save()
            }

            apiManager.restoreLastSelectedServer(from: servers)
            
            if let server = apiManager.selectedServer {
                Task {
                    await apiManager.ping(server: server, modelContext: modelContext)
                }
            }
        }
    }
    private func AddButton() -> some View {
        Button {
            showCreatePage = true
        } label: {
            Image(systemName: "plus")
                .foregroundStyle(Color(.black))
                .font(.title2)
                .padding()
        }
        .buttonBorderShape(.circle)
        .glassEffect(.regular.tint(.white.opacity(1.0)).interactive())
    }

    private var homePage: some View {
        VStack(spacing: 0) {
            chatList
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

    private var mainHeader: some View {
        GlassEffectContainer {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Echo UI")
                        .font(.title)
                        .bold()
                    if showMainHubAPIStatus {
                        Button {
                            showAPIpage = true
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(apiStatusColor)
                                    .frame(width: 8, height: 8)
                                Text("\(displayedServerName) • \(apiStatusText)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Spacer()

                Button {
                    showSheetPersona = true
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
    }

    private var chatList: some View {
        List {
            if bots.isEmpty {
                Text("Tap the plus button to create a new character")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)
            } else if pinnedBots.isEmpty {
                ForEach(regularBots) { bot in
                    chatRow(for: bot)
                }
            } else {
                Section() {
                    ForEach(pinnedBots) { bot in
                        chatRow(for: bot)
                    }
                }

                if !regularBots.isEmpty {
                    Section("All chats") {
                        ForEach(regularBots) { bot in
                            chatRow(for: bot)
                        }
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
    }
    
    @ViewBuilder
    private func chatRow(for bot: BotModel) -> some View {
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
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            pinButton(for: bot)

            if bot.isPinned {
                Button {
                    movePinnedBot(bot, direction: .up)
                } label: {
                    Label("Up", systemImage: "arrow.up")
                }
                .tint(.blue)
                .disabled(!canMovePinnedBot(bot, direction: .up))

                Button {
                    movePinnedBot(bot, direction: .down)
                } label: {
                    Label("Down", systemImage: "arrow.down")
                }
                .tint(.blue)
                .disabled(!canMovePinnedBot(bot, direction: .down))
            }
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
        .contextMenu {
            pinButton(for: bot)

            if bot.isPinned {
                Button {
                    movePinnedBot(bot, direction: .up)
                } label: {
                    Label("Move Up", systemImage: "arrow.up")
                }
                .disabled(!canMovePinnedBot(bot, direction: .up))

                Button {
                    movePinnedBot(bot, direction: .down)
                } label: {
                    Label("Move Down", systemImage: "arrow.down")
                }
                .disabled(!canMovePinnedBot(bot, direction: .down))
            }
        }
    }

    private func pinButton(for bot: BotModel) -> some View {
        Button {
            togglePinned(bot)
        } label: {
            Label(bot.isPinned ? "Unpin" : "Pin", systemImage: bot.isPinned ? "pin.slash" : "pin")
        }
        .tint(bot.isPinned ? .gray : .gray)
    }

    private enum PinnedMoveDirection {
        case up
        case down
    }

    private func togglePinned(_ bot: BotModel) {
        if bot.isPinned {
            bot.isPinned = false
            bot.pinnedSortIndex = 0
        } else {
            bot.isPinned = true
            bot.pinnedSortIndex = (pinnedBots.map(\.pinnedSortIndex).max() ?? -1) + 1
        }

        normalizePinnedOrder()
        try? modelContext.save()
    }

    private func canMovePinnedBot(_ bot: BotModel, direction: PinnedMoveDirection) -> Bool {
        guard let index = pinnedBots.firstIndex(where: { $0.id == bot.id }) else { return false }

        switch direction {
        case .up:
            return index > 0
        case .down:
            return index < pinnedBots.count - 1
        }
    }

    private func movePinnedBot(_ bot: BotModel, direction: PinnedMoveDirection) {
        var orderedPinnedBots = pinnedBots
        guard let index = orderedPinnedBots.firstIndex(where: { $0.id == bot.id }) else { return }

        let targetIndex: Int
        switch direction {
        case .up:
            targetIndex = index - 1
        case .down:
            targetIndex = index + 1
        }

        guard orderedPinnedBots.indices.contains(targetIndex) else { return }
        orderedPinnedBots.swapAt(index, targetIndex)
        applyPinnedOrder(orderedPinnedBots)
        try? modelContext.save()
    }

    private func normalizePinnedOrder() {
        applyPinnedOrder(pinnedBots)
    }

    private func applyPinnedOrder(_ orderedPinnedBots: [BotModel]) {
        for (index, bot) in orderedPinnedBots.enumerated() {
            bot.pinnedSortIndex = index
        }
    }
}

private struct MainPageAPISubtitleModifier: ViewModifier {
    let isVisible: Bool
    let subtitle: Text

    @ViewBuilder
    func body(content: Content) -> some View {
        if isVisible {
            content.navigationSubtitle(subtitle)
        } else {
            content
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
        return ChatPreviewData(subtitle: "No messages yet", dateText: formattedMainPageDate(from: bot.date))
    }

    let latest: (message: ChatMessageEntity, date: Date, content: String)? = histories.compactMap { history in
        history.messages
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { message in
                let messageDate = message.timestamp ?? history.date
                return (message: message, date: messageDate, content: message.text)
            }
            .max(by: { $0.message.index < $1.message.index })
    }
    .max(by: { $0.date < $1.date })

    guard let latest else {
        return ChatPreviewData(subtitle: "No messages yet", dateText: formattedMainPageDate(from: bot.date))
    }

    let prefix = latest.message.isUser ? "You: " : "\(bot.name): "
    let content = normalizedMainPagePreviewText(from: latest.content)
    let full = prefix + content
    let dateText = formattedMainPageDate(latest.date)
    return ChatPreviewData(subtitle: full, dateText: dateText)
}

private func normalizedMainPagePreviewText(from text: String) -> String {
    text
        .split(whereSeparator: \.isWhitespace)
        .joined(separator: " ")
}

private func formattedMainPageDate(from storedDate: String) -> String {
    guard let date = parsedStoredBotDate(storedDate) else {
        return storedDate
    }

    return formattedMainPageDate(date)
}

private func parsedStoredBotDate(_ storedDate: String) -> Date? {
    let formats = [
        DateFormatter.Style.medium,
        DateFormatter.Style.short
    ]

    for dateStyle in formats {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = .none

        if let date = formatter.date(from: storedDate) {
            return date
        }
    }

    return nil
}

private func formattedMainPageDate(_ date: Date, relativeTo now: Date = Date()) -> String {
    let calendar = Calendar.current

    if date >= now.addingTimeInterval(-24 * 60 * 60) {
        return mainPageDateFormatter("HH:mm").string(from: date)
    }

    if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now), date >= weekAgo {
        return mainPageDateFormatter("EEE").string(from: date)
    }

    if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
        return mainPageDateFormatter("d/M").string(from: date)
    }

    return mainPageDateFormatter("d/M/yy").string(from: date)
}

private func mainPageDateFormatter(_ dateFormat: String) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = dateFormat
    return formatter
}



#Preview("Empty Chats") {
    MainPage()
        .modelContainer(mainPagePreviewContainer())
        .environmentObject(APIManager())
        .environment(PersonaManager())
}

#Preview("All Chats") {
    MainPage()
        .modelContainer(mainPagePreviewContainer(seed: .regularOnly))
        .environmentObject(APIManager())
        .environment(PersonaManager())
}

#Preview("Pinned And All Chats") {
    MainPage()
        .modelContainer(mainPagePreviewContainer(seed: .pinnedAndRegular))
        .environmentObject(APIManager())
        .environment(PersonaManager())
}

private enum MainPagePreviewSeed {
    case empty
    case regularOnly
    case pinnedAndRegular
}

@MainActor
private func mainPagePreviewContainer(seed: MainPagePreviewSeed = .empty) -> ModelContainer {
    let schema = Schema([
        BotModel.self,
        APIServer.self,
        ChatHistory.self,
        ChatMessageEntity.self,
        PersonaModel.self
    ])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [configuration])
    let context = container.mainContext

    switch seed {
    case .empty:
        break
    case .regularOnly:
        insertMainPagePreviewBots(
            regularBots: mainPageRegularPreviewBots(),
            pinnedBots: [],
            in: context
        )
    case .pinnedAndRegular:
        insertMainPagePreviewBots(
            regularBots: mainPageRegularPreviewBots(),
            pinnedBots: mainPagePinnedPreviewBots(),
            in: context
        )
    }

    try? context.save()
    return container
}

@MainActor
private func insertMainPagePreviewBots(
    regularBots: [BotModel],
    pinnedBots: [BotModel],
    in context: ModelContext
) {
    let allBots = pinnedBots + regularBots
    for bot in allBots {
        context.insert(bot)
        context.insert(mainPagePreviewHistory(for: bot))
    }
}

private func mainPagePinnedPreviewBots() -> [BotModel] {
    [
        BotModel(
            name: "Design Lead",
            subtitle: "Product UI review",
            date: "Apr 28, 2026",
            avatarSystemName: "paintpalette.fill",
            iconColorName: "purple",
            isPinned: true,
            pinnedSortIndex: 0,
            greeting: "Send screens or flows for review."
        ),
        BotModel(
            name: "Swift Mentor",
            subtitle: "iOS implementation notes",
            date: "Apr 27, 2026",
            avatarSystemName: "swift",
            iconColorName: "orange",
            isPinned: true,
            pinnedSortIndex: 1,
            greeting: "Ask about SwiftUI, SwiftData, and app structure."
        )
    ]
}

private func mainPageRegularPreviewBots() -> [BotModel] {
    [
        BotModel(
            name: "Travel Planner",
            subtitle: "Trip research",
            date: "Apr 26, 2026",
            avatarSystemName: "airplane.departure",
            iconColorName: "blue",
            isPinned: false,
            greeting: "Where are we going next?"
        ),
        BotModel(
            name: "Study Coach",
            subtitle: "Learning schedule",
            date: "Apr 25, 2026",
            avatarSystemName: "book.fill",
            iconColorName: "green",
            isPinned: false,
            greeting: "What topic are we covering today?"
        ),
        BotModel(
            name: "API Helper",
            subtitle: "Endpoint debugging",
            date: "Apr 24, 2026",
            avatarSystemName: "network",
            iconColorName: "cyan",
            isPinned: false,
            greeting: "Paste an API response or request."
        )
    ]
}

private func mainPagePreviewHistory(for bot: BotModel) -> ChatHistory {
    let now = Date()
    let messages = [
        ChatMessageEntity(
            text: "Can you help me continue this thread?",
            isUser: true,
            index: 0,
            timestamp: now.addingTimeInterval(-600)
        ),
        ChatMessageEntity(
            text: "Yes, I have the context and can pick up from the latest changes.",
            isUser: false,
            index: 1,
            timestamp: now
        )
    ]

    return ChatHistory(messages: messages, date: now, bot: bot)
}
