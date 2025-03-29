//
//  ChatBotSheetView.swift
//  FrontendAI
//
//  Created by macbook on 28.03.2025.
//


import SwiftUI

struct ChatBotSheetView: View {
    let bot: Bot
    var onNewChat: () -> Void
    var onViewHistory: () -> Void

    @Environment(\.dismiss) var dismiss
    @State private var isDescriptionExpanded = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            // Header
            HStack {
                Spacer()
                Text(bot.name)
                Spacer()
            }
            .padding(.horizontal)
            .bold(true)

            // Avatar
            if let data = bot.avatarData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .shadow(radius: 5)
            } else {
                Image(systemName: bot.avatarSystemName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(bot.iconColor)
            }

            // Greeting
            Text(bot.greeting)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Description
            Group {
                Text(bot.subtitle)
                    .font(.body)
                    .lineLimit(isDescriptionExpanded ? nil : 3)
                    .padding(.horizontal)

                Button(action: {
                    withAnimation {
                        isDescriptionExpanded.toggle()
                    }
                }) {
                    Text(isDescriptionExpanded ? "Show Less" : "Show More")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }

            Divider()

            // Buttons
            VStack(spacing: 12) {
                Button(action: onViewHistory) {
                    HStack {
                        Image(systemName: "clock")
                        Text("View Previous Chats")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }

                Button(action: onNewChat) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Start New Chat")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    ChatBotSheetView(
        bot: Bot(
            name: "Luna",
            avatarSystemName: "moon.fill",
            iconColor: .purple,
            subtitle: "Luna is your dreamy assistant, always ready to talk about the stars and the universe in poetic ways.",
            date: "Today",
            isPinned: false,
            greeting: "Hi! I'm Luna. Let's explore the stars together. ✨",
            avatarData: nil
        ),
        onNewChat: {},
        onViewHistory: {}
    )
}
