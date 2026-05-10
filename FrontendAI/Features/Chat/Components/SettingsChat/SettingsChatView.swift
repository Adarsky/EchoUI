//
//  SettingsChatView.swift
//  FrontendAI
//
//  Created by macbook on 10.05.2026.
//

import SwiftUI

struct SettingsChatView: View {
    let botID: UUID?
    let botName: String?
    let chatID: String?

    @EnvironmentObject private var apiManager: APIManager

    init(botID: UUID? = nil, botName: String? = nil, chatID: String? = nil) {
        self.botID = botID
        self.botName = botName
        self.chatID = chatID
    }

    var body: some View {
        List {
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
                    Label("Input Bar Appearance", systemImage: "paperplane.fill")
                }
            }

            Section(
                header: Text("Model Settings"),
                footer: Text("Thinking effort is configured per OpenRouter API server.")
            ) {
                NavigationLink {
                    APIManagerView(
                        selectedServer: Binding(
                            get: { apiManager.selectedServer },
                            set: { apiManager.selectedServer = $0 }
                        )
                    )
                    .environmentObject(apiManager)
                } label: {
                    Label("Thinking Effort", systemImage: "brain")
                }
            }
        }
        .navigationTitle("Chat Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsChatView()
    }
    .environmentObject(APIManager())
}
