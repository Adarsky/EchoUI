import SwiftData
import SwiftUI

struct ChatBotProfileView: View {
    let bot: Bot
    let botModel: BotModel?
    let botID: UUID
    let chatAppearanceID: String?
    var currentChatTokenCount = 0
    var tokenWindow: Int?
    var personas: [PersonaModel] = []
    var currentPersona: PersonaModel?
    var globalPersona: PersonaModel?
    var hasPersonaOverride = false
    var onViewHistory: () -> Void = { }
    var onSelectPersona: (PersonaModel?) -> Void = { _ in }
    var onUseGlobalPersona: () -> Void = { }

    @EnvironmentObject private var apiManager: APIManager
    @Environment(\.modelContext) private var modelContext
    @State private var isPromptExpanded = false
    @State private var showSettingsSaveError = false
    @State private var settingsSaveErrorMessage = ""

    var body: some View {
        List {
                Section {
                    CharSection
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                Section {
                    currentChatTokenSection
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                Section("Character Persona") {
                    personaPickerSection
                }
                Section {
                    if selectedServer != nil {
                        currentAPIServerRow
                        currentAPIModelRow
                        currentAPIThinkingEffortRow
                    } else {
                        Label("Select an API server to configure this character.", systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Current API")
                } footer: {
                    if let selectedServer {
                        modelSettingsFooter(for: selectedServer)
                    }
                }
                Section("Chat settings") {
                    NavigationLink {
                        ChatAppearanceSettingsView(
                            botID: botID,
                            botName: bot.name,
                            chatID: chatAppearanceID
                        )
                    } label: {
                        Label("Chat Appearance", systemImage: "paintpalette")
                    }

                    NavigationLink {
                        TokenSpeedChangeView()
                    } label: {
                        Label("Token Speed", systemImage: "hare")
                    }

                    NavigationLink {
                        InputBarSettings()
                    } label: {
                        Label("Input Bar Appearance", systemImage: "arrow.up")
                    }
                }
                //                characterPromptSection
                //                characterDetailsSection
            }
        .scrollIndicators(.visible)
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("History", systemImage: "clock.arrow.circlepath", action: onViewHistory)
            }
        }
        .onChange(of: bot.id) { _, _ in
            isPromptExpanded = false
        }
        .alert("Could Not Save Character Settings", isPresented: $showSettingsSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(settingsSaveErrorMessage)
        }
    }

    private var CharSection: some View {
        ZStack {
            VStack(spacing: 14) {
                avatarView

                VStack(spacing: 4) {
                    Text(bot.name)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text("Character profile")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 26)
            .padding(.horizontal, 18)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(minHeight: 224)
        .clipShape(.rect(cornerRadius: 28))
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(bot.iconColor.opacity(0.18))
                .frame(width: 122, height: 122)

            if let data = bot.avatarData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 108, height: 108)
                    .clipShape(Circle())
            } else {
                Image(systemName: bot.avatarSystemName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 76, height: 76)
                    .foregroundStyle(bot.iconColor)
            }
        }
        .shadow(color: bot.iconColor.opacity(0.2), radius: 12, y: 6)
    }

    private var currentChatTokenSection: some View {
        CurrentTokenUsageBadge(
            tokenUsageText: tokenUsageText,
            emphasisColor: tokenUsageColor
        )
    }

    private var currentAPIServerRow: some View {
        HStack(spacing: 10) {
            apiIconView

            VStack(alignment: .leading, spacing: 2) {
                Text(selectedServer?.name ?? "No API selected")
                    .font(.headline)
                    .lineLimit(1)

                Text(endpointHostText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
            statusPill
        }
    }

    @ViewBuilder
    private var currentAPIModelRow: some View {
        if let selectedServer {
            NavigationLink {
                CharacterModelPickerView(
                    selectedModelOverride: modelOverrideBinding,
                    defaultModel: selectedServer.selectedModel,
                    availableModels: availableModelIDs
                )
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "cpu")
                        .foregroundStyle(.secondary)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Model")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(effectiveModelName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(botModel == nil)
        }
    }

    private var currentAPIThinkingEffortRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "brain.head.profile")
                .foregroundStyle(.secondary)
                .frame(width: 22)

            Text("Thinking Effort")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 10)

            Picker("Thinking effort", selection: thinkingEffortBinding) {
                ForEach(APIThinkingEffort.allCases) { effort in
                    Text(effort.pickerDisplayName)
                        .tag(effort)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .disabled(botModel == nil)
        }
    }

    @ViewBuilder
    private func modelSettingsFooter(for server: APIServer) -> some View {
        if selectedThinkingEffort == .on {
            Label("ON is intended for small or older models that expose a simple thinking toggle.", systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if selectedThinkingEffort == .max {
            Label("Be careful, not all models support this parameter.", systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(.orange)
        } else {
            Text("This setting applies to this character on the selected \(server.type.displayName) server.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
    private var personaPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Menu {
                Button(action: onUseGlobalPersona) {
                    Label(
                        globalPersona.map { "Use Global: \($0.name)" } ?? "Use Global: None",
                        systemImage: !hasPersonaOverride ? "checkmark.circle.fill" : "person.crop.circle"
                    )
                }

                Button {
                    onSelectPersona(nil)
                } label: {
                    Label(
                        "No Persona",
                        systemImage: hasPersonaOverride && currentPersona == nil
                            ? "checkmark.circle.fill"
                            : "person.crop.circle.badge.xmark"
                    )
                }

                if !personas.isEmpty {
                    Divider()

                    ForEach(personas) { persona in
                        Button {
                            onSelectPersona(persona)
                        } label: {
                            Label(
                                persona.name,
                                systemImage: hasPersonaOverride && currentPersona?.id == persona.id
                                    ? "checkmark.circle.fill"
                                    : "person.crop.circle"
                            )
                        }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    PersonaAvatarBadge(persona: currentPersona, size: 42)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(currentPersona?.name ?? "No Persona")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(personaSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }

            }
            .buttonStyle(.plain)
        }
    }

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Greeting", systemImage: "bubble.left.and.text.bubble.right")

            Text(renderedMarkdown(from: bot.greeting))
                .font(.body)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    private var characterPromptSection: some View {
        DisclosureGroup(isExpanded: $isPromptExpanded) {
            Divider()
                .padding(.vertical, 4)

            Text(renderedMarkdown(from: bot.subtitle))
                .font(.body)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Character Prompt")
                        .font(.headline)
                }
            } icon: {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .tint(.primary)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    private var characterDetailsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Details", systemImage: "sparkles")
            InfoRow(icon: "calendar", title: "Created", value: bot.date)
            InfoRow(
                icon: "number",
                title: "Character ID",
                value: bot.id.uuidString,
                valueColor: .secondary,
                lineLimit: 2
            )
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    @ViewBuilder
    private var apiIconView: some View {
        if let officialAPIIconName {
            Image(officialAPIIconName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.primary)
                .padding(7)
                .frame(width: 36, height: 36)
                .background(Color(.tertiarySystemGroupedBackground), in: Circle())
        } else {
            Image(systemName: "server.rack")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(statusColor, in: Circle())
        }
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(selectedServer?.connectionStatus.displayName ?? "Offline")
                .font(.caption.bold())
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.12), in: Capsule())
    }

    private func sectionHeader(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(.primary)
            .symbolRenderingMode(.hierarchical)
    }

    private var selectedServer: APIServer? {
        apiManager.selectedServer
    }

    private var modelOverrideBinding: Binding<String?> {
        Binding(
            get: {
                guard let selectedServer else { return nil }
                return CharacterGenerationSettings.modelOverride(
                    for: botModel,
                    server: selectedServer
                )
            },
            set: { newValue in
                guard let botModel, let selectedServer else { return }
                CharacterGenerationSettings.setModelOverride(
                    newValue,
                    for: botModel,
                    server: selectedServer
                )
                saveCharacterSettings()
            }
        )
    }

    private var thinkingEffortBinding: Binding<APIThinkingEffort> {
        Binding(
            get: {
                guard let selectedServer else { return .defaultValue }
                return CharacterGenerationSettings.resolvedThinkingEffort(
                    for: botModel,
                    botID: botID,
                    server: selectedServer
                )
            },
            set: { newValue in
                guard let botModel, let selectedServer else { return }
                CharacterGenerationSettings.setThinkingEffortOverride(
                    newValue,
                    for: botModel,
                    server: selectedServer
                )
                saveCharacterSettings()
            }
        )
    }

    private var selectedThinkingEffort: APIThinkingEffort {
        guard let selectedServer else { return .defaultValue }
        return CharacterGenerationSettings.resolvedThinkingEffort(
            for: botModel,
            botID: botID,
            server: selectedServer
        )
    }

    private var effectiveModelName: String {
        guard let selectedServer else { return "No model selected" }
        let model = CharacterGenerationSettings.resolvedModel(for: botModel, server: selectedServer)
        return model.isEmpty ? "No model selected" : model
    }

    private var modelSourceText: String {
        guard let selectedServer else { return "Server default" }
        return CharacterGenerationSettings.modelOverride(for: botModel, server: selectedServer) == nil
            ? "Server default"
            : "Character override"
    }

    private var availableModelIDs: [String] {
        guard let selectedServer else { return [] }

        var modelIDs = selectedServer.availableModels
        if selectedServer.type == .openrouter {
            modelIDs += APIModelCatalogCache
                .cachedOpenRouterModels(for: selectedServer.baseURL)?
                .map(\.id) ?? []
        } else {
            modelIDs += APIModelCatalogCache.cachedOpenAIModels(
                for: selectedServer.type,
                baseURL: selectedServer.baseURL
            ) ?? []
        }
        modelIDs.append(selectedServer.selectedModel)
        if let override = CharacterGenerationSettings.modelOverride(for: botModel, server: selectedServer) {
            modelIDs.append(override)
        }

        var seen = Set<String>()
        return modelIDs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private var endpointHostText: String {
        guard let selectedServer else { return "Select a server in chat settings" }
        let normalizedBaseURL = selectedServer.type.normalizedBaseURL(selectedServer.baseURL)
        guard let url = URL(string: normalizedBaseURL), let host = url.host else {
            return selectedServer.type.displayName
        }
        return "\(selectedServer.type.displayName) · \(host)"
    }

    private var officialAPIIconName: String? {
        guard let selectedServer, let host = normalizedAPIHost else { return nil }

        switch selectedServer.type {
        case .openai where host == "api.openai.com":
            return "AICompanyOpenAI"
        case .openrouter where host == "openrouter.ai" || host.hasSuffix(".openrouter.ai"):
            return "AICompanyOpenRouter"
        default:
            return nil
        }
    }

    private var normalizedAPIHost: String? {
        guard let selectedServer else { return nil }
        let normalizedBaseURL = selectedServer.type.normalizedBaseURL(selectedServer.baseURL)
        return URL(string: normalizedBaseURL)?.host?.lowercased()
    }

    private var statusColor: Color {
        switch selectedServer?.connectionStatus {
        case .online:
            return .green
        case .warning:
            return .orange
        case .offline, .none:
            return .red
        }
    }

    private var effectiveTokenWindow: Int? {
        guard let selectedServer, selectedServer.type == .openrouter else {
            return tokenWindow
        }

        let modelID = CharacterGenerationSettings
            .resolvedModel(for: botModel, server: selectedServer)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !modelID.isEmpty else { return tokenWindow }
        return APIModelCatalogCache
            .cachedOpenRouterModels(for: selectedServer.baseURL)?
            .first { $0.id.lowercased() == modelID }?
            .contextLength ?? tokenWindow
    }

    private var tokenUsageText: String {
        guard let effectiveTokenWindow, effectiveTokenWindow > 0 else {
            return "\(currentChatTokenCount.formatted()) tokens"
        }
        return "\(currentChatTokenCount.formatted()) / \(effectiveTokenWindow.formatted())"
    }

    private var tokenUsageColor: Color? {
        guard let effectiveTokenWindow, effectiveTokenWindow > 0 else { return nil }
        let progress = Double(currentChatTokenCount) / Double(effectiveTokenWindow)
        return Self.tokenUsageColor(for: progress)
    }

    private static func tokenUsageColor(for progress: Double) -> Color {
        let clampedProgress = max(0, progress)
        if clampedProgress <= 0.1 {
            return .green
        }
        if clampedProgress >= 1 {
            return Color(red: 0.86, green: 0.08, blue: 0.24)
        }

        let stops: [(progress: Double, color: RGBColor)] = [
            (0.1, RGBColor(red: 0.20, green: 0.72, blue: 0.32)),
            (0.5, RGBColor(red: 0.95, green: 0.72, blue: 0.16)),
            (0.85, RGBColor(red: 0.94, green: 0.38, blue: 0.12)),
            (1.0, RGBColor(red: 0.86, green: 0.08, blue: 0.24))
        ]

        guard let upperIndex = stops.firstIndex(where: { clampedProgress <= $0.progress }) else {
            return stops.last?.color.swiftUIColor ?? .red
        }

        let lowerIndex = max(0, upperIndex - 1)
        let lower = stops[lowerIndex]
        let upper = stops[upperIndex]
        let segmentLength = upper.progress - lower.progress
        let segmentProgress = segmentLength > 0
            ? (clampedProgress - lower.progress) / segmentLength
            : 0
        return RGBColor.interpolate(
            from: lower.color,
            to: upper.color,
            progress: segmentProgress
        ).swiftUIColor
    }

    private var personaSubtitle: String {
        if hasPersonaOverride {
            return currentPersona == nil ? "Saved for this chat without a persona" : "Saved for this chat"
        }
        return globalPersona == nil ? "Following global persona: none" : "Following global persona"
    }

    private func renderedMarkdown(from text: String) -> AttributedString {
        let normalizedText = CharacterTextFormatting.normalized(text)
        let fallback = normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "No content provided."
            : normalizedText
        let markdownText = CharacterTextFormatting.markdownPreservingLineBreaks(fallback)
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return (try? AttributedString(markdown: markdownText, options: options))
            ?? AttributedString(fallback)
    }

    private func saveCharacterSettings() {
        do {
            try modelContext.save()
        } catch {
            settingsSaveErrorMessage = error.localizedDescription
            showSettingsSaveError = true
        }
    }
}

private struct RGBColor {
    let red: Double
    let green: Double
    let blue: Double

    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue)
    }

    static func interpolate(from start: RGBColor, to end: RGBColor, progress: Double) -> RGBColor {
        let clampedProgress = min(max(progress, 0), 1)
        return RGBColor(
            red: start.red + (end.red - start.red) * clampedProgress,
            green: start.green + (end.green - start.green) * clampedProgress,
            blue: start.blue + (end.blue - start.blue) * clampedProgress
        )
    }
}

private struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    var valueColor: Color = .primary
    var lineLimit: Int = 1

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 22)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
                .lineLimit(lineLimit)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

private struct PersonaAvatarBadge: View {
    let persona: PersonaModel?
    var size: CGFloat

    var body: some View {
        Group {
            if let persona {
                if let data = persona.avatarData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: persona.avatarSystemName)
                        .resizable()
                        .scaledToFit()
                        .padding(size * 0.22)
                        .foregroundStyle(persona.iconColor)
                }
            } else {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.18)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .background(Color(.secondarySystemGroupedBackground), in: Circle())
        .clipShape(Circle())
    }
}

#Preview {
    let botID = UUID()
    let bot = Bot(
        id: botID,
        name: "Luna",
        avatarSystemName: "livephoto",
        iconColor: .purple,
        subtitle: "You are a dreamy assistant.\\nUse a warm, poetic voice.",
        date: "Today",
        isPinned: false,
        greeting: "Hi! I'm Luna.\\nLet's explore the stars together. ✨",
        avatarData: nil
    )
    let botModel = BotModel(
        id: botID,
        name: bot.name,
        subtitle: bot.subtitle,
        date: bot.date,
        avatarSystemName: bot.avatarSystemName,
        iconColorName: "purple",
        isPinned: false,
        greeting: bot.greeting
    )
    let apiManager = APIManager()
    apiManager.selectedServer = APIServer(
        name: "OpenRouter",
        baseURL: "https://openrouter.ai",
        selectedModel: "openai/gpt-4o-mini",
        availableModels: ["openai/gpt-4o-mini", "anthropic/claude-sonnet-4"],
        type: .openrouter,
        connectionStatus: .online
    )

    return NavigationStack {
        ChatBotProfileView(
            bot: bot,
            botModel: botModel,
            botID: botID,
            chatAppearanceID: nil
        )
    }
    .environmentObject(apiManager)
    .modelContainer(for: BotModel.self, inMemory: true)
}
