import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

struct FoldersSettingsSheet: View {
    @AppStorage("chatFoldersEnabled") private var foldersEnabled = true
    @Environment(\.modelContext) private var modelContext
    @Environment(PrivateChatAccess.self) private var privateChatAccess
    @Query(sort: [SortDescriptor(\ChatFolder.sortIndex), SortDescriptor(\ChatFolder.name)]) private var folders: [ChatFolder]
    @Query(sort: [SortDescriptor(\BotModel.name)]) private var bots: [BotModel]

    @State private var previewSelectedFolderID = ChatFolder.allFolderID
    @State private var isCreatingFolder = false
    @State private var editingFolder: ChatFolder?
    @State private var folderError: String?

    private var accessibleBots: [BotModel] {
        privateChatAccess.visibleBots(from: bots, folders: folders)
    }

    var body: some View {
        List {
            Section("Preview") {
                FolderPickerView(
                    folders: folders,
                    selectedFolderID: $previewSelectedFolderID,
                    showsCounts: true,
                    countForFolder: folderCount
                )
                .listRowInsets(EdgeInsets())
            }

            Section {
                Toggle("Enable folders", isOn: $foldersEnabled)
            }

            Section {
                if folders.isEmpty {
                    Text("Create a folder to group chats by work, personal projects, agents, or any workflow you use often.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(folders) { folder in
                        folderRow(folder)
                            .swipeActions(edge: .trailing) {
                                Button {
                                    requestEditFolder(folder)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.orange)

                                Button(role: .destructive) {
                                    requestDeleteFolder(folder)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                    .onMove(perform: moveFolders)
                }

                Button {
                    isCreatingFolder = true
                } label: {
                    Label("Create new folder", systemImage: "plus")
                }
            } header: {
                Text("Folders")
            } footer: {
                Text("Folders appear as tabs above the chat list and filter which chats are shown.")
            }
        }
        .navigationTitle("Chat Folders")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !folders.isEmpty {
                EditButton()
            }
        }
        .sheet(isPresented: $isCreatingFolder) {
            ChatFolderEditorSheet(
                title: "New Folder",
                bots: accessibleBots,
                folder: nil,
                onSave: createFolder
            )
        }
        .sheet(item: $editingFolder) { folder in
            if privateChatAccess.canModify(folder) {
                ChatFolderEditorSheet(
                    title: "Edit Folder",
                    bots: accessibleBots,
                    folder: folder,
                    onSave: { name, symbolName, colorName, hidesFromAllChats, botIDStrings in
                        updateFolder(
                            folder,
                            name: name,
                            symbolName: symbolName,
                            colorName: colorName,
                            hidesFromAllChats: hidesFromAllChats,
                            botIDStrings: botIDStrings
                        )
                    }
                )
            }
        }
        .alert("Could Not Update Folder", isPresented: Binding(
            get: { folderError != nil },
            set: { if !$0 { folderError = nil } }
        )) { } message: {
            Text(folderError ?? "")
        }
        .onChange(of: privateChatAccess.isUnlocked) { _, isUnlocked in
            if !isUnlocked {
                editingFolder = nil
                isCreatingFolder = false
            }
        }
        .onChange(of: folderSignature) { _, _ in
            if previewSelectedFolderID != ChatFolder.allFolderID && !folders.contains(where: { $0.id.uuidString == previewSelectedFolderID }) {
                previewSelectedFolderID = ChatFolder.allFolderID
            }
        }
    }

    private var folderSignature: String {
        folders.map { $0.id.uuidString }.joined(separator: "|")
    }

    private func folderRow(_ folder: ChatFolder) -> some View {
        Button {
            requestEditFolder(folder)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: folder.symbolName)
                    .frame(width: 28, height: 28)
                    .foregroundStyle(.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(folder.displayName)
                        .foregroundStyle(.primary)
                    Text("\(folderCount(folder)) chats")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private func folderCount(_ folder: ChatFolder?) -> Int {
        guard let folder else {
            return PrivateChatVisibility.visibleBots(
                from: bots,
                folders: folders,
                foldersEnabled: true,
                selectedFolderID: ChatFolder.allFolderID,
                unlockedPrivateFolderID: nil
            ).count
        }
        return accessibleBots.filter { folder.contains(botID: $0.id) }.count
    }

    private func requestEditFolder(_ folder: ChatFolder) {
        Task {
            guard await authorize(folder) else { return }
            editingFolder = folder
        }
    }

    private func requestDeleteFolder(_ folder: ChatFolder) {
        Task {
            guard await authorize(folder) else { return }
            deleteFolder(folder)
        }
    }

    private func authorize(_ folder: ChatFolder) async -> Bool {
        if privateChatAccess.canModify(folder) { return true }
        do {
            return try await privateChatAccess.authorize()
        } catch {
            folderError = error.localizedDescription
            return false
        }
    }

    private func createFolder(name: String, symbolName: String, colorName: String, hidesFromAllChats: Bool, botIDStrings: [String]) {
        let folder = ChatFolder(
            name: name,
            symbolName: symbolName,
            colorName: colorName,
            hidesFromAllChats: hidesFromAllChats,
            botIDStrings: botIDStrings,
            sortIndex: (folders.map(\.sortIndex).max() ?? -1) + 1
        )
        modelContext.insert(folder)
        saveFolders()
        previewSelectedFolderID = folder.id.uuidString
    }

    private func updateFolder(
        _ folder: ChatFolder,
        name: String,
        symbolName: String,
        colorName: String,
        hidesFromAllChats: Bool,
        botIDStrings: [String]
    ) {
        guard privateChatAccess.canModify(folder) else { return }
        ChatFolderOrganization.replaceMembers(of: folder, with: botIDStrings, bots: bots, folders: folders)
        folder.name = ChatFolder.clampedName(name)
        folder.symbolName = symbolName
        folder.colorName = ChatFolderColor(rawValue: colorName)?.rawValue ?? ChatFolderColor.defaultValue.rawValue
        folder.hidesFromAllChats = hidesFromAllChats
        folder.updatedAt = .now
        saveFolders()
    }

    private func deleteFolder(_ folder: ChatFolder) {
        guard privateChatAccess.canModify(folder) else { return }
        if previewSelectedFolderID == folder.id.uuidString {
            previewSelectedFolderID = ChatFolder.allFolderID
        }
        ChatFolderOrganization.replaceMembers(of: folder, with: [], bots: bots, folders: folders)
        modelContext.delete(folder)
        saveFolders()
        folderFeedback(.warning)
    }

    private func moveFolders(from source: IndexSet, to destination: Int) {
        var orderedFolders = folders
        orderedFolders.move(fromOffsets: source, toOffset: destination)
        for (index, folder) in orderedFolders.enumerated() {
            folder.sortIndex = index
            folder.updatedAt = .now
        }
        saveFolders()
    }

    private func saveFolders() {
        try? modelContext.save()
        folderFeedback(.success)
    }
}

struct ChatFolderAssignmentSheet: View {
    let bot: BotModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(PrivateChatAccess.self) private var privateChatAccess
    @State private var authenticationError: String?
    @Query(sort: [SortDescriptor(\ChatFolder.sortIndex), SortDescriptor(\ChatFolder.name)]) private var folders: [ChatFolder]
    @Query private var bots: [BotModel]

    var body: some View {
        NavigationStack {
            List {
                if folders.isEmpty {
                    ContentUnavailableView(
                        "No Folders",
                        systemImage: "folder",
                        description: Text("Create folders in Settings, then add this chat to them.")
                    )
                } else {
                    Section {
                        ForEach(folders) { folder in
                            Button {
                                Task { await toggle(folder) }
                            } label: {
                                HStack {
                                    Label(folder.displayName, systemImage: folder.symbolName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if folder.contains(botID: bot.id) {
                                        Image(systemName: "checkmark")
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(.accent)
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } footer: {
                        Text("A chat can be in more than one folder.")
                    }
                }
            }
            .navigationTitle("Folders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Private Folder Locked", isPresented: Binding(
            get: { authenticationError != nil },
            set: { if !$0 { authenticationError = nil } }
        )) { } message: {
            Text(authenticationError ?? "")
        }
    }

    private func toggle(_ folder: ChatFolder) async {
        if !privateChatAccess.canModify(folder) {
            do {
                guard try await privateChatAccess.authorize() else { return }
            } catch {
                authenticationError = error.localizedDescription
                return
            }
        }
        let id = ChatFolder.storageID(for: bot.id)
        let memberIDs = folder.contains(botID: bot.id)
            ? folder.botIDStrings.filter { $0 != id }
            : folder.botIDStrings + [id]
        ChatFolderOrganization.replaceMembers(of: folder, with: memberIDs, bots: bots, folders: folders)
        try? modelContext.save()
        folderFeedback(.selection)
    }
}

private struct ChatFolderEditorSheet: View {
    let title: String
    let bots: [BotModel]
    let folder: ChatFolder?
    let onSave: (String, String, String, Bool, [String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var symbolName: String
    @State private var colorName: String
    @State private var hidesFromAllChats: Bool
    @State private var selectedBotIDStrings: Set<String>

    init(
        title: String,
        bots: [BotModel],
        folder: ChatFolder?,
        onSave: @escaping (String, String, String, Bool, [String]) -> Void
    ) {
        self.title = title
        self.bots = bots
        self.folder = folder
        self.onSave = onSave
        self._name = State(initialValue: folder?.displayName ?? "")
        self._symbolName = State(initialValue: folder?.symbolName ?? ChatFolderSymbol.defaultSymbol)
        self._colorName = State(initialValue: folder?.displayColor.rawValue ?? ChatFolderColor.defaultValue.rawValue)
        self._hidesFromAllChats = State(initialValue: folder?.hidesFromAllChats ?? false)
        self._selectedBotIDStrings = State(initialValue: Set(folder?.botIDStrings ?? []))
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Folder") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .onChange(of: name) { _, newValue in
                            if newValue.count > ChatFolder.maxNameLength {
                                name = String(newValue.prefix(ChatFolder.maxNameLength))
                            }
                        }

                    Picker("Icon", selection: $symbolName) {
                        ForEach(ChatFolderSymbol.allSymbols, id: \.self) { symbol in
                            Label(ChatFolderSymbol.title(for: symbol), systemImage: symbol)
                                .tag(symbol)
                        }
                    }

                    Picker("Color", selection: $colorName) {
                        ForEach(ChatFolderColor.allCases) { folderColor in
                            Label {
                                Text(folderColor.displayName)
                            } icon: {
                                colorOptionImage(for: folderColor)
                                    .renderingMode(.original)
                                    .accessibilityHidden(true)
                            }
                            .tag(folderColor.rawValue)
                        }
                    }
                }

                Section {
                    Toggle("Hide from All Chats", isOn: $hidesFromAllChats)
                } footer: {
                    Text("When enabled, characters in this folder are hidden from All Chats. Characters in Private folders always stay hidden from All Chats.")
                }

                Section {
                    if bots.isEmpty {
                        Text("Create chats first, then add them to this folder.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(bots.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })) { bot in
                            Button {
                                toggle(bot)
                            } label: {
                                HStack(spacing: 12) {
                                    bot.avatarImage
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 32, height: 32)
                                        .clipShape(Circle())

                                    Text(bot.name)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    if selectedBotIDStrings.contains(ChatFolder.storageID(for: bot.id)) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.accent)
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selectedBotIDStrings.contains(ChatFolder.storageID(for: bot.id)) ? .isSelected : [])
                        }
                    }
                } header: {
                    Text("Included Chats")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private var trimmedName: String {
        ChatFolder.clampedName(name)
    }

    private func colorOptionImage(for folderColor: ChatFolderColor) -> Image {
        #if os(iOS)
        if let symbol = UIImage(systemName: "circle.fill") {
            let coloredSymbol = symbol.withTintColor(
                UIColor(folderColor.color),
                renderingMode: .alwaysOriginal
            )
            return Image(uiImage: coloredSymbol)
        }
        #endif

        return Image(systemName: "circle.fill")
    }

    private func toggle(_ bot: BotModel) {
        let storageID = ChatFolder.storageID(for: bot.id)
        if selectedBotIDStrings.contains(storageID) {
            selectedBotIDStrings.remove(storageID)
        } else {
            selectedBotIDStrings.insert(storageID)
        }
        folderFeedback(.selection)
    }

    private func save() {
        onSave(trimmedName, symbolName, colorName, hidesFromAllChats, Array(selectedBotIDStrings).sorted())
        folderFeedback(.success)
        dismiss()
    }
}

private enum ChatFolderSymbol {
    static let defaultSymbol = "folder"
    static let allSymbols = [
        "folder",
        "briefcase",
        "person.2",
        "star",
        "house",
        "book",
        "hammer",
        "paintpalette",
        "network",
        "lock"
    ]

    static func title(for symbolName: String) -> String {
        switch symbolName {
        case "briefcase":
            return "Work"
        case "person.2":
            return "People"
        case "star":
            return "Favorites"
        case "house":
            return "Home"
        case "book":
            return "Study"
        case "hammer":
            return "Tools"
        case "paintpalette":
            return "Creative"
        case "network":
            return "API"
        case "lock":
            return "Private"
        default:
            return "Folder"
        }
    }
}

private enum ChatFolderFeedbackKind {
    case selection
    case success
    case warning
}

private func folderFeedback(_ kind: ChatFolderFeedbackKind) {
    #if os(iOS)
    switch kind {
    case .selection:
        UISelectionFeedbackGenerator().selectionChanged()
    case .success:
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    case .warning:
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    #endif
}

#Preview {
    NavigationStack {
        FoldersSettingsSheet()
    }
    .modelContainer(foldersSettingsPreviewContainer)
    .environment(PrivateChatAccess())
}

@MainActor
private let foldersSettingsPreviewContainer: ModelContainer = {
    let schema = Schema([BotModel.self, ChatHistory.self, ChatFolder.self, ChatMessageEntity.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [configuration])
    let context = container.mainContext
    let bot = BotModel(
        name: "Swift Mentor",
        subtitle: "iOS implementation notes",
        date: "May 27, 2026",
        avatarSystemName: "swift",
        iconColorName: "orange",
        isPinned: true,
        greeting: "Ask about SwiftUI."
    )
    context.insert(bot)
    context.insert(
        ChatFolder(
            name: "Work",
            symbolName: "briefcase",
            colorName: "orange",
            botIDStrings: [ChatFolder.storageID(for: bot.id)]
        )
    )
    try? context.save()
    return container
}()
