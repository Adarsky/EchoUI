//
//  ChatAppearanceSettingsView.swift
//  FrontendAI
//

import SwiftUI
import PhotosUI
import UIKit

private struct WallpaperEditorDraftImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct WallpaperEditorResult {
    let image: UIImage
    let blurEnabled: Bool
    let blurRadius: Double
}

struct ChatAppearanceSettingsView: View {
    let botID: UUID?
    let botName: String?
    let chatID: String?

    @State private var selectedScope: ChatAppearanceScopeKind
    @State private var appearance: ChatAppearanceSnapshot
    @State private var selectedWallpaperItem: PhotosPickerItem?
    @State private var pendingWallpaperImage: WallpaperEditorDraftImage?
    @State private var wallpaperImage: UIImage?
    @State private var isLoadingWallpaper = false
    @State private var showResetConfirmation = false
    @State private var presets: [ChatAppearancePreset] = []
    @State private var presetName = ""

    private let previewUserMessage = "Can we tune this chat style so user bubbles stay readable while still looking clean across long replies and smaller screens?"
    private let previewBotMessage = "Yes. Adjust color, opacity, transparency, and width together. This longer sample helps you clearly see how the maxWidth slider changes wrapping and alignment in real conversations."

    init(botID: UUID? = nil, botName: String? = nil, chatID: String? = nil) {
        self.botID = botID
        self.botName = botName
        self.chatID = chatID

        let preferredScope = ChatAppearanceStore.preferredScope(botID: botID, chatID: chatID)
        _selectedScope = State(initialValue: preferredScope)
        _appearance = State(
            initialValue: ChatAppearanceStore.snapshot(
                for: preferredScope,
                botID: botID,
                chatID: chatID
            )
        )
    }

