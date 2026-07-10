import SwiftUI
import Foundation
import SwiftData
import UIKit
import Symbols
import LocalAuthentication

enum MainPageAPIStatusDisplayStyle: String, CaseIterable, Identifiable {
    case hidden
    case coloredDot
    case monochromeDot
    case statusSymbols
    case textOnly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hidden:
            return "Hidden"
        case .coloredDot:
            return "Colored dot"
        case .monochromeDot:
            return "Black and white dot"
        case .statusSymbols:
            return "Signs"
        case .textOnly:
            return "No dot"
        }
    }
}

struct MainPage: View {
    @State private var showSheetSettings = false
    @State private var showSheetPersona = false
    @State private var selectedBot: BotModel? = nil
    @State private var selectedBotForEdit: BotModel? = nil
    @State private var navigateToChat = false
    @State private var showCreatePage = false
    @State private var showCreatePersonaPage = false
    @State private var shouldOpenCreatePersonaAfterPersonaSheetDismisses = false
    @State private var showAPIpage = false
    @State private var botForFolderAssignment: BotModel?


    @State private var botToDelete: BotModel? = nil
    @State private var showDeleteAlert = false
    @State private var botDeletionError: String?
    @State private var checkingAPIStatusServerUUID: UUID? = nil
    @State private var checkingAPIStatusRequestUUID: UUID? = nil
    @AppStorage("showMainHubAPIStatus") private var legacyShowMainHubAPIStatus = true
    @AppStorage("mainPageAPIStatusDisplayStyle") private var apiStatusDisplayStyleRawValue = MainPageAPIStatusDisplayStyle.coloredDot.rawValue
    @AppStorage("mainPageAPIStatusDisplayStyleDidMigrate") private var didMigrateAPIStatusDisplayStyle = false

    @AppStorage("chatFoldersEnabled") private var chatFoldersEnabled = true
    @AppStorage("selectedChatFolderID") private var selectedChatFolderID = ChatFolder.allFolderID
    @State private var folderNavigationDirection = 1
    @State private var unlockedPrivateFolderID: String?
    @State private var privateFolderAuthenticationMessage = "Face ID is required to open the Private folder."
    @State private var showsPrivateFolderAuthenticationAlert = false

    @Query var bots: [BotModel]
    @Query(sort: [SortDescriptor(\ChatFolder.sortIndex), SortDescriptor(\ChatFolder.name)]) private var chatFolders: [ChatFolder]
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

    private var apiStatusDisplayStyle: MainPageAPIStatusDisplayStyle {
        MainPageAPIStatusDisplayStyle(rawValue: apiStatusDisplayStyleRawValue) ?? .coloredDot
    }

    private var isWaitingForAPIStatusResponse: Bool {
        guard let selectedServerUUID = apiManager.selectedServer?.uuid else { return false }
        return checkingAPIStatusServerUUID == selectedServerUUID && checkingAPIStatusRequestUUID != nil
    }
    
    private var apiStatusText: String {
        if isWaitingForAPIStatusResponse {
            return "Checking"
        }

        return apiConnectionStatus.displayName
    }

    private var apiStatusColor: Color {
        if apiStatusDisplayStyle == .monochromeDot || apiStatusDisplayStyle == .statusSymbols {
            return .primary
        }

        if isWaitingForAPIStatusResponse {
            return .secondary
        }

        switch apiConnectionStatus {
        case .online:
            return .green
        case .warning:
            return .orange
        case .offline:
            return .red
        }
    }

    private var apiStatusSymbolName: String? {
        switch apiStatusDisplayStyle {
        case .hidden, .textOnly:
            return nil
        case .coloredDot, .monochromeDot:
            return "circle.fill"
        case .statusSymbols:
            if isWaitingForAPIStatusResponse {
                return "arrow.trianglehead.2.clockwise.rotate.90.icloud.fill"
            }
        }

        switch apiConnectionStatus {
        case .online:
            return "checkmark.icloud.fill"
        case .warning:
            return "exclamationmark.icloud.fill"
        case .offline:
            return "icloud.slash.fill"
        }
    }

