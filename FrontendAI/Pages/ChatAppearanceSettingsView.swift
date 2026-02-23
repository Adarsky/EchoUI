//
//  ChatAppearanceSettingsView.swift
//  FrontendAI
//

import SwiftUI
import PhotosUI
import UIKit

struct ChatAppearanceSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(ChatAppearanceStorageKeys.userBubbleRed) private var userBubbleRed = ChatAppearanceDefaults.userBubbleRed
    @AppStorage(ChatAppearanceStorageKeys.userBubbleGreen) private var userBubbleGreen = ChatAppearanceDefaults.userBubbleGreen
    @AppStorage(ChatAppearanceStorageKeys.userBubbleBlue) private var userBubbleBlue = ChatAppearanceDefaults.userBubbleBlue
    @AppStorage(ChatAppearanceStorageKeys.userBubbleOpacity) private var userBubbleOpacity = ChatAppearanceDefaults.userBubbleOpacity
    @AppStorage(ChatAppearanceStorageKeys.userBubbleTransparent) private var userBubbleTransparent = ChatAppearanceDefaults.userBubbleTransparent

    @AppStorage(ChatAppearanceStorageKeys.botBubbleRed) private var botBubbleRed = ChatAppearanceDefaults.botBubbleRed
    @AppStorage(ChatAppearanceStorageKeys.botBubbleGreen) private var botBubbleGreen = ChatAppearanceDefaults.botBubbleGreen
    @AppStorage(ChatAppearanceStorageKeys.botBubbleBlue) private var botBubbleBlue = ChatAppearanceDefaults.botBubbleBlue
    @AppStorage(ChatAppearanceStorageKeys.botBubbleOpacity) private var botBubbleOpacity = ChatAppearanceDefaults.botBubbleOpacity
    @AppStorage(ChatAppearanceStorageKeys.botBubbleTransparent) private var botBubbleTransparent = ChatAppearanceDefaults.botBubbleTransparent

    @AppStorage(ChatAppearanceStorageKeys.wallpaperPath) private var wallpaperPath = ""
    @AppStorage(ChatAppearanceStorageKeys.wallpaperBase64) private var legacyWallpaperBase64 = ""

    @State private var selectedWallpaperItem: PhotosPickerItem?
    @State private var wallpaperImage: UIImage?
    @Namespace private var navNamespace

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                topBar
                previewCard

                GroupBox {
                    VStack(spacing: 16) {
                        bubbleControls(
                            title: "Your messages",
                            color: userBubbleColorBinding,
                            transparent: $userBubbleTransparent
                        )

                        Divider()

                        bubbleControls(
                            title: "Bot messages",
                            color: botBubbleColorBinding,
                            transparent: $botBubbleTransparent
                        )
                    }
                } label: {
                    Label("Message Bubbles", systemImage: "ellipsis.message")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        PhotosPicker(selection: $selectedWallpaperItem, matching: .images) {
                            Label("Choose Wallpaper", systemImage: "photo.on.rectangle")
                        }
                        .buttonStyle(.borderedProminent)

                        if wallpaperImage != nil {
                            Button(role: .destructive) {
                                removeWallpaper()
                            } label: {
                                Label("Remove Wallpaper", systemImage: "trash")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Wallpaper", systemImage: "photo")
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            migrateLegacyWallpaperIfNeeded()
            refreshWallpaperImage()
        }
        .onChange(of: selectedWallpaperItem) { _, newItem in
            Task {
                await loadWallpaper(from: newItem)
            }
        }
        .onChange(of: wallpaperPath) { _, _ in
            refreshWallpaperImage()
        }
    }

    private var topBar: some View {
        GlassEffectContainer {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .imageScale(.large)
                }
                .buttonStyle(.glass)
                .glassEffectUnion(id: 1, namespace: navNamespace)

                Spacer()

                Text("Chat Appearance")
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassEffect(.regular)
                    .glassEffectUnion(id: 2, namespace: navNamespace)

                Spacer()

                Button {
                    resetAppearance()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .imageScale(.medium)
                }
                .buttonStyle(.glass)
                .glassEffectUnion(id: 1, namespace: navNamespace)
            }
        }
        .padding(.top, 8)
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Preview")
                .font(.headline)

            ZStack {
                previewBackground

                VStack(spacing: 10) {
                    HStack {
                        Spacer(minLength: 28)
                        previewBubble(
                            text: "Can we tune this chat style?",
                            isUser: true
                        )
                    }

                    HStack {
                        previewBubble(
                            text: "Yes. Changes appear here instantly.",
                            isUser: false
                        )
                        Spacer(minLength: 28)
                    }
                }
                .padding(12)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var previewBackground: some View {
        GeometryReader { geo in
            if let wallpaperImage {
                Image(uiImage: wallpaperImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .overlay(
                        Color.black.opacity(0.12)
                            .frame(width: geo.size.width, height: geo.size.height)
                    )
            } else {
                LinearGradient(
                    colors: [Color(.secondarySystemBackground), Color(.systemBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }

    private func previewBubble(text: String, isUser: Bool) -> some View {
        Text(text)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(previewBubbleFillColor(isUser: isUser))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(previewBubbleStrokeColor(isUser: isUser), lineWidth: 1)
            )
            .foregroundStyle(previewBubbleTextColor(isUser: isUser))
    }

    private func bubbleControls(
        title: String,
        color: Binding<Color>,
        transparent: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            ColorPicker("Bubble color", selection: color, supportsOpacity: true)
            Toggle("Transparent", isOn: transparent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var userBubbleColorBinding: Binding<Color> {
        Binding(
            get: {
                ChatAppearanceColor.makeColor(
                    red: userBubbleRed,
                    green: userBubbleGreen,
                    blue: userBubbleBlue,
                    opacity: userBubbleOpacity
                )
            },
            set: { newColor in
                let rgba = ChatAppearanceColor.rgbaComponents(for: newColor)
                userBubbleRed = rgba.red
                userBubbleGreen = rgba.green
                userBubbleBlue = rgba.blue
                userBubbleOpacity = rgba.alpha
            }
        )
    }

    private var botBubbleColorBinding: Binding<Color> {
        Binding(
            get: {
                ChatAppearanceColor.makeColor(
                    red: botBubbleRed,
                    green: botBubbleGreen,
                    blue: botBubbleBlue,
                    opacity: botBubbleOpacity
                )
            },
            set: { newColor in
                let rgba = ChatAppearanceColor.rgbaComponents(for: newColor)
                botBubbleRed = rgba.red
                botBubbleGreen = rgba.green
                botBubbleBlue = rgba.blue
                botBubbleOpacity = rgba.alpha
            }
        )
    }

    private func previewBubbleFillColor(isUser: Bool) -> Color {
        if isUser {
            return userBubbleTransparent ? .clear : userBubbleColorBinding.wrappedValue
        }
        return botBubbleTransparent ? .clear : botBubbleColorBinding.wrappedValue
    }

    private func previewBubbleStrokeColor(isUser: Bool) -> Color {
        let isTransparent = isUser ? userBubbleTransparent : botBubbleTransparent
        return isTransparent ? Color.primary.opacity(0.24) : .clear
    }

    private func previewBubbleTextColor(isUser: Bool) -> Color {
        let isTransparent = isUser ? userBubbleTransparent : botBubbleTransparent
        if isTransparent { return .primary }
        return isUser ? .white : .primary
    }

    private func resetAppearance() {
        userBubbleRed = ChatAppearanceDefaults.userBubbleRed
        userBubbleGreen = ChatAppearanceDefaults.userBubbleGreen
        userBubbleBlue = ChatAppearanceDefaults.userBubbleBlue
        userBubbleOpacity = ChatAppearanceDefaults.userBubbleOpacity
        userBubbleTransparent = ChatAppearanceDefaults.userBubbleTransparent

        botBubbleRed = ChatAppearanceDefaults.botBubbleRed
        botBubbleGreen = ChatAppearanceDefaults.botBubbleGreen
        botBubbleBlue = ChatAppearanceDefaults.botBubbleBlue
        botBubbleOpacity = ChatAppearanceDefaults.botBubbleOpacity
        botBubbleTransparent = ChatAppearanceDefaults.botBubbleTransparent

        removeWallpaper()
    }

    private func removeWallpaper() {
        ChatWallpaperStore.removeWallpaper(at: wallpaperPath)
        wallpaperPath = ""
        legacyWallpaperBase64 = ""
        refreshWallpaperImage()
    }

    private func migrateLegacyWallpaperIfNeeded() {
        ChatWallpaperStore.migrateLegacyBase64IfNeeded(
            path: &wallpaperPath,
            legacyBase64: &legacyWallpaperBase64
        )
    }

    private func refreshWallpaperImage() {
        wallpaperImage = ChatWallpaperStore.loadImage(from: wallpaperPath)
    }

    private func loadWallpaper(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        guard let savedPath = ChatWallpaperStore.saveFromRawImageData(data) else { return }

        await MainActor.run {
            let oldPath = wallpaperPath
            wallpaperPath = savedPath
            legacyWallpaperBase64 = ""
            if oldPath != savedPath {
                ChatWallpaperStore.removeWallpaper(at: oldPath)
            }
            refreshWallpaperImage()
        }
    }
}
