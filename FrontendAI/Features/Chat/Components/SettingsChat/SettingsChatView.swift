//
//  SettingsChatView.swift
//  FrontendAI
//
//  Created by macbook on 10.05.2026.
//

import SwiftData
import SwiftUI

struct SettingsChatView: View {
    let botID: UUID?
    let botName: String?
    let chatID: String?

    @EnvironmentObject private var apiManager: APIManager
    @Environment(\.modelContext) private var modelContext
    @Query private var bots: [BotModel]

    init(botID: UUID? = nil, botName: String? = nil, chatID: String? = nil) {
        self.botID = botID
        self.botName = botName
        self.chatID = chatID
    }

    var body: some View {
        List {
            appearanceSettingsSection
            modelSettingsSection
            currentSettingsSection
        }
        .navigationTitle("Chat Settings")
        .navigationBarTitleDisplayMode(.inline)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(.systemBackground))
    }

    private var selectedServer: APIServer? {
        apiManager.selectedServer
    }

    private var selectedThinkingEffort: APIThinkingEffort {
        guard let selectedServer else { return .defaultValue }
        return CharacterGenerationSettings.resolvedThinkingEffort(
            for: currentBotModel,
            botID: botID,
            server: selectedServer
        )
    }

    private var thinkingEffortBinding: Binding<APIThinkingEffort> {
        Binding(
            get: { selectedThinkingEffort },
            set: { newValue in
                guard let selectedServer else { return }
                if botID != nil {
                    guard let currentBotModel else { return }
                    CharacterGenerationSettings.setThinkingEffortOverride(
                        newValue,
                        for: currentBotModel,
                        server: selectedServer
                    )
                } else {
                    selectedServer.thinkingEffort = newValue
                }
                try? modelContext.save()
            }
        )
    }

    private var currentBotModel: BotModel? {
        guard let botID else { return nil }
        return bots.first { $0.id == botID }
    }

    private var modelSettingsFooter: String {
        guard let server = selectedServer else {
            return "Select an API server before configuring model behavior."
        }
        guard server.type == .openrouter else {
            return "Thinking effort is only sent to OpenRouter-compatible servers."
        }
        guard botID != nil else {
            return "Without a character context, this updates the selected OpenRouter server default."
        }
        if selectedThinkingEffort == .max {
            return "Be careful, not all models support this parameter."
        }
        return "This thinking effort is saved for \(botName ?? "this character")."
    }

    private var selectedEndpointText: String {
        guard let selectedServer else { return "No endpoint selected" }
        let endpoint = selectedServer.type.endpoint(baseURL: selectedServer.baseURL, path: "chat/completions")
        return "\(selectedServer.type.displayName) * \(endpoint)"
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

    public var appearanceSettingsSection: some View {
        Section("Appearance Settings") {
            NavigationLink {
                ChatAppearanceSettingsView(
                    botID: botID,
                    botName: botName,
                    chatID: chatID
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
    }

    private var modelSettingsSection: some View {
        Section(
            header: Text("Model Settings"),
            footer: Text(modelSettingsFooter)
        ) {
            if let selectedServer, selectedServer.type == .openrouter {
                Picker("Thinking Effort", selection: thinkingEffortBinding) {
                    ForEach(APIThinkingEffort.allCases) { effort in
                        Text(effort.displayName).tag(effort)
                    }
                }
                .pickerStyle(.menu)
            } else if selectedServer != nil {
                Label("Thinking effort requires OpenRouter.", systemImage: "brain")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            NavigationLink {
                APIManagerView(
                    selectedServer: Binding(
                        get: { apiManager.selectedServer },
                        set: { apiManager.selectedServer = $0 }
                    )
                )
                .environmentObject(apiManager)
            } label: {
                Label(selectedServer == nil ? "Select API Server" : "API Servers", systemImage: "server.rack")
            }
            .presentationDetents([.large])
        }
    }

    private var currentSettingsSection: some View {
        Section("Current Settings") {
            if let selectedServer {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "cpu")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(Color.accentColor))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(selectedModelName)
                                .font(.headline)
                                .lineLimit(2)
                            Text(botName ?? "Global chat defaults")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    SettingsSummaryRow(title: "Thinking Effort", value: selectedThinkingEffort.displayName)
                    SettingsSummaryRow(title: "Selected API", value: selectedServer.name)
                    SettingsSummaryRow(title: "Endpoint", value: selectedEndpointText, lineLimit: 2)
                    SettingsSummaryRow(
                        title: "Status",
                        value: selectedServer.connectionStatus.displayName,
                        valueColor: statusColor
                    )
                }
                .padding(.vertical, 8)
            } else {
                Label("No API server selected", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var selectedModelName: String {
        guard let selectedServer else { return "No model selected" }
        let model = CharacterGenerationSettings.resolvedModel(
            for: currentBotModel,
            server: selectedServer
        )
        return model.isEmpty ? "No model selected" : model
    }
}

private struct SettingsSummaryRow: View {
    let title: String
    let value: String
    var valueColor: Color = .primary
    var lineLimit: Int = 1

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 108, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
                .lineLimit(lineLimit)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsChatView()
    }
    .environmentObject(APIManager())
}
