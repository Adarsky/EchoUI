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

    @Binding var showChatBotSheet: Bool
    @Binding var isViewingHistory: Bool
    @Namespace var chatBotSheetNamespace
    let onNewChat: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GlassEffectContainer {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.glass)
                .glassEffectUnion(id: 1, namespace: chatBotSheetNamespace)
                
                Spacer()
                
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
            }
                .frame(maxWidth: 300)
                .glassEffect(.clear)
                .glassEffectUnion(id: 2, namespace: chatBotSheetNamespace)
                
                Spacer()
                
                Button { showChatBotSheet = true } label: {
                    Image(systemName: "gearshape.fill")
                }
                .buttonStyle(.glass)
                .glassEffectUnion(id: 3, namespace: chatBotSheetNamespace)
                .sheet(isPresented: $showChatBotSheet) {
                    ChatBotSheetView(
                        bot: bot,
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
            avatarSystemName: "sparkles",
            iconColor: .blue,
            subtitle: "Ready to help",
            date: "Today",
            isPinned: false,
            greeting: "Hi!",
            avatarData: nil
        ),
        botID: UUID(),
        showChatBotSheet: .constant(false),
        isViewingHistory: .constant(false),
        onNewChat: { }
    )
}
