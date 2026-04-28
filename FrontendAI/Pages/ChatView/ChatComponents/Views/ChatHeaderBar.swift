//
//  ChatHeaderBar.swift
//  FrontendAI
//
//  Created by macbook on 03.07.2025.
//

import SwiftUI

struct ChatHeaderBar: View {
    let bot: Bot
    let botID: UUID
    let chatAppearanceID: String?

    @Binding var showChatBotSheet: Bool
    @Binding var isViewingHistory: Bool
    @Namespace var chatBotSheetNamespace
    let onNewChat: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GlassEffectContainer {
            ZStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .frame(width: 32, height: 26)
                }
                .buttonStyle(.glass)
                .glassEffectUnion(id: 1, namespace: chatBotSheetNamespace)
                .frame(maxWidth: .infinity, alignment: .leading)

                Button { showChatBotSheet = true } label: {
                    HStack(spacing: 8) {
                        if let data = bot.avatarData,
                           let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: bot.avatarSystemName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                                .foregroundColor(bot.iconColor)
                        }
                        Text(bot.name)
                            .font(.headline)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: 400)
                .buttonStyle(.glass)
                .glassEffectUnion(id: 2, namespace: chatBotSheetNamespace)
                .sheet(isPresented: $showChatBotSheet) {
                    ChatBotSheetView(
                        bot: bot,
                        botID: botID,
                        chatAppearanceID: chatAppearanceID,
                        onNewChat: {
                            onNewChat()
                            showChatBotSheet = false
                        },
                        onViewHistory: {
                            showChatBotSheet = false
                            isViewingHistory = true
                        }
                    )
                }
            }
            .padding()
        }
    }
}

#Preview {
    ChatHeaderBar(
        bot: Bot(
            name: "Assistant",
            avatarSystemName: "circle.circle.fill",
            iconColor: .blue,
            subtitle: "Ready to help",
            date: "Today",
            isPinned: false,
            greeting: "Hi!",
            avatarData: nil
        ),
        botID: UUID(),
        chatAppearanceID: nil,
        showChatBotSheet: .constant(false),
        isViewingHistory: .constant(false),
        onNewChat: { }
    )
}
