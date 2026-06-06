import SwiftUI

struct ChatBotSheetView: View {
    let bot: Bot
    let botID: UUID
    let chatAppearanceID: String?
    var currentChatTokenCount = 0
    var tokenWindow: Int?
    var personas: [PersonaModel] = []
    var currentPersona: PersonaModel?
    var globalPersona: PersonaModel?
    var hasPersonaOverride = false
    var onNewChat: () -> Void
    var onViewHistory: () -> Void
    var onSelectPersona: (PersonaModel?) -> Void = { _ in }
    var onUseGlobalPersona: () -> Void = { }

    @EnvironmentObject private var apiManager: APIManager
    @State private var isDescriptionExpandedManually = false
    @State private var selectedDetent: PresentationDetent = .medium
    @State private var isShowingChatViewSettings = false
    @State private var selectedProfileSection: ProfileSection = .about
    @Namespace private var headerNamespace

    private let collapsedDescriptionCharacterLimit = 140

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 18) {
                    headerSection
                    personaPickerSection
//                    currentModelSection
                    currentChatTokenSection
                    profileSectionPicker
                    profileContentSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity)
            }

            Divider()
            actionBar
        }
        .background(Color(.systemGroupedBackground))
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .onChange(of: bot.id) { _, _ in
            isDescriptionExpandedManually = false
            selectedProfileSection = .about
        }
        .sheet(isPresented: $isShowingChatViewSettings) {
            NavigationStack {
                SettingsChatView(
                    botID: botID,
                    botName: bot.name,
                    chatID: chatAppearanceID
                )
            }
        }
    }

    private var headerSection: some View {
        Group {
            if isLargeDetent {
                VStack(spacing: 16) {
                    avatarView
                        .frame(maxWidth: .infinity)

                    nameView(multilineAlignment: .center, maxWidth: .infinity, frameAlignment: .center)
                }
                .padding(.vertical, 8)
            } else {
                HStack(spacing: 14) {
                    avatarView

                    VStack(alignment: .leading, spacing: 5) {
                        nameView(multilineAlignment: .leading, maxWidth: nil, frameAlignment: .leading)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 0)
                }
                .padding(14)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isLargeDetent)
    }
    private var currentChatTokenSection: some View {
        ZStack {
            if let tokenUsageColor {
                LinearGradient(
                    gradient: Gradient(colors: [
                        tokenUsageColor.opacity(0.34),
                        tokenUsageColor.opacity(0.12),
                        Color.clear
                    ]),
                    startPoint: .trailing,
                    endPoint: .leading
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            HStack {
                Text("Current token usage:")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(tokenUsageText)
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .foregroundStyle(tokenUsageColor ?? .primary)
            }
            .padding(16)
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var currentModelSection: some View {
        VStack(alignment: .leading, spacing: 14) {
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

            Divider()

            InfoRow(
                icon: "cpu",
                title: "Model",
                value: selectedServer?.selectedModel.isEmpty == false ? selectedServer?.selectedModel ?? "" : "No model selected",
                valueColor: selectedServer == nil ? .secondary : .primary,
                lineLimit: 2
            )

            InfoRow(
                icon: "brain.head.profile",
                title: "Thinking",
                value: selectedThinkingEffort.displayName,
                valueColor: selectedServer?.type == .openrouter ? .primary : .secondary
            )
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var personaPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Persona", systemImage: "person.crop.circle")

            Menu {
                Button {
                    onUseGlobalPersona()
                } label: {
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
                        systemImage: hasPersonaOverride && currentPersona == nil ? "checkmark.circle.fill" : "person.crop.circle.badge.xmark"
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
                                systemImage: hasPersonaOverride && currentPersona?.id == persona.id ? "checkmark.circle.fill" : persona.avatarSystemName
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
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var apiIconView: some View {
        if let officialAPIIconName {
            Image(officialAPIIconName)
                .resizable()
                .scaledToFit()
                .padding(7)
                .frame(width: 34, height: 34)
                .background(Color(.tertiarySystemGroupedBackground), in: Circle())
        } else {
            Image(systemName: "server.rack")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(statusColor))
        }
    }

    private var profileSectionPicker: some View {
        Picker("Profile Section", selection: $selectedProfileSection) {
            ForEach(ProfileSection.allCases) { section in
                Label(section.title, systemImage: section.systemImage).tag(section)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var profileContentSection: some View {
        switch selectedProfileSection {
        case .about:
            contentCard(
                title: "About Character",
                systemImage: "person.text.rectangle",
                text: bot.subtitle,
                lineLimit: isDescriptionExpanded ? nil : 6,
                showsToggle: canToggleDescription && !isLargeDetent
            )
        case .greeting:
            contentCard(
                title: "Greeting",
                systemImage: "bubble.left.and.text.bubble.right",
                text: bot.greeting,
                lineLimit: nil,
                showsToggle: false
            )
        case .details:
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(title: "Character Details", systemImage: "sparkles")

                InfoRow(icon: "calendar", title: "Created", value: bot.date)
//                InfoRow(icon: bot.isPinned ? "pin.fill" : "pin", title: "Pinned", value: bot.isPinned ? "Yes" : "No")
//                InfoRow(icon: "person.crop.circle", title: "Avatar", value: bot.avatarData == nil ? bot.avatarSystemName : "Custom image")
                InfoRow(icon: "number", title: "Character ID", value: bot.id.uuidString, valueColor: .secondary, lineLimit: 2)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var actionBar: some View {
        VStack(spacing: 12) {
            Button(action: onNewChat) {
                Label {
                    Text("Create new Chat")
                        .fontWeight(.semibold)
                } icon: {
                    Image(systemName: "plus")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundColor(.white)
            }

            HStack(spacing: 12) {
                Button {
                    isShowingChatViewSettings = true
                } label: {
                    Label("View settings", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Button(action: onViewHistory) {
                    Label("History", systemImage: "clock.arrow.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.regularMaterial)
    }

    private var avatarView: some View {
        let avatarImageSize: CGFloat = isLargeDetent ? 112 : 64
        let avatarSymbolSize: CGFloat = isLargeDetent ? 82 : 44

        return ZStack {
            Circle()
                .fill(bot.iconColor.opacity(0.16))
                .frame(width: avatarImageSize + 12, height: avatarImageSize + 12)

            if let data = bot.avatarData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: avatarImageSize, height: avatarImageSize)
                    .clipShape(Circle())
            } else {
                Image(systemName: bot.avatarSystemName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: avatarSymbolSize, height: avatarSymbolSize)
                    .foregroundColor(bot.iconColor)
            }
        }
        .shadow(color: bot.iconColor.opacity(0.18), radius: 12, y: 6)
        .matchedGeometryEffect(id: "botAvatar", in: headerNamespace)
    }

    private func nameView(multilineAlignment: TextAlignment, maxWidth: CGFloat?, frameAlignment: Alignment) -> some View {
        Text(bot.name)
            .font(isLargeDetent ? .title.weight(.bold) : .title3.weight(.semibold))
            .multilineTextAlignment(multilineAlignment)
            .lineLimit(isLargeDetent ? 2 : 1)
            .minimumScaleFactor(isLargeDetent ? 0.9 : 0.8)
            .allowsTightening(true)
            .frame(maxWidth: maxWidth, alignment: frameAlignment)
            .matchedGeometryEffect(id: "botName", in: headerNamespace)
    }

    private func contentCard(
        title: String,
        systemImage: String,
        text: String,
        lineLimit: Int?,
        showsToggle: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: title, systemImage: systemImage)

            Text(renderedMarkdown(from: text))
                .font(.body)
                .lineSpacing(3)
                .lineLimit(lineLimit)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if showsToggle {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDescriptionExpandedManually.toggle()
                    }
                } label: {
                    Label(
                        isDescriptionExpandedManually ? "Show Less" : "Show More",
                        systemImage: isDescriptionExpandedManually ? "chevron.up" : "chevron.down"
                    )
                    .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sectionHeader(title: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
                .frame(width: 26, height: 26)
                .background(Color.accentColor.opacity(0.12), in: Circle())

            Text(title)
                .font(.headline)

            Spacer()
        }
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(selectedServer?.connectionStatus.displayName ?? "Offline")
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.12), in: Capsule())
    }

    private var selectedServer: APIServer? {
        apiManager.selectedServer
    }

    private var selectedThinkingEffort: APIThinkingEffort {
        guard let selectedServer else { return .defaultValue }
        return ChatThinkingEffortStore.resolvedEffort(botID: botID, server: selectedServer)
    }

    private var endpointHostText: String {
        guard let selectedServer else { return "Select a server in chat settings" }
        let normalizedBaseURL = selectedServer.type.normalizedBaseURL(selectedServer.baseURL)
        guard let url = URL(string: normalizedBaseURL), let host = url.host else {
            return selectedServer.type.displayName
        }
        return "\(selectedServer.type.displayName) * \(host)"
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

    private var tokenUsageText: String {
        guard let tokenWindow, tokenWindow > 0 else {
            return "\(currentChatTokenCount.formatted()) tokens"
        }

        return "\(currentChatTokenCount.formatted()) / \(tokenWindow.formatted())"
    }

    private var tokenUsageColor: Color? {
        guard let tokenWindow, tokenWindow > 0 else { return nil }

        let progress = Double(currentChatTokenCount) / Double(tokenWindow)
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
        let segmentProgress = segmentLength > 0 ? (clampedProgress - lower.progress) / segmentLength : 0

        return RGBColor.interpolate(from: lower.color, to: upper.color, progress: segmentProgress).swiftUIColor
    }

    private var personaSubtitle: String {
        if hasPersonaOverride {
            return currentPersona == nil ? "Saved for this chat without a persona" : "Saved for this chat"
        }

        return globalPersona == nil ? "Following global persona: none" : "Following global persona"
    }

    private var isLargeDetent: Bool {
        selectedDetent == .large
    }

    private var isDescriptionExpanded: Bool {
        isLargeDetent || isDescriptionExpandedManually
    }

    private var canToggleDescription: Bool {
        let normalized = normalizedMarkdownText(from: bot.subtitle).trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.count > collapsedDescriptionCharacterLimit || normalized.contains("\n")
    }

    private func renderedMarkdown(from text: String) -> AttributedString {
        let normalizedText = normalizedMarkdownText(from: text)
        let fallback = normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No content provided." : normalizedText
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )

        if let attributed = try? AttributedString(
            markdown: fallback,
            options: options
        ) {
            return attributed
        }
        return AttributedString(fallback)
    }

    private func normalizedMarkdownText(from text: String) -> String {
        text
            .replacingOccurrences(of: "/n/n", with: "\n\n")
            .replacingOccurrences(of: "/n", with: "\n")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
}

private enum ProfileSection: String, CaseIterable, Identifiable {
    case about
    case greeting
    case details

    var id: String { rawValue }

    var title: String {
        switch self {
        case .about:
            return "About"
        case .greeting:
            return "Greeting"
        case .details:
            return "Details"
        }
    }

    var systemImage: String {
        switch self {
        case .about:
            return "person.text.rectangle"
        case .greeting:
            return "bubble.left.and.text.bubble.right"
        case .details:
            return "sparkles"
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
    let apiManager = APIManager()
    apiManager.selectedServer = APIServer(
        name: "OpenRouter",
        baseURL: "https://openrouter.ai",
        selectedModel: "openai/gpt-4o-mini",
        type: .openrouter,
        connectionStatus: .online
    )

    return ChatBotSheetView(
        bot: Bot(
            name: "Luna",
            avatarSystemName: "livephoto",
            iconColor: .purple,
            subtitle: "Luna is your dreamy assistant, always ready to talk about the stars and the universe in poetic ways.",
            date: "Today",
            isPinned: false,
            greeting: "Hi! I'm Luna. Let's explore the stars together. ✨",
            avatarData: nil
        ),
        botID: UUID(),
        chatAppearanceID: nil,
        onNewChat: {},
        onViewHistory: {}
    )
    .environmentObject(apiManager)
}
