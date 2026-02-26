//
//  ChatAppearanceSettingsView.swift
//  FrontendAI
//

import SwiftUI
import PhotosUI
import UIKit

struct ChatAppearanceViewStyle {
    var navigationTitle = "Chat Appearance"
    var previewTitle = "Preview"

    var messageSectionTitle = "Message Bubbles"
    var messageSectionSystemImage = "ellipsis.message"
    var wallpaperSectionTitle = "Wallpaper"
    var wallpaperSectionSystemImage = "photo"

    var userMessageControlsTitle = "Your messages"
    var botMessageControlsTitle = "Bot messages"
    var bubbleColorPickerTitle = "Bubble color"
    var transparencyToggleTitle = "Transparent"

    var chooseWallpaperTitle = "Choose Wallpaper"
    var removeWallpaperTitle = "Remove Wallpaper"

    var previewHeight: CGFloat = 170

    var previewContainer: (AnyView) -> AnyView = { content in
        AnyView(
            content
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }

    var sectionContainer: (_ title: String, _ systemImage: String, _ content: AnyView) -> AnyView = { title, systemImage, content in
        AnyView(
            GroupBox {
                content
            } label: {
                Label(title, systemImage: systemImage)
            }
        )
    }

    static let `default` = ChatAppearanceViewStyle()
}

struct ChatAppearanceSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    private let style: ChatAppearanceViewStyle
    private let onBack: (() -> Void)?

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

    init(style: ChatAppearanceViewStyle = .default, onBack: (() -> Void)? = nil) {
        self.style = style
        self.onBack = onBack
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                topBar
                previewCard
                messageBubblesSection
                wallpaperSection
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

    private var messageBubblesSection: some View {
        style.sectionContainer(
            style.messageSectionTitle,
            style.messageSectionSystemImage,
            AnyView(
                VStack(spacing: 12) {
                    bubbleControls(
                        title: style.userMessageControlsTitle,
                        color: userBubbleColorBinding,
                        transparent: $userBubbleTransparent
                    )
                    .padding(.top, 8)

                    Divider()

                    bubbleControls(
                        title: style.botMessageControlsTitle,
                        color: botBubbleColorBinding,
                        transparent: $botBubbleTransparent
                    )
                    .padding(.top, 8)
                }
            )
        )
    }

    private var wallpaperSection: some View {
        style.sectionContainer(
            style.wallpaperSectionTitle,
            style.wallpaperSectionSystemImage,
            AnyView(
                VStack(alignment: .leading, spacing: 12) {
                    PhotosPicker(selection: $selectedWallpaperItem, matching: .images) {
                        Label(style.chooseWallpaperTitle, systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.glass)

                    if wallpaperImage != nil {
                        Button(role: .destructive) {
                            removeWallpaper()
                        } label: {
                            Label(style.removeWallpaperTitle, systemImage: "trash")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            )
        )
    }

    private var topBar: some View {
        GlassEffectContainer {
            HStack {
                Button {
                    handleBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .imageScale(.large)
                }
                .buttonStyle(.glass)
                .glassEffectUnion(id: 1, namespace: navNamespace)

                Spacer()

                Text(style.navigationTitle)
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
                .glassEffectUnion(id: 3, namespace: navNamespace)
            }
        }
        .padding(.top, 8)
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(style.previewTitle)
                .font(.headline)

            style.previewContainer(
                AnyView(
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
                    .frame(height: style.previewHeight)
                )
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
                    .fill(.ultraThinMaterial)
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

            ColorPicker(style.bubbleColorPickerTitle, selection: color, supportsOpacity: true)
            Toggle(style.transparencyToggleTitle, isOn: transparent)
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
        ChatWallpaperStore.normalizeStoredPath(&wallpaperPath)
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
            if !ChatWallpaperStore.referencesSameWallpaper(oldPath, savedPath) {
                ChatWallpaperStore.removeWallpaper(at: oldPath)
            }
            refreshWallpaperImage()
        }
    }

    private func handleBack() {
        if let onBack {
            onBack()
            return
        }
        if presentationMode.wrappedValue.isPresented {
            presentationMode.wrappedValue.dismiss()
        }
        dismiss()
    }
}

struct ChatAppearanceView: View {
    private let style: ChatAppearanceViewStyle

    init(style: ChatAppearanceViewStyle = .default) {
        self.style = style
    }

    var body: some View {
        ChatAppearanceSettingsView(style: style)
    }
}

#Preview {
    NavigationStack {
        ChatAppearanceSettingsView()
    }
}

#Preview("Custom Style") {
    NavigationStack {
        ChatAppearanceView(
            style: ChatAppearanceViewStyle(
                navigationTitle: "Theme Editor",
                previewTitle: "Live Canvas",
                messageSectionTitle: "Bubble Studio",
                messageSectionSystemImage: "paintpalette",
                wallpaperSectionTitle: "Backdrop",
                wallpaperSectionSystemImage: "photo",
                userMessageControlsTitle: "My Bubble",
                botMessageControlsTitle: "Assistant Bubble",
                bubbleColorPickerTitle: "Bubble Fill",
                transparencyToggleTitle: "Use Transparent",
                chooseWallpaperTitle: "Select Backdrop",
                removeWallpaperTitle: "Clear Backdrop",
                previewHeight: 190,
                previewContainer: { content in
                    AnyView(
                        content
                            .clipShape(Rectangle())
                            .overlay(
                                Rectangle()
                                    .stroke(Color.orange.opacity(0.45), lineWidth: 2)
                            )
                    )
                },
                sectionContainer: { title, systemImage, content in
                    AnyView(
                        VStack(alignment: .leading, spacing: 12) {
                            Label(title.uppercased(), systemImage: systemImage)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.orange)
                            content
                        }
                        .padding(14)
                        .background(Color.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    )
                }
            )
        )
    }
}