    private var rotatesAPIStatusSymbol: Bool {
        guard apiStatusDisplayStyle == .statusSymbols else { return false }
        return isWaitingForAPIStatusResponse
    }

    private var apiNavigationSubtitleString: String {
        "\(displayedServerName) • \(apiStatusText)"
    }

    private var apiNavigationSubtitle: Text {
        Text(apiNavigationSubtitleString)
    }

    private var pinnedBots: [BotModel] {
        visibleBots
            .filter { $0.isPinned }
            .sorted {
                if $0.pinnedSortIndex == $1.pinnedSortIndex {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return $0.pinnedSortIndex < $1.pinnedSortIndex
            }
    }

    private var regularBots: [BotModel] {
        visibleBots.filter { !$0.isPinned }
    }

    private var selectedChatFolder: ChatFolder? {
        guard chatFoldersEnabled else { return nil }
        guard selectedChatFolderID != ChatFolder.allFolderID else { return nil }
        return chatFolders.first { $0.id.uuidString == selectedChatFolderID }
    }

    private var visibleBots: [BotModel] {
        PrivateChatVisibility.visibleBots(
            from: bots,
            folders: chatFolders,
            foldersEnabled: chatFoldersEnabled,
            selectedFolderID: selectedChatFolderID,
            unlockedPrivateFolderID: unlockedPrivateFolderID
        )
    }

    private var folderSignature: String {
        chatFolders.map { $0.id.uuidString }.joined(separator: "|")
    }

    private var chatFolderListTransition: AnyTransition {
        let insertionEdge: Edge = folderNavigationDirection >= 0 ? .trailing : .leading
        let removalEdge: Edge = folderNavigationDirection >= 0 ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
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
                    isVisible: apiStatusDisplayStyle != .hidden,
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
        .sheet(
            isPresented: $showSheetPersona,
            onDismiss: {
                if shouldOpenCreatePersonaAfterPersonaSheetDismisses {
                    shouldOpenCreatePersonaAfterPersonaSheetDismisses = false
                    showCreatePersonaPage = true
                }
            }
        ) {
            PersonaSheetView(
                isPresented: $showSheetPersona,
                onCreatePersona: {
                    shouldOpenCreatePersonaAfterPersonaSheetDismisses = true
                    showSheetPersona = false
                }
            )
        }
        .sheet(isPresented: $showSheetSettings) {
            SettingsSheetView(
                isPresented: $showSheetSettings,
                apiStatusDisplayStyle: $apiStatusDisplayStyleRawValue
            )
        }
        .sheet(isPresented: $showAPIpage) {
            APIManagerView(selectedServer: $apiManager.selectedServer)
        }
        .sheet(item: $botForFolderAssignment) { bot in
            ChatFolderAssignmentSheet(bot: bot)
        }
        .onAppear {
            migrateAPIStatusDisplayStyleIfNeeded()

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
            lockSelectedPrivateFolderIfNeeded()
            
            if let server = apiManager.selectedServer {
                Task {
                    await refreshAPIStatus(for: server)
                }
            }
        }
        .onChange(of: apiManager.selectedServer?.uuid) { _, _ in
            guard let server = apiManager.selectedServer else {
                checkingAPIStatusServerUUID = nil
                checkingAPIStatusRequestUUID = nil
                return
            }

            Task {
                await refreshAPIStatus(for: server)
            }
        }
        .onChange(of: folderSignature) { _, _ in
            validateSelectedFolder()
        }
        .onChange(of: chatFoldersEnabled) { _, isEnabled in
            if !isEnabled {
                selectedChatFolderID = ChatFolder.allFolderID
                unlockedPrivateFolderID = nil
            }
        }
        .onChange(of: selectedChatFolderID) { _, folderID in
            if !isPrivateFolderID(folderID) {
                unlockedPrivateFolderID = nil
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
        .navigationDestination(isPresented: $showCreatePersonaPage) {
            CreatePersonaView()
        }
    }

    private var mainHeader: some View {
        GlassEffectContainer {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Echo UI")
                        .font(.title)
                        .bold()
                    if apiStatusDisplayStyle != .hidden {
                        Button {
                            showAPIpage = true
                        } label: {
                            HStack(spacing: 6) {
                                if let apiStatusSymbolName {
                                    Image(systemName: apiStatusSymbolName)
                                        .font(.caption)
                                        .foregroundStyle(apiStatusColor)
                                        .symbolEffect(.rotate, isActive: rotatesAPIStatusSymbol)
                                }
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
            if chatFoldersEnabled && !bots.isEmpty {
                FolderPickerView(
                    folders: chatFolders,
                    selectedFolderID: $selectedChatFolderID,
                    showsCounts: true,
                    countForFolder: folderCount,
                    canSelectFolder: canSelectFolder,
                    onSelectionDirectionChange: { direction in
                        folderNavigationDirection = direction
                    }
                )
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }

            if bots.isEmpty {
                Text("Tap the plus button to create a new character.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)
            } else if visibleBots.isEmpty {
                Text(emptyFolderMessage)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)
                    .id(selectedChatFolderID)
                    .transition(chatFolderListTransition)
            } else if pinnedBots.isEmpty {
                ForEach(regularBots) { bot in
                    chatRow(for: bot)
                        .id(chatListAnimationID(for: bot))
                        .transition(chatFolderListTransition)
                }
            } else {
                Section() {
                    ForEach(pinnedBots) { bot in
                        chatRow(for: bot)
                            .id(chatListAnimationID(for: bot))
                            .transition(chatFolderListTransition)
                    }
                    .onMove { source, destination in
                        movePinnedBots(from: source, to: destination)
                    }
                }

                if !regularBots.isEmpty {
                    Section("All chats") {
                        ForEach(regularBots) { bot in
                            chatRow(for: bot)
                                .id(chatListAnimationID(for: bot))
                                .transition(chatFolderListTransition)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .animation(.snappy(duration: 0.28), value: selectedChatFolderID)
        .alert("Are you sure you want to delete this bot?", isPresented: $showDeleteAlert, presenting: botToDelete) { bot in
            Button("Yes, delete", role: .destructive) {
                deleteBot(bot)
            }
            Button("Cancel", role: .cancel) { }
        } message: { bot in
            Text("Bot \(bot.name) will be destroyed.")
        }
        .alert("Private Folder Locked", isPresented: $showsPrivateFolderAuthenticationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(privateFolderAuthenticationMessage)
        }
        .alert(
            "Could Not Delete Chat",
            isPresented: Binding(
                get: { botDeletionError != nil },
                set: { if !$0 { botDeletionError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { botDeletionError = nil }
        } message: {
            Text(botDeletionError ?? "The chat could not be deleted.")
        }
    }

    private var emptyFolderMessage: String {
        guard let selectedChatFolder else { return "No chats in this folder." }
        return "No chats in \(selectedChatFolder.displayName)."
    }

    private func folderCount(_ folder: ChatFolder?) -> Int {
        PrivateChatVisibility.visibleBots(
            from: bots,
            folders: chatFolders,
            foldersEnabled: true,
            selectedFolderID: folder?.id.uuidString ?? ChatFolder.allFolderID,
            unlockedPrivateFolderID: unlockedPrivateFolderID
        ).count
    }

    private func chatListAnimationID(for bot: BotModel) -> String {
        "\(selectedChatFolderID)-\(bot.id.uuidString)"
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
        }
        .swipeActions(edge: .trailing) {
            if !chatFolders.isEmpty {
                Button {
                    botForFolderAssignment = bot
                } label: {
                    Label("Folders", systemImage: "folder")
                }
                .tint(.blue)
            }

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
            if !chatFolders.isEmpty {
                Button {
                    botForFolderAssignment = bot
                } label: {
                    Label("Folders", systemImage: "folder")
                }
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

    @MainActor
    private func deleteBot(_ bot: BotModel) {
        let botID = bot.id

        do {
            try ChatHistoryPersistence.deleteHistories(for: botID, context: modelContext)
            for folder in chatFolders where folder.contains(botID: botID) {
                folder.setContains(false, botID: botID)
            }
            modelContext.delete(bot)
            try modelContext.save()
        } catch {
            modelContext.rollback()
            botDeletionError = error.localizedDescription
        }
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

    private func movePinnedBots(from source: IndexSet, to destination: Int) {
        var orderedPinnedBots = pinnedBots
        orderedPinnedBots.move(fromOffsets: source, toOffset: destination)
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

    private func validateSelectedFolder() {
        guard selectedChatFolderID != ChatFolder.allFolderID else { return }
        if !chatFolders.contains(where: { $0.id.uuidString == selectedChatFolderID }) {
            selectedChatFolderID = ChatFolder.allFolderID
        }
    }

    @MainActor
    private func canSelectFolder(_ folderID: String) async -> Bool {
        guard isPrivateFolderID(folderID) else { return true }

        let result = await authenticatePrivateFolder()
        switch result {
        case .success:
            unlockedPrivateFolderID = folderID
            return true
        case .failure(let message):
            privateFolderAuthenticationMessage = message
            showsPrivateFolderAuthenticationAlert = true
            return false
        }
    }

    private func isPrivateFolderID(_ folderID: String) -> Bool {
        chatFolders.first { $0.id.uuidString == folderID }?.isPrivate == true
    }

    private func lockSelectedPrivateFolderIfNeeded() {
        guard isPrivateFolderID(selectedChatFolderID), unlockedPrivateFolderID != selectedChatFolderID else { return }
        selectedChatFolderID = ChatFolder.allFolderID
    }

    private func migrateAPIStatusDisplayStyleIfNeeded() {
        guard !didMigrateAPIStatusDisplayStyle else { return }
        apiStatusDisplayStyleRawValue = legacyShowMainHubAPIStatus
            ? MainPageAPIStatusDisplayStyle.coloredDot.rawValue
            : MainPageAPIStatusDisplayStyle.hidden.rawValue
        didMigrateAPIStatusDisplayStyle = true
    }

    private func authenticatePrivateFolder() async -> PrivateFolderAuthenticationResult {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .failure(faceIDUnavailableMessage(from: error))
        }

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock the Private folder."
            ) { success, error in
                if success {
                    continuation.resume(returning: .success)
                } else {
                    continuation.resume(returning: .failure(faceIDFailedMessage(from: error)))
                }
            }
        }
    }

    @MainActor
    private func refreshAPIStatus(for server: APIServer) async {
        let requestUUID = UUID()
        checkingAPIStatusServerUUID = server.uuid
        checkingAPIStatusRequestUUID = requestUUID

        await apiManager.ping(server: server, modelContext: modelContext)

        if checkingAPIStatusRequestUUID == requestUUID {
            checkingAPIStatusServerUUID = nil
            checkingAPIStatusRequestUUID = nil
        }
    }
}

private enum PrivateFolderAuthenticationResult {
    case success
    case failure(String)
}

private func faceIDUnavailableMessage(from error: NSError?) -> String {
    guard let error else {
        return "Face ID is not available on this device."
    }

    switch LAError.Code(rawValue: error.code) {
    case .biometryNotAvailable:
        return "Face ID is not available on this device."
    case .biometryNotEnrolled:
        return "Set up Face ID in Settings to open the Private folder."
    case .biometryLockout:
        return "Face ID is locked. Unlock it in Settings before opening the Private folder."
    default:
        return "Face ID is required to open the Private folder."
    }
}

private func faceIDFailedMessage(from error: Error?) -> String {
    guard let error = error as? LAError else {
        return "Face ID did not unlock the Private folder."
    }

    switch error.code {
    case .userCancel, .appCancel, .systemCancel:
        return "The Private folder was not unlocked."
    case .authenticationFailed:
        return "Face ID did not recognize you."
    case .biometryLockout:
        return "Face ID is locked. Unlock it in Settings before opening the Private folder."
    default:
        return "Face ID did not unlock the Private folder."
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
        ChatFolder.self,
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
