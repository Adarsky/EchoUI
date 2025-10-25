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
    let onNewChat: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.headline)
            }

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

            Spacer()

            Button { showChatBotSheet = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
            }
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
        .background(Color.gray.opacity(0.15))
    }
}
