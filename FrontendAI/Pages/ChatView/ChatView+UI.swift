//  ChatView+UI.swift
//  FrontendAI

import SwiftUI
import UIKit

extension ChatView {
        @ViewBuilder
        var chatBackground: some View {
            GeometryReader { geo in
                if let chatWallpaperImage {
                    Image(uiImage: chatWallpaperImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .overlay(
                            Color.black.opacity(0.14)
                                .frame(width: geo.size.width, height: geo.size.height)
                        )
                } else {
                    LinearGradient(
                        colors: [
                            Color(.systemBackground),
                            Color(.systemGroupedBackground)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .ignoresSafeArea()
        }

        var bottomInputMaterialFade: some View {
            GeometryReader { geo in
                Rectangle()
                    .fill(.black)
                    .frame(height: geo.safeAreaInsets.bottom + 90)
                    .mask(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .black, location: 0),
                                .init(color: .clear, location: 1)
                            ]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea(edges: .bottom)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            .allowsHitTesting(false)
        }

        @MainActor
        func migrateLegacyWallpaperIfNeeded() {
            ChatWallpaperStore.migrateLegacyBase64IfNeeded(path: &chatWallpaperPath)
            ChatWallpaperStore.normalizeStoredPath(&chatWallpaperPath)
        }

        @MainActor
        func refreshWallpaperImage() {
            chatWallpaperImage = ChatWallpaperStore.loadImage(from: chatWallpaperPath)
        }

        // MARK: – Header helpers
        func startNewChatTapped() {
            if personas.isEmpty {
                performStartNewChat()
                return
            }
            showPersonaPickerForNewChat = true
        }

        func performStartNewChat() {
            saveChatHistory()
            messages.removeAll()
            currentHistory = nil
            messages.append(ChatMessageModel(content: bot.greeting, isUser: false))
        }

        @MainActor
        func scrollToLatestMessageIfNeeded(using proxy: ScrollViewProxy) {
            guard !didApplyInitialScrollPosition else { return }
            guard let latestMessageID = messages.last?.id else { return }

            DispatchQueue.main.async {
                proxy.scrollTo(latestMessageID, anchor: .bottom)
                didApplyInitialScrollPosition = true
            }
        }
}