    var body: some View {
        Form {
            Section {
                if availableScopes.count > 1 {
                    Picker("Apply to", selection: $selectedScope) {
                        ForEach(availableScopes) { scope in
                            Text(scope.title).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                previewCard
            }

            Section("Message Bubbles") {
                bubbleControls(
                    title: "Your messages",
                    color: userBubbleColorBinding,
                    transparent: boolBinding(\.userBubbleTransparent)
                )

                bubbleControls(
                    title: "Bot messages",
                    color: botBubbleColorBinding,
                    transparent: boolBinding(\.botBubbleTransparent)
                )
            }

            Section("Message Width") {
                widthSlider(
                    title: "Your messages",
                    value: doubleBinding(\.userMessageBubbleWidthRatio),
                    displayedValue: appearance.clampedUserMessageBubbleWidthRatio
                )

                widthSlider(
                    title: "Bot messages",
                    value: doubleBinding(\.botMessageBubbleWidthRatio),
                    displayedValue: appearance.clampedBotMessageBubbleWidthRatio
                )
            }

            Section("Text Animation") {
                Toggle("Fade In Message Text", isOn: boolBinding(\.messageTextFadeInEnabled))
            }

            Section("Wallpaper") {
                PhotosPicker(selection: $selectedWallpaperItem, matching: .images, photoLibrary: .shared()) {
                    Label("Choose Wallpaper", systemImage: "photo.on.rectangle")
                }

                if isLoadingWallpaper {
                    HStack {
                        ProgressView()
                        Text("Loading photo")
                            .foregroundStyle(.secondary)
                    }
                }

                if wallpaperImage != nil {
                    Button {
                        if let wallpaperImage {
                            pendingWallpaperImage = WallpaperEditorDraftImage(image: wallpaperImage)
                        }
                    } label: {
                        Label("Edit Wallpaper", systemImage: "slider.horizontal.3")
                    }

                    Toggle("Blur Wallpaper", isOn: boolBinding(\.wallpaperBlurEnabled))

                    if appearance.wallpaperBlurEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Blur intensity")
                                Spacer()
                                Text("\(Int(appearance.clampedWallpaperBlurRadius))")
                                    .foregroundStyle(.secondary)
                            }
                            Slider(
                                value: doubleBinding(\.wallpaperBlurRadius),
                                in: ChatAppearanceDefaults.minWallpaperBlurRadius...ChatAppearanceDefaults.maxWallpaperBlurRadius,
                                step: 1
                            )
                        }
                    }

                    Button("Remove Wallpaper", role: .destructive) {
                        removeWallpaper()
                    }
                }
            }

            Section("Presets") {
                HStack {
                    TextField("Preset name", text: $presetName)
                        .textInputAutocapitalization(.words)

                    Button {
                        savePreset()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Save preset")
                }

                if presets.isEmpty {
                    Text("No saved presets")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(presets) { preset in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(preset.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                applyPreset(preset)
                            } label: {
                                Image(systemName: "checkmark.circle")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Apply preset")
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                presets = ChatAppearancePresetStore.delete(preset)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Chat Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") {
                    showResetConfirmation = true
                }
            }
        }
        .alert(resetConfirmationTitle, isPresented: $showResetConfirmation) {
            Button("Reset", role: .destructive) {
                resetAppearance()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(resetConfirmationMessage)
        }
        .sheet(item: $pendingWallpaperImage) { draft in
            WallpaperImageEditorView(
                image: draft.image,
                initialBlurEnabled: appearance.wallpaperBlurEnabled,
                initialBlurRadius: appearance.wallpaperBlurRadius,
                onCancel: {
                    pendingWallpaperImage = nil
                },
                onApply: { result in
                    pendingWallpaperImage = nil
                    applyWallpaper(result)
                }
            )
        }
        .onAppear {
            ChatAppearanceStore.migrateLegacyWallpaperIfNeeded()
            presets = ChatAppearancePresetStore.load()
            loadAppearanceForSelectedScope()
        }
        .onChange(of: selectedScope) { _, _ in
            loadAppearanceForSelectedScope()
        }
        .onChange(of: selectedWallpaperItem) { _, newItem in
            Task {
                await loadWallpaper(from: newItem)
            }
        }
    }

    private var availableScopes: [ChatAppearanceScopeKind] {
        ChatAppearanceStore.availableScopes(botID: botID, chatID: chatID)
    }

    private var previewCard: some View {
        ZStack {
            previewBackground

            VStack(spacing: 10) {
                HStack {
                    Spacer(minLength: 28)
                    previewBubble(text: previewUserMessage, isUser: true)
                }

                HStack {
                    previewBubble(text: previewBotMessage, isUser: false)
                    Spacer(minLength: 28)
                }
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 180)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var previewBackground: some View {
        GeometryReader { geo in
            if let wallpaperImage {
                Image(uiImage: wallpaperImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .blur(radius: appearance.wallpaperBlurEnabled ? CGFloat(appearance.clampedWallpaperBlurRadius) : 0)
                    .clipped()
                    .overlay(
                        Color.black.opacity(0.12)
                            .frame(width: geo.size.width, height: geo.size.height)
                    )
            } else {
                Color(.secondarySystemGroupedBackground)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }

    private func previewBubble(text: String, isUser: Bool) -> some View {
        Text(text)
            .font(.subheadline)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(
                maxWidth: 280 * (isUser ? appearance.clampedUserMessageBubbleWidthRatio : appearance.clampedBotMessageBubbleWidthRatio),
                alignment: isUser ? .trailing : .leading
            )
            .background(previewBubbleBackground(isUser: isUser))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.clear, lineWidth: 1)
            )
            .foregroundStyle(previewBubbleTextColor(isUser: isUser))
    }

    private func bubbleControls(
        title: String,
        color: Binding<Color>,
        transparent: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.subheadline.weight(.semibold))

            ColorPicker("Bubble color", selection: color, supportsOpacity: true)
            Toggle("Transparent", isOn: transparent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func widthSlider(
        title: String,
        value: Binding<Double>,
        displayedValue: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(displayedValue * 100))%")
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0.45...1.0, step: 0.05)
        }
    }

    private var userBubbleColorBinding: Binding<Color> {
        Binding(
            get: {
                ChatAppearanceColor.makeColor(
                    red: appearance.userBubbleRed,
                    green: appearance.userBubbleGreen,
                    blue: appearance.userBubbleBlue,
                    opacity: appearance.userBubbleOpacity
                )
            },
            set: { newColor in
                let rgba = ChatAppearanceColor.rgbaComponents(for: newColor)
                saveAppearance { snapshot in
                    snapshot.userBubbleRed = rgba.red
                    snapshot.userBubbleGreen = rgba.green
                    snapshot.userBubbleBlue = rgba.blue
                    snapshot.userBubbleOpacity = rgba.alpha
                }
            }
        )
    }

    private var botBubbleColorBinding: Binding<Color> {
        Binding(
            get: {
                ChatAppearanceColor.makeColor(
                    red: appearance.botBubbleRed,
                    green: appearance.botBubbleGreen,
                    blue: appearance.botBubbleBlue,
                    opacity: appearance.botBubbleOpacity
                )
            },
            set: { newColor in
                let rgba = ChatAppearanceColor.rgbaComponents(for: newColor)
                saveAppearance { snapshot in
                    snapshot.botBubbleRed = rgba.red
                    snapshot.botBubbleGreen = rgba.green
                    snapshot.botBubbleBlue = rgba.blue
                    snapshot.botBubbleOpacity = rgba.alpha
                }
            }
        )
    }

    private func boolBinding(_ keyPath: WritableKeyPath<ChatAppearanceSnapshot, Bool>) -> Binding<Bool> {
        Binding(
            get: { appearance[keyPath: keyPath] },
            set: { newValue in
                saveAppearance { snapshot in
                    snapshot[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func doubleBinding(_ keyPath: WritableKeyPath<ChatAppearanceSnapshot, Double>) -> Binding<Double> {
        Binding(
            get: { appearance[keyPath: keyPath] },
            set: { newValue in
                saveAppearance { snapshot in
                    snapshot[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func previewBubbleFillColor(isUser: Bool) -> Color {
        if isUser {
            return appearance.userBubbleTransparent ? .clear : userBubbleColorBinding.wrappedValue
        }
        return appearance.botBubbleTransparent ? .clear : botBubbleColorBinding.wrappedValue
    }

    @ViewBuilder
    private func previewBubbleBackground(isUser: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        shape.fill(previewBubbleFillColor(isUser: isUser))
        if !(isUser ? appearance.userBubbleTransparent : appearance.botBubbleTransparent) {
            shape.fill(.ultraThinMaterial)
        }
    }

    private func previewBubbleTextColor(isUser: Bool) -> Color {
        let isTransparent = isUser ? appearance.userBubbleTransparent : appearance.botBubbleTransparent
        if isTransparent { return .primary }
        return isUser ? .white : .primary
    }

    private var resetConfirmationTitle: String {
        "Reset \(selectedScope.title)?"
    }

    private var resetConfirmationMessage: String {
        switch selectedScope {
        case .global:
            return "This will reset the global chat style and remove the global wallpaper."
        case .bot:
            let name = botName ?? "this bot"
            return "This will remove the custom style for \(name) and fall back to the global style."
        case .chat:
            return "This will remove the custom style for this chat and fall back to the bot or global style."
        }
    }

    private func loadAppearanceForSelectedScope() {
        appearance = ChatAppearanceStore.snapshot(
            for: selectedScope,
            botID: botID,
            chatID: chatID
        )
        refreshWallpaperImage()
    }

    private func saveAppearance(_ mutation: (inout ChatAppearanceSnapshot) -> Void) {
        var next = appearance
        mutation(&next)
        next.userMessageBubbleWidthRatio = min(max(next.userMessageBubbleWidthRatio, 0.45), 1.0)
        next.botMessageBubbleWidthRatio = min(max(next.botMessageBubbleWidthRatio, 0.45), 1.0)
        next.wallpaperBlurRadius = next.clampedWallpaperBlurRadius
        saveAppearance(next)
    }

    private func saveAppearance(_ next: ChatAppearanceSnapshot) {
        appearance = next
        ChatAppearanceStore.save(
            next,
            to: selectedScope,
            botID: botID,
            chatID: chatID
        )
        refreshWallpaperImage()
    }

    private func resetAppearance() {
        ChatAppearanceStore.reset(
            scope: selectedScope,
            botID: botID,
            chatID: chatID
        )
        loadAppearanceForSelectedScope()
    }

    private func removeWallpaper() {
        if selectedScope == .global, !appearance.wallpaperPath.isEmpty {
            ChatWallpaperStore.removeWallpaper(at: appearance.wallpaperPath)
        }

        saveAppearance { snapshot in
            snapshot.wallpaperPath = ""
            snapshot.wallpaperBlurEnabled = ChatAppearanceDefaults.wallpaperBlurEnabled
            snapshot.wallpaperBlurRadius = ChatAppearanceDefaults.wallpaperBlurRadius
        }
        ChatWallpaperStore.clearLegacyBase64Storage()
    }

    private func refreshWallpaperImage() {
        wallpaperImage = ChatWallpaperStore.loadImage(from: appearance.wallpaperPath)
    }

    private func loadWallpaper(from item: PhotosPickerItem?) async {
        guard let item else { return }

        await MainActor.run {
            isLoadingWallpaper = true
        }

        let loadedImage: UIImage?
        if let data = try? await item.loadTransferable(type: Data.self) {
            loadedImage = await Task.detached(priority: .userInitiated) {
                UIImage(data: data)?.normalizedForWallpaperEditing()
            }.value
        } else {
            loadedImage = nil
        }

        await MainActor.run {
            isLoadingWallpaper = false
            selectedWallpaperItem = nil
            if let loadedImage {
                pendingWallpaperImage = WallpaperEditorDraftImage(image: loadedImage)
            }
        }
    }

    private func applyWallpaper(_ result: WallpaperEditorResult) {
        wallpaperImage = result.image

        Task {
            let savedPath = await Task.detached(priority: .userInitiated) {
                ChatWallpaperStore.saveImage(result.image)
            }.value

            await MainActor.run {
                guard let savedPath else { return }
                saveAppearance { snapshot in
                    snapshot.wallpaperPath = savedPath
                    snapshot.wallpaperBlurEnabled = result.blurEnabled
                    snapshot.wallpaperBlurRadius = result.blurRadius
                }
                wallpaperImage = result.image
            }
        }
    }

    private func savePreset() {
        presets = ChatAppearancePresetStore.savePreset(named: presetName, appearance: appearance)
        presetName = ""
    }

    private func applyPreset(_ preset: ChatAppearancePreset) {
        var next = preset.appearance
        if let copiedWallpaperPath = ChatWallpaperStore.copyWallpaper(from: preset.appearance.wallpaperPath) {
            next.wallpaperPath = copiedWallpaperPath
        }
        saveAppearance(next)
    }
}

private struct WallpaperImageEditorView: View {
    let onCancel: () -> Void
    let onApply: (WallpaperEditorResult) -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var workingImage: UIImage
    @State private var rotationQuarterTurns: Int = 0
    @State private var isMirrored: Bool = false
    @State private var zoomScale: CGFloat = 1
    @State private var committedZoomScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var committedOffset: CGSize = .zero
    @State private var canvasSize: CGSize = .zero
    @State private var blurEnabled: Bool
    @State private var blurRadius: Double

    init(
        image: UIImage,
        initialBlurEnabled: Bool,
        initialBlurRadius: Double,
        onCancel: @escaping () -> Void,
        onApply: @escaping (WallpaperEditorResult) -> Void
    ) {
        _workingImage = State(initialValue: image.normalizedForWallpaperEditing())
        _blurEnabled = State(initialValue: initialBlurEnabled)
        _blurRadius = State(initialValue: initialBlurRadius)
        self.onCancel = onCancel
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let resolvedCanvasSize = editorCanvasSize(in: proxy.size)

                VStack(spacing: 18) {
                    Spacer(minLength: 8)
                    editorCanvas(size: resolvedCanvasSize)
                    blurControls
                    transformControls
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 20)
            .background(editorBackground.ignoresSafeArea())
            .navigationTitle("Edit Wallpaper")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Use Wallpaper") {
                        onApply(
                            WallpaperEditorResult(
                                image: renderWallpaper(),
                                blurEnabled: blurEnabled,
                                blurRadius: ChatAppearanceDefaults.clampedWallpaperBlurRadius(blurRadius)
                            )
                        )
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func editorCanvas(size: CGSize) -> some View {
        let baseSize = baseDisplaySize(for: workingImage.size, canvasSize: size)

        return VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(canvasBackground)

                Image(uiImage: workingImage)
                    .resizable()
                    .frame(width: baseSize.width, height: baseSize.height)
                    .scaleEffect(x: isMirrored ? -1 : 1, y: 1, anchor: .center)
                    .rotationEffect(.degrees(Double(rotationQuarterTurns) * 90))
                    .scaleEffect(zoomScale, anchor: .center)
                    .offset(offset)
                    .blur(radius: blurEnabled ? CGFloat(ChatAppearanceDefaults.clampedWallpaperBlurRadius(blurRadius)) : 0)

                cropGuidesOverlay(size: size)
                    .frame(width: size.width, height: size.height)
                    .allowsHitTesting(false)
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(canvasBorder, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .gesture(dragGesture(canvasSize: size))
            .simultaneousGesture(magnificationGesture(canvasSize: size))
            .onAppear {
                canvasSize = size
            }
            .onChange(of: size) { _, newValue in
                canvasSize = newValue
                committedOffset = clampedOffset(committedOffset, canvasSize: newValue)
                offset = committedOffset
            }

            Text("Drag to reposition and pinch to zoom")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var blurControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Blur Wallpaper", isOn: $blurEnabled)

            if blurEnabled {
                HStack {
                    Text("Blur intensity")
                    Spacer()
                    Text("\(Int(ChatAppearanceDefaults.clampedWallpaperBlurRadius(blurRadius)))")
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: $blurRadius,
                    in: ChatAppearanceDefaults.minWallpaperBlurRadius...ChatAppearanceDefaults.maxWallpaperBlurRadius,
                    step: 1
                )
            }
        }
        .padding(.horizontal, 6)
    }

    private var transformControls: some View {
        HStack(spacing: 12) {
            controlButton(title: "Rotate Left", icon: "rotate.left") {
                rotate(clockwise: false)
            }
            controlButton(title: "Mirror", icon: "arrow.left.and.right.righttriangle.left.righttriangle.right") {
                mirror()
            }
            controlButton(title: "Reset", icon: "arrow.counterclockwise") {
                resetTransform()
            }
        }
    }

    private func controlButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(controlBackground)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func dragGesture(canvasSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let proposed = CGSize(
                    width: committedOffset.width + value.translation.width,
                    height: committedOffset.height + value.translation.height
                )
                offset = clampedOffset(proposed, canvasSize: canvasSize)
            }
            .onEnded { _ in
                committedOffset = clampedOffset(offset, canvasSize: canvasSize)
                offset = committedOffset
            }
    }

    private func magnificationGesture(canvasSize: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoomScale = min(max(committedZoomScale * value, 1), 6)
                offset = clampedOffset(offset, canvasSize: canvasSize)
            }
            .onEnded { _ in
                committedZoomScale = zoomScale
                committedOffset = clampedOffset(offset, canvasSize: canvasSize)
                offset = committedOffset
            }
    }

    private func cropGuidesOverlay(size: CGSize) -> some View {
        ZStack {
            Path { path in
                let thirdX = size.width / 3
                let thirdY = size.height / 3

                path.move(to: CGPoint(x: thirdX, y: 0))
                path.addLine(to: CGPoint(x: thirdX, y: size.height))
                path.move(to: CGPoint(x: thirdX * 2, y: 0))
                path.addLine(to: CGPoint(x: thirdX * 2, y: size.height))

                path.move(to: CGPoint(x: 0, y: thirdY))
                path.addLine(to: CGPoint(x: size.width, y: thirdY))
                path.move(to: CGPoint(x: 0, y: thirdY * 2))
                path.addLine(to: CGPoint(x: size.width, y: thirdY * 2))
            }
            .stroke(Color.white.opacity(0.25), lineWidth: 0.9)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.5), lineWidth: 1.2)
        }
    }

    private var editorBackground: Color {
        Color(.systemBackground)
    }

    private var canvasBackground: Color {
        colorScheme == .light ? Color(.secondarySystemGroupedBackground) : Color.white.opacity(0.06)
    }

    private var canvasBorder: Color {
        colorScheme == .light ? Color.primary.opacity(0.16) : Color.white.opacity(0.32)
    }

    private var controlBackground: Color {
        colorScheme == .light ? Color(.secondarySystemFill) : Color.white.opacity(0.1)
    }

    private func editorCanvasSize(in availableSize: CGSize) -> CGSize {
        let targetAspect: CGFloat = 9.0 / 16.0
        var width = min(availableSize.width - 40, 360)
        var height = width / targetAspect

        let maxHeight = max(280, availableSize.height * 0.56)
        if height > maxHeight {
            height = maxHeight
            width = height * targetAspect
        }

        return CGSize(width: max(220, width), height: max(300, height))
    }

    private func baseDisplaySize(for imageSize: CGSize, canvasSize: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return canvasSize
        }
        let scale = max(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    private func clampedOffset(_ proposed: CGSize, canvasSize: CGSize) -> CGSize {
        let baseSize = baseDisplaySize(for: workingImage.size, canvasSize: canvasSize)
        let orientedBase = orientedBaseSize(from: baseSize)
        let displayedSize = CGSize(
            width: orientedBase.width * zoomScale,
            height: orientedBase.height * zoomScale
        )
        let maxX = max(0, (displayedSize.width - canvasSize.width) / 2)
        let maxY = max(0, (displayedSize.height - canvasSize.height) / 2)
        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }

    private func renderWallpaper() -> UIImage {
        let sourceCanvasSize = canvasSize == .zero ? CGSize(width: 360, height: 640) : canvasSize
        let outputSize = CGSize(width: 1440, height: 2560)
        let baseSize = baseDisplaySize(for: workingImage.size, canvasSize: sourceCanvasSize)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: outputSize, format: format).image { context in
            let cg = context.cgContext
            let scale = outputSize.width / sourceCanvasSize.width

            cg.translateBy(x: outputSize.width / 2, y: outputSize.height / 2)
            cg.scaleBy(x: scale, y: scale)
            cg.translateBy(x: offset.width, y: offset.height)
            cg.scaleBy(x: zoomScale, y: zoomScale)
            cg.rotate(by: CGFloat(rotationQuarterTurns) * (.pi / 2))
            cg.scaleBy(x: isMirrored ? -1 : 1, y: 1)

            let drawRect = CGRect(
                x: -baseSize.width / 2,
                y: -baseSize.height / 2,
                width: baseSize.width,
                height: baseSize.height
            )
            workingImage.draw(in: drawRect)
        }
    }

    private func rotate(clockwise: Bool) {
        let sourceOffset = committedOffset
        rotationQuarterTurns = (rotationQuarterTurns + (clockwise ? 1 : 3)) % 4
        let rotatedOffset = CGSize(
            width: clockwise ? -sourceOffset.height : sourceOffset.height,
            height: clockwise ? sourceOffset.width : -sourceOffset.width
        )
        committedOffset = clampedOffset(rotatedOffset, canvasSize: canvasSize)
        offset = committedOffset
    }

    private func mirror() {
        isMirrored.toggle()
        let mirroredOffset = CGSize(width: -committedOffset.width, height: committedOffset.height)
        committedOffset = clampedOffset(mirroredOffset, canvasSize: canvasSize)
        offset = committedOffset
    }

    private func resetTransform() {
        rotationQuarterTurns = 0
        isMirrored = false
        zoomScale = 1
        committedZoomScale = 1
        offset = .zero
        committedOffset = .zero
        blurEnabled = false
        blurRadius = ChatAppearanceDefaults.wallpaperBlurRadius
    }

    private func orientedBaseSize(from baseSize: CGSize) -> CGSize {
        if rotationQuarterTurns.isMultiple(of: 2) {
            return baseSize
        }
        return CGSize(width: baseSize.height, height: baseSize.width)
    }
}

private extension UIImage {
    func normalizedForWallpaperEditing() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

#Preview {
    NavigationStack {
        ChatAppearanceSettingsView()
    }
}
