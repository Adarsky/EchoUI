//
//  MessageRow.swift
//  FrontendAI
//
//  Created by macbook on 30.05.2025.
//


import SwiftUI
import UIKit

struct MessageRow: View, Equatable {
    static func == (lhs: MessageRow, rhs: MessageRow) -> Bool {
        lhs.msg.id == rhs.msg.id &&
        lhs.msg.currentIndex == rhs.msg.currentIndex &&
        lhs.msg.content == rhs.msg.content
    }
    
    private var isStreaming: Bool {
        (msg.id == streamingReply?.id) && isGenerating
    }

    let msg: ChatView.ChatMessage
    @Binding var messages: [ChatView.ChatMessage]
    var regenerate: (ChatView.ChatMessage) -> Void
    var switchVariant: (UUID, Int) -> Void

    @Environment(\.showAvatars) private var showAvatars
    @Environment(\.bot) private var bot
    @Environment(\.personaManager) private var persona
    @Environment(\.streamingReply) private var streamingReply
    @Environment(\.isGenerating) private var isGenerating
    @Environment(\.showCursor) private var showCursor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if msg.isUser {
                userBubble
            } else {
                assistantBubble
            }
        }
        .contextMenu {
            Button("Copy") { UIPasteboard.general.string = msg.content }
            Button("Edit") {}
            Button("Delete", role: .destructive) {
                messages.removeAll { $0.id == msg.id }
            }
        }
    }

    @ViewBuilder
    private var assistantBubble: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if showAvatars { botAvatar }

            VStack(alignment: .leading, spacing: 6) {

                // ---------- BUBBLE ----------
                ZStack(alignment: .bottomLeading) {

                    // сам текст — анимируем opacity на КАЖДЫЙ chunk
                    Text(msg.content.isEmpty ? "‎" : msg.content)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                        .drawingGroup(opaque: !isStreaming)
                        .animation(.easeInOut(duration: 0.3),   // ⬅️ fade-in 120 мс
                                   value: msg.content)            // 🔑 триггер — любое изменение строки

                    // мигающий курсор только пока строка пуста
                    if isStreaming && msg.content.isEmpty {
                        Circle()
                            .fill(.gray)
                            .frame(width: 10, height: 10)
                            .scaleEffect(showCursor ? 1.0 : 1.4)
                            .opacity(showCursor ? 0.6 : 0.3)
                            .padding(EdgeInsets(top: 0, leading: 6, bottom: 6, trailing: 0))
                            .animation(.easeInOut(duration: 0.6)
                                       .repeatForever(autoreverses: true),
                                       value: showCursor)
                    }
                }

                controlsBar
            }
        }
    }



    @ViewBuilder
    private var userBubble: some View {
        HStack(spacing: 6) {
            Spacer()
            VStack(alignment: .trailing) {
                Text(msg.content)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                    .foregroundColor(.white)
            }
            if showAvatars {
                if let avatar = persona.activePersona?.avatarData,
                   let image = UIImage(data: avatar) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundColor(.gray)
                }
            }
        }
    }

    @ViewBuilder
    private var botAvatar: some View {
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
    }

    @ViewBuilder
    private var controlsBar: some View {
        HStack(spacing: 8) {
            Button {
                regenerate(msg)
            } label: {
                Image(systemName: "arrow.trianglehead.counterclockwise.rotate.90")
            }

            Button {
                switchVariant(msg.id, -1)
            } label: {
                Image(systemName: "arrow.left")
            }
            .disabled(msg.currentIndex == 0)

            Button {
                switchVariant(msg.id, 1)
            } label: {
                Image(systemName: "arrow.right")
            }
            .disabled(msg.currentIndex >= msg.allVariants.count - 1)
        }
    }
    
    struct TextChunkView: View {
        let chunk: String

        @State private var isVisible = false

        var body: some View {
            Text(chunk + " ") // добавим пробел вручную
                .opacity(isVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: isVisible)
                .onAppear { isVisible = true }
                .drawingGroup()
        }
    }

}
