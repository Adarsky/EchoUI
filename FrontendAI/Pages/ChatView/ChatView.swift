//  ChatView.swift
//  FrontendAI
//
//

import SwiftUI
import SwiftData
import UIKit


// MARK: – Chat view
struct ChatView: View {
    let bot: Bot
    let botID: UUID
    let isPreviewSeeded: Bool

    let maxVisibleMessages = 300
    let topMessagesInset: CGFloat = 100
    let BottomMessagesInset: CGFloat = 70

    @State var messages: [ChatMessageModel] = []
    @State var showChatBotSheet = false
    @State var inputText: String = ""
    @State var currentHistory: ChatHistory?
    @State var isViewingHistory = false
    @State var isManualHistoryLoad = false
    @State var streamingReply: ChatMessageModel?
    @State var isGenerating = false
    @State var isThinking = false
    @State var generationTask: Task<Void, Never>? = nil

    @State var alertMessage: String?
    @State var showAlertBanner = false
    @State var showMissingAPIAlert = false
    @State var openSettings = false
    @State var showPersonaPickerForNewChat = false
    @State var didApplyInitialScrollPosition = false

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var apiManager: APIManager
    @Environment(PersonaManager.self) var personaManager
    @Query var allBots: [BotModel]
    @Query(sort: [SortDescriptor(\PersonaModel.name)]) var personas: [PersonaModel]
    @State var savedBotModel: BotModel?
    @AppStorage(ChatAppearanceStorageKeys.appearanceRevision) var chatAppearanceRevision = 0
    @AppStorage(ChatStreamingStorageKeys.chunkFlushIntervalMs) var streamChunkFlushIntervalMs = ChatStreamingDefaults.chunkFlushIntervalMs
    @State var activeChatAppearance = ChatAppearanceSnapshot.global()
    @State var chatWallpaperImage: UIImage?
    @State var chatWallpaperSmartGradient: ChatWallpaperSmartGradient?

    init(bot: Bot) {
        self.bot = bot
        self.botID = bot.id
        self.isPreviewSeeded = false
    }

    init(bot: Bot, previewMessages: [ChatMessageModel]) {
        self.bot = bot
        self.botID = bot.id
        self.isPreviewSeeded = true
        self._messages = State(initialValue: previewMessages)
    }

    var currentSystemPrompt: String {
        let personaPrompt = personaManager.activePersona?.systemPrompt ?? ""
        return [personaPrompt, bot.subtitle].filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    var body: some View {
        ZStack {
            chatBackground

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
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
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
                                .id(msg.id)
                            }
                        }
                        .padding(.top, topMessagesInset)
                        .padding(.bottom, BottomMessagesInset)
                        .padding(.horizontal, 15)
                        .padding(.bottom, 15)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onAppear {
                        scrollToLatestMessageIfNeeded(using: scrollProxy)
                    }
                    .onChange(of: messages.count) { _, _ in
                        scrollToLatestMessageIfNeeded(using: scrollProxy)
                    }
                }

                // Input bar
            }
            .environment(\.chatAppearance, activeChatAppearance)
            bottomInputMaterialFade
            VStack {
                ZStack {
                    ChatHeaderBar(
                        bot: bot,
                        botID: botID,
                        chatAppearanceID: currentChatAppearanceID,
                        showChatBotSheet: $showChatBotSheet,
                        isViewingHistory: $isViewingHistory,
                        onNewChat: startNewChatTapped
                    )
                    .background(alignment: .top) {
                        GeometryReader { geo in
                            Rectangle()
                                .fill(chatTopChromeFadeColor)
                                .frame(height: geo.safeAreaInsets.top + 70)
                                .mask(
                                    LinearGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: .black, location: 0),
                                            .init(color: .clear, location: 1)
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .ignoresSafeArea(edges: .top)
                        }
                    }
                }
                Spacer()
                ChatInputBar(
                    inputText: $inputText,
                    isGenerating: $isGenerating,
                    isThinking: $isThinking,
                    placeholder: "Message \(bot.name)",
                    onSend: sendMessage,
                    onStop: stopGeneration
                )
            }
            
        }
        .environment(\.bot, bot)
        .environment(\.personaManager, personaManager)
        .environment(\.isGenerating, isGenerating)
        .environment(\.showCursor, true)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            migrateLegacyWallpaperIfNeeded()
            refreshActiveAppearance()
            if !isManualHistoryLoad && !isPreviewSeeded {
                loadHistory()
            }
        }
        .onChange(of: chatAppearanceRevision) { _, _ in
            refreshActiveAppearance()
        }
        .onChange(of: currentChatAppearanceID) { _, _ in
            refreshActiveAppearance()
        }
        .onDisappear { saveChatHistory() }
        .sheet(isPresented: $openSettings) {
            APIManagerView(selectedServer: $apiManager.selectedServer)
                .environmentObject(apiManager)
        }
        .sheet(isPresented: $showPersonaPickerForNewChat) {
            NavigationStack {
                List {
                    Section("Choose persona for new chat") {
                        ForEach(personas) { persona in
                            Button {
                                personaManager.activePersona = persona
                                showPersonaPickerForNewChat = false
                                performStartNewChat()
                            } label: {
                                HStack(spacing: 12) {
                                    persona.avatarImage
                                        .resizable()
                                        .frame(width: 32, height: 32)
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(persona.name)
                                            .foregroundStyle(.primary)
                                        Text(persona.systemPrompt)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    if personaManager.activePersona?.id == persona.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .navigationTitle("New Chat Persona")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showPersonaPickerForNewChat = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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
}
