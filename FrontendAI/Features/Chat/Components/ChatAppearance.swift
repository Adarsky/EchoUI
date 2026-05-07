import SwiftUI
import UIKit
import Foundation

enum ChatAppearanceStorageKeys {
    static let userBubbleRed = "chatUserBubbleRed"
    static let userBubbleGreen = "chatUserBubbleGreen"
    static let userBubbleBlue = "chatUserBubbleBlue"
    static let userBubbleOpacity = "chatUserBubbleOpacity"
    static let userBubbleTransparent = "chatUserBubbleTransparent"

    static let botBubbleRed = "chatBotBubbleRed"
    static let botBubbleGreen = "chatBotBubbleGreen"
    static let botBubbleBlue = "chatBotBubbleBlue"
    static let botBubbleOpacity = "chatBotBubbleOpacity"
    static let botBubbleTransparent = "chatBotBubbleTransparent"
    static let userMessageBubbleWidthRatio = "chatUserMessageBubbleWidthRatio"
    static let botMessageBubbleWidthRatio = "chatBotMessageBubbleWidthRatio"
    static let messageBubbleWidthRatio = "chatMessageBubbleWidthRatio"

    static let wallpaperPath = "chatWallpaperPath"
    static let wallpaperBase64 = "chatWallpaperBase64" // legacy key for migration
    static let wallpaperBlurEnabled = "chatWallpaperBlurEnabled"
    static let wallpaperBlurRadius = "chatWallpaperBlurRadius"
    static let messageTextFadeInEnabled = "chatMessageTextFadeInEnabled"
    static let appearanceRevision = "chatAppearanceRevision"
    static let appearancePresets = "chatAppearancePresets"
    static let botAppearancePrefix = "chatBotAppearance."
    static let chatAppearancePrefix = "chatSessionAppearance."
}

enum ChatAppearanceDefaults {
    static let userBubbleRed: Double = 0.0
    static let userBubbleGreen: Double = 0.478
    static let userBubbleBlue: Double = 1.0
    static let userBubbleOpacity: Double = 0.8
    static let userBubbleTransparent: Bool = false

    static let botBubbleRed: Double = 0.557
    static let botBubbleGreen: Double = 0.557
    static let botBubbleBlue: Double = 0.576
    static let botBubbleOpacity: Double = 0.2
    static let botBubbleTransparent: Bool = false
    static let userMessageBubbleWidthRatio: Double = 0.82
    static let botMessageBubbleWidthRatio: Double = 0.82
    static let messageBubbleWidthRatio: Double = 0.82
    static let wallpaperBlurEnabled: Bool = false
    static let wallpaperBlurRadius: Double = 8.0
    static let minWallpaperBlurRadius: Double = 0.0
    static let maxWallpaperBlurRadius: Double = 24.0
    static let messageTextFadeInEnabled: Bool = true

    static func clampedWallpaperBlurRadius(_ value: Double) -> Double {
        min(max(value, minWallpaperBlurRadius), maxWallpaperBlurRadius)
    }
}

enum ChatStreamingStorageKeys {
    static let chunkFlushIntervalMs = "llmStreamChunkFlushIntervalMs"
}

enum ChatStreamingDefaults {
    static let chunkMaxChars: Int = 1200
    static let chunkFlushIntervalMs: Double = 33

    static let minChunkFlushIntervalMs: Double = 10
    static let maxChunkFlushIntervalMs: Double = 1000

    static func clampedChunkFlushIntervalMs(_ value: Double) -> Double {
        min(max(value, minChunkFlushIntervalMs), maxChunkFlushIntervalMs)
    }
}

enum ChatAppearanceColor {
    static func makeColor(red: Double, green: Double, blue: Double, opacity: Double) -> Color {
        Color(red: clamp(red), green: clamp(green), blue: clamp(blue), opacity: clamp(opacity))
    }

    static func rgbaComponents(for color: Color) -> (red: Double, green: Double, blue: Double, alpha: Double) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return (
                ChatAppearanceDefaults.userBubbleRed,
                ChatAppearanceDefaults.userBubbleGreen,
                ChatAppearanceDefaults.userBubbleBlue,
                ChatAppearanceDefaults.userBubbleOpacity
            )
        }

        return (Double(red), Double(green), Double(blue), Double(alpha))
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

struct ChatAppearanceSnapshot: Codable, Equatable {
    var userBubbleRed: Double
    var userBubbleGreen: Double
    var userBubbleBlue: Double
    var userBubbleOpacity: Double
    var userBubbleTransparent: Bool

    var botBubbleRed: Double
    var botBubbleGreen: Double
    var botBubbleBlue: Double
    var botBubbleOpacity: Double
    var botBubbleTransparent: Bool

    var userMessageBubbleWidthRatio: Double
    var botMessageBubbleWidthRatio: Double
    var wallpaperPath: String
    var wallpaperBlurEnabled: Bool
    var wallpaperBlurRadius: Double
    var messageTextFadeInEnabled: Bool

    static var defaultValue: ChatAppearanceSnapshot {
        ChatAppearanceSnapshot(
            userBubbleRed: ChatAppearanceDefaults.userBubbleRed,
            userBubbleGreen: ChatAppearanceDefaults.userBubbleGreen,
            userBubbleBlue: ChatAppearanceDefaults.userBubbleBlue,
            userBubbleOpacity: ChatAppearanceDefaults.userBubbleOpacity,
            userBubbleTransparent: ChatAppearanceDefaults.userBubbleTransparent,
            botBubbleRed: ChatAppearanceDefaults.botBubbleRed,
            botBubbleGreen: ChatAppearanceDefaults.botBubbleGreen,
            botBubbleBlue: ChatAppearanceDefaults.botBubbleBlue,
            botBubbleOpacity: ChatAppearanceDefaults.botBubbleOpacity,
            botBubbleTransparent: ChatAppearanceDefaults.botBubbleTransparent,
            userMessageBubbleWidthRatio: ChatAppearanceDefaults.userMessageBubbleWidthRatio,
            botMessageBubbleWidthRatio: ChatAppearanceDefaults.botMessageBubbleWidthRatio,
            wallpaperPath: "",
            wallpaperBlurEnabled: ChatAppearanceDefaults.wallpaperBlurEnabled,
            wallpaperBlurRadius: ChatAppearanceDefaults.wallpaperBlurRadius,
            messageTextFadeInEnabled: ChatAppearanceDefaults.messageTextFadeInEnabled
        )
    }

    enum CodingKeys: String, CodingKey {
        case userBubbleRed
        case userBubbleGreen
        case userBubbleBlue
        case userBubbleOpacity
        case userBubbleTransparent
        case botBubbleRed
        case botBubbleGreen
        case botBubbleBlue
        case botBubbleOpacity
        case botBubbleTransparent
        case userMessageBubbleWidthRatio
        case botMessageBubbleWidthRatio
        case wallpaperPath
        case wallpaperBlurEnabled
        case wallpaperBlurRadius
        case messageTextFadeInEnabled
    }

    init(
        userBubbleRed: Double,
        userBubbleGreen: Double,
        userBubbleBlue: Double,
        userBubbleOpacity: Double,
        userBubbleTransparent: Bool,
        botBubbleRed: Double,
        botBubbleGreen: Double,
        botBubbleBlue: Double,
        botBubbleOpacity: Double,
        botBubbleTransparent: Bool,
        userMessageBubbleWidthRatio: Double,
        botMessageBubbleWidthRatio: Double,
        wallpaperPath: String,
        wallpaperBlurEnabled: Bool,
        wallpaperBlurRadius: Double,
        messageTextFadeInEnabled: Bool
    ) {
        self.userBubbleRed = userBubbleRed
        self.userBubbleGreen = userBubbleGreen
        self.userBubbleBlue = userBubbleBlue
        self.userBubbleOpacity = userBubbleOpacity
        self.userBubbleTransparent = userBubbleTransparent
        self.botBubbleRed = botBubbleRed
        self.botBubbleGreen = botBubbleGreen
        self.botBubbleBlue = botBubbleBlue
        self.botBubbleOpacity = botBubbleOpacity
        self.botBubbleTransparent = botBubbleTransparent
        self.userMessageBubbleWidthRatio = userMessageBubbleWidthRatio
        self.botMessageBubbleWidthRatio = botMessageBubbleWidthRatio
        self.wallpaperPath = wallpaperPath
        self.wallpaperBlurEnabled = wallpaperBlurEnabled
        self.wallpaperBlurRadius = wallpaperBlurRadius
        self.messageTextFadeInEnabled = messageTextFadeInEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            userBubbleRed: try container.decode(Double.self, forKey: .userBubbleRed),
            userBubbleGreen: try container.decode(Double.self, forKey: .userBubbleGreen),
            userBubbleBlue: try container.decode(Double.self, forKey: .userBubbleBlue),
            userBubbleOpacity: try container.decode(Double.self, forKey: .userBubbleOpacity),
            userBubbleTransparent: try container.decode(Bool.self, forKey: .userBubbleTransparent),
            botBubbleRed: try container.decode(Double.self, forKey: .botBubbleRed),
            botBubbleGreen: try container.decode(Double.self, forKey: .botBubbleGreen),
            botBubbleBlue: try container.decode(Double.self, forKey: .botBubbleBlue),
            botBubbleOpacity: try container.decode(Double.self, forKey: .botBubbleOpacity),
            botBubbleTransparent: try container.decode(Bool.self, forKey: .botBubbleTransparent),
            userMessageBubbleWidthRatio: try container.decode(Double.self, forKey: .userMessageBubbleWidthRatio),
            botMessageBubbleWidthRatio: try container.decode(Double.self, forKey: .botMessageBubbleWidthRatio),
            wallpaperPath: try container.decode(String.self, forKey: .wallpaperPath),
            wallpaperBlurEnabled: try container.decode(Bool.self, forKey: .wallpaperBlurEnabled),
            wallpaperBlurRadius: try container.decode(Double.self, forKey: .wallpaperBlurRadius),
            messageTextFadeInEnabled: try container.decodeIfPresent(Bool.self, forKey: .messageTextFadeInEnabled) ?? ChatAppearanceDefaults.messageTextFadeInEnabled
        )
    }

    static func global(defaults: UserDefaults = .standard) -> ChatAppearanceSnapshot {
        ChatAppearanceSnapshot(
            userBubbleRed: double(defaults, key: ChatAppearanceStorageKeys.userBubbleRed, fallback: ChatAppearanceDefaults.userBubbleRed),
            userBubbleGreen: double(defaults, key: ChatAppearanceStorageKeys.userBubbleGreen, fallback: ChatAppearanceDefaults.userBubbleGreen),
            userBubbleBlue: double(defaults, key: ChatAppearanceStorageKeys.userBubbleBlue, fallback: ChatAppearanceDefaults.userBubbleBlue),
            userBubbleOpacity: double(defaults, key: ChatAppearanceStorageKeys.userBubbleOpacity, fallback: ChatAppearanceDefaults.userBubbleOpacity),
            userBubbleTransparent: bool(defaults, key: ChatAppearanceStorageKeys.userBubbleTransparent, fallback: ChatAppearanceDefaults.userBubbleTransparent),
            botBubbleRed: double(defaults, key: ChatAppearanceStorageKeys.botBubbleRed, fallback: ChatAppearanceDefaults.botBubbleRed),
            botBubbleGreen: double(defaults, key: ChatAppearanceStorageKeys.botBubbleGreen, fallback: ChatAppearanceDefaults.botBubbleGreen),
            botBubbleBlue: double(defaults, key: ChatAppearanceStorageKeys.botBubbleBlue, fallback: ChatAppearanceDefaults.botBubbleBlue),
            botBubbleOpacity: double(defaults, key: ChatAppearanceStorageKeys.botBubbleOpacity, fallback: ChatAppearanceDefaults.botBubbleOpacity),
            botBubbleTransparent: bool(defaults, key: ChatAppearanceStorageKeys.botBubbleTransparent, fallback: ChatAppearanceDefaults.botBubbleTransparent),
            userMessageBubbleWidthRatio: double(defaults, key: ChatAppearanceStorageKeys.userMessageBubbleWidthRatio, fallback: ChatAppearanceDefaults.userMessageBubbleWidthRatio),
            botMessageBubbleWidthRatio: double(defaults, key: ChatAppearanceStorageKeys.botMessageBubbleWidthRatio, fallback: ChatAppearanceDefaults.botMessageBubbleWidthRatio),
            wallpaperPath: defaults.string(forKey: ChatAppearanceStorageKeys.wallpaperPath) ?? "",
            wallpaperBlurEnabled: bool(defaults, key: ChatAppearanceStorageKeys.wallpaperBlurEnabled, fallback: ChatAppearanceDefaults.wallpaperBlurEnabled),
            wallpaperBlurRadius: double(defaults, key: ChatAppearanceStorageKeys.wallpaperBlurRadius, fallback: ChatAppearanceDefaults.wallpaperBlurRadius),
            messageTextFadeInEnabled: bool(defaults, key: ChatAppearanceStorageKeys.messageTextFadeInEnabled, fallback: ChatAppearanceDefaults.messageTextFadeInEnabled)
        )
    }

    func writeToGlobal(defaults: UserDefaults = .standard) {
        defaults.set(userBubbleRed, forKey: ChatAppearanceStorageKeys.userBubbleRed)
        defaults.set(userBubbleGreen, forKey: ChatAppearanceStorageKeys.userBubbleGreen)
        defaults.set(userBubbleBlue, forKey: ChatAppearanceStorageKeys.userBubbleBlue)
        defaults.set(userBubbleOpacity, forKey: ChatAppearanceStorageKeys.userBubbleOpacity)
        defaults.set(userBubbleTransparent, forKey: ChatAppearanceStorageKeys.userBubbleTransparent)

        defaults.set(botBubbleRed, forKey: ChatAppearanceStorageKeys.botBubbleRed)
        defaults.set(botBubbleGreen, forKey: ChatAppearanceStorageKeys.botBubbleGreen)
        defaults.set(botBubbleBlue, forKey: ChatAppearanceStorageKeys.botBubbleBlue)
        defaults.set(botBubbleOpacity, forKey: ChatAppearanceStorageKeys.botBubbleOpacity)
        defaults.set(botBubbleTransparent, forKey: ChatAppearanceStorageKeys.botBubbleTransparent)

        defaults.set(userMessageBubbleWidthRatio, forKey: ChatAppearanceStorageKeys.userMessageBubbleWidthRatio)
        defaults.set(botMessageBubbleWidthRatio, forKey: ChatAppearanceStorageKeys.botMessageBubbleWidthRatio)
        defaults.set(wallpaperPath, forKey: ChatAppearanceStorageKeys.wallpaperPath)
        defaults.set(wallpaperBlurEnabled, forKey: ChatAppearanceStorageKeys.wallpaperBlurEnabled)
        defaults.set(clampedWallpaperBlurRadius, forKey: ChatAppearanceStorageKeys.wallpaperBlurRadius)
        defaults.set(messageTextFadeInEnabled, forKey: ChatAppearanceStorageKeys.messageTextFadeInEnabled)
    }

    var clampedUserMessageBubbleWidthRatio: Double {
        min(max(userMessageBubbleWidthRatio, 0.45), 1.0)
    }

    var clampedBotMessageBubbleWidthRatio: Double {
        min(max(botMessageBubbleWidthRatio, 0.45), 1.0)
    }

    var clampedWallpaperBlurRadius: Double {
        ChatAppearanceDefaults.clampedWallpaperBlurRadius(wallpaperBlurRadius)
    }

    private static func double(_ defaults: UserDefaults, key: String, fallback: Double) -> Double {
        defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
    }

    private static func bool(_ defaults: UserDefaults, key: String, fallback: Bool) -> Bool {
        defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
    }
}

private struct ChatAppearanceEnvironmentKey: EnvironmentKey {
    static let defaultValue = ChatAppearanceSnapshot.global()
}

extension EnvironmentValues {
    var chatAppearance: ChatAppearanceSnapshot {
        get { self[ChatAppearanceEnvironmentKey.self] }
        set { self[ChatAppearanceEnvironmentKey.self] = newValue }
    }
}

enum ChatAppearanceScopeKind: String, CaseIterable, Identifiable {
    case global
    case bot
    case chat

    var id: String { rawValue }

    var title: String {
        switch self {
        case .global:
            return "Global"
        case .bot:
            return "This Bot"
        case .chat:
            return "This Chat"
        }
    }
}

struct ChatAppearancePreset: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var createdAt: Date
    var appearance: ChatAppearanceSnapshot

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        appearance: ChatAppearanceSnapshot
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.appearance = appearance
    }
}

enum ChatAppearanceStore {
    static func availableScopes(botID: UUID?, chatID: String?) -> [ChatAppearanceScopeKind] {
        var scopes: [ChatAppearanceScopeKind] = [.global]
        if botID != nil {
            scopes.append(.bot)
        }
        if chatID != nil {
            scopes.append(.chat)
        }
        return scopes
    }

    static func preferredScope(botID: UUID?, chatID: String?) -> ChatAppearanceScopeKind {
        if chatID != nil { return .chat }
        if botID != nil { return .bot }
        return .global
    }

    static func chatID(botID: UUID, firstMessageID: UUID?) -> String? {
        guard let firstMessageID else { return nil }
        return "\(botID.uuidString.lowercased()).\(firstMessageID.uuidString.lowercased())"
    }

    static func snapshot(
        for scope: ChatAppearanceScopeKind,
        botID: UUID?,
        chatID: String?,
        defaults: UserDefaults = .standard
    ) -> ChatAppearanceSnapshot {
        switch scope {
        case .global:
            return ChatAppearanceSnapshot.global(defaults: defaults)
        case .bot:
            guard let botID else { return ChatAppearanceSnapshot.global(defaults: defaults) }
            return override(forKey: botOverrideKey(botID), defaults: defaults)
                ?? ChatAppearanceSnapshot.global(defaults: defaults)
        case .chat:
            guard let chatID else {
                return resolved(botID: botID, chatID: nil, defaults: defaults)
            }
            return override(forKey: chatOverrideKey(chatID), defaults: defaults)
                ?? resolved(botID: botID, chatID: nil, defaults: defaults)
        }
    }

    static func resolved(
        botID: UUID?,
        chatID: String?,
        defaults: UserDefaults = .standard
    ) -> ChatAppearanceSnapshot {
        if let chatID,
           let chatAppearance = override(forKey: chatOverrideKey(chatID), defaults: defaults) {
            return chatAppearance
        }

        if let botID,
           let botAppearance = override(forKey: botOverrideKey(botID), defaults: defaults) {
            return botAppearance
        }

        return ChatAppearanceSnapshot.global(defaults: defaults)
    }

    static func hasCustomAppearance(
        for scope: ChatAppearanceScopeKind,
        botID: UUID?,
        chatID: String?,
        defaults: UserDefaults = .standard
    ) -> Bool {
        switch scope {
        case .global:
            return true
        case .bot:
            guard let botID else { return false }
            return override(forKey: botOverrideKey(botID), defaults: defaults) != nil
        case .chat:
            guard let chatID else { return false }
            return override(forKey: chatOverrideKey(chatID), defaults: defaults) != nil
        }
    }

    static func save(
        _ appearance: ChatAppearanceSnapshot,
        to scope: ChatAppearanceScopeKind,
        botID: UUID?,
        chatID: String?,
        defaults: UserDefaults = .standard,
        bumpRevision: Bool = true
    ) {
        switch scope {
        case .global:
            appearance.writeToGlobal(defaults: defaults)
        case .bot:
            guard let botID else { return }
            saveOverride(appearance, forKey: botOverrideKey(botID), defaults: defaults)
        case .chat:
            guard let chatID else { return }
            saveOverride(appearance, forKey: chatOverrideKey(chatID), defaults: defaults)
        }

        if bumpRevision {
            self.bumpRevision(defaults: defaults)
        }
    }

    static func reset(
        scope: ChatAppearanceScopeKind,
        botID: UUID?,
        chatID: String?,
        defaults: UserDefaults = .standard
    ) {
        switch scope {
        case .global:
            let oldAppearance = ChatAppearanceSnapshot.global(defaults: defaults)
            if !oldAppearance.wallpaperPath.isEmpty {
                ChatWallpaperStore.removeWallpaper(at: oldAppearance.wallpaperPath)
            }
            ChatAppearanceSnapshot.defaultValue.writeToGlobal(defaults: defaults)
            ChatWallpaperStore.clearLegacyBase64Storage(defaults: defaults)
        case .bot:
            guard let botID else { return }
            defaults.removeObject(forKey: botOverrideKey(botID))
        case .chat:
            guard let chatID else { return }
            defaults.removeObject(forKey: chatOverrideKey(chatID))
        }

        bumpRevision(defaults: defaults)
    }

    static func migrateLegacyWallpaperIfNeeded(defaults: UserDefaults = .standard) {
        var globalAppearance = ChatAppearanceSnapshot.global(defaults: defaults)
        let oldPath = globalAppearance.wallpaperPath
        ChatWallpaperStore.migrateLegacyBase64IfNeeded(path: &globalAppearance.wallpaperPath, defaults: defaults)
        ChatWallpaperStore.normalizeStoredPath(&globalAppearance.wallpaperPath)

        if globalAppearance.wallpaperPath != oldPath {
            globalAppearance.writeToGlobal(defaults: defaults)
            bumpRevision(defaults: defaults)
        }
    }

    private static func override(forKey key: String, defaults: UserDefaults) -> ChatAppearanceSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ChatAppearanceSnapshot.self, from: data)
    }

    private static func saveOverride(
        _ appearance: ChatAppearanceSnapshot,
        forKey key: String,
        defaults: UserDefaults
    ) {
        guard let data = try? JSONEncoder().encode(appearance) else { return }
        defaults.set(data, forKey: key)
    }

    private static func botOverrideKey(_ botID: UUID) -> String {
        ChatAppearanceStorageKeys.botAppearancePrefix + botID.uuidString.lowercased()
    }

    private static func chatOverrideKey(_ chatID: String) -> String {
        ChatAppearanceStorageKeys.chatAppearancePrefix + chatID
    }

    private static func bumpRevision(defaults: UserDefaults) {
        let current = defaults.integer(forKey: ChatAppearanceStorageKeys.appearanceRevision)
        defaults.set(current + 1, forKey: ChatAppearanceStorageKeys.appearanceRevision)
    }
}

enum ChatAppearancePresetStore {
    static func load(defaults: UserDefaults = .standard) -> [ChatAppearancePreset] {
        guard let data = defaults.data(forKey: ChatAppearanceStorageKeys.appearancePresets),
              let presets = try? JSONDecoder().decode([ChatAppearancePreset].self, from: data)
        else {
            return []
        }

        return presets.sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    static func savePreset(
        named name: String,
        appearance: ChatAppearanceSnapshot,
        defaults: UserDefaults = .standard
    ) -> [ChatAppearancePreset] {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var savedAppearance = appearance
        if let copiedWallpaperPath = ChatWallpaperStore.copyWallpaper(from: appearance.wallpaperPath) {
            savedAppearance.wallpaperPath = copiedWallpaperPath
        }

        let preset = ChatAppearancePreset(
            name: trimmedName.isEmpty ? "Chat Style" : trimmedName,
            appearance: savedAppearance
        )
        let presets = [preset] + load(defaults: defaults)
        save(presets, defaults: defaults)
        return presets
    }

    static func delete(_ preset: ChatAppearancePreset, defaults: UserDefaults = .standard) -> [ChatAppearancePreset] {
        if !preset.appearance.wallpaperPath.isEmpty {
            ChatWallpaperStore.removeWallpaper(at: preset.appearance.wallpaperPath)
        }

        let presets = load(defaults: defaults).filter { $0.id != preset.id }
        save(presets, defaults: defaults)
        return presets
    }

    private static func save(_ presets: [ChatAppearancePreset], defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        defaults.set(data, forKey: ChatAppearanceStorageKeys.appearancePresets)
    }
}

enum ChatWallpaperStore {
    private static let directoryName = "ChatAppearance"
    private static let wallpapersDirectoryName = "Wallpapers"
    private static let legacyFileName = "chat_wallpaper.jpg"
    private static let persistedPathToken = "local://chat_wallpaper"
    private static let scopedPathPrefix = "local://chat_wallpaper/"

    static func saveFromRawImageData(_ data: Data) -> String? {
        guard let image = UIImage(data: data) else { return nil }
        return saveImage(image)
    }

    static func saveImage(_ image: UIImage) -> String? {
        guard let normalized = resizedIfNeeded(image: image),
              let jpegData = normalized.jpegData(compressionQuality: 0.78)
        else {
            return nil
        }

        do {
            let fileURL = try wallpaperFileURL(identifier: UUID().uuidString)
            try jpegData.write(to: fileURL, options: [.atomic])
            return scopedPathPrefix + fileURL.lastPathComponent
        } catch {
            return nil
        }
    }

    static func loadImage(from path: String) -> UIImage? {
        guard let resolvedPath = resolveExistingPath(from: path) else { return nil }
        return UIImage(contentsOfFile: resolvedPath)
    }

    static func removeWallpaper(at path: String) {
        let fm = FileManager.default

        if let resolvedPath = resolvePathReference(path),
           fm.fileExists(atPath: resolvedPath) {
            try? fm.removeItem(atPath: resolvedPath)
        }
    }

    static func normalizeStoredPath(_ path: inout String) {
        if path.isEmpty {
            if let canonicalPath = try? legacyWallpaperFileURL().path,
               FileManager.default.fileExists(atPath: canonicalPath) {
                path = persistedPathToken
            }
            return
        }

        if path == persistedPathToken {
            return
        }

        if path.hasPrefix(scopedPathPrefix) {
            return
        }

        guard let canonicalPath = try? legacyWallpaperFileURL().path else { return }
        let fm = FileManager.default
        let normalizedInput = URL(fileURLWithPath: path).standardized.path
        let normalizedCanonical = URL(fileURLWithPath: canonicalPath).standardized.path

        if normalizedInput == normalizedCanonical {
            path = persistedPathToken
            return
        }

        if path.hasSuffix("/\(legacyFileName)") && !fm.fileExists(atPath: path) && fm.fileExists(atPath: canonicalPath) {
            path = persistedPathToken
        }
    }

    static func referencesSameWallpaper(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == rhs { return true }
        guard !lhs.isEmpty, !rhs.isEmpty else { return false }

        let lhsResolved = resolvePathReference(lhs)
        let rhsResolved = resolvePathReference(rhs)
        return lhsResolved == rhsResolved
    }

    static func migrateLegacyBase64IfNeeded(path: inout String, defaults: UserDefaults = .standard) {
        let legacyKey = ChatAppearanceStorageKeys.wallpaperBase64
        guard let legacyBase64 = defaults.string(forKey: legacyKey), !legacyBase64.isEmpty else { return }
        defer { defaults.removeObject(forKey: legacyKey) }

        guard path.isEmpty else { return }
        guard let data = Data(base64Encoded: legacyBase64),
              let savedPath = saveFromRawImageData(data)
        else {
            return
        }

        path = savedPath
    }

    static func clearLegacyBase64Storage(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: ChatAppearanceStorageKeys.wallpaperBase64)
    }

    static func copyWallpaper(from path: String) -> String? {
        guard let sourcePath = resolveExistingPath(from: path),
              FileManager.default.fileExists(atPath: sourcePath)
        else {
            return nil
        }

        do {
            let destination = try wallpaperFileURL(identifier: UUID().uuidString)
            try FileManager.default.copyItem(atPath: sourcePath, toPath: destination.path)
            return scopedPathPrefix + destination.lastPathComponent
        } catch {
            return nil
        }
    }

    private static func resolveExistingPath(from path: String) -> String? {
        let fm = FileManager.default

        if let directPath = resolvePathReference(path),
           fm.fileExists(atPath: directPath) {
            return directPath
        }

        guard !path.hasPrefix(scopedPathPrefix) else {
            return nil
        }

        if let canonicalPath = try? legacyWallpaperFileURL().path,
           fm.fileExists(atPath: canonicalPath) {
            return canonicalPath
        }

        return nil
    }

    private static func resolvePathReference(_ path: String) -> String? {
        guard !path.isEmpty else { return nil }

        if path == persistedPathToken {
            return try? legacyWallpaperFileURL().path
        }

        if path.hasPrefix(scopedPathPrefix) {
            let fileName = String(path.dropFirst(scopedPathPrefix.count))
            return try? wallpaperFileURL(fileName: fileName).path
        }

        return path
    }

    private static func legacyWallpaperFileURL() throws -> URL {
        try baseDirectoryURL().appendingPathComponent(legacyFileName)
    }

    private static func wallpaperFileURL(identifier: String) throws -> URL {
        let safeIdentifier = identifier
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let fileName = (safeIdentifier.isEmpty ? UUID().uuidString : safeIdentifier) + ".jpg"
        return try wallpaperFileURL(fileName: fileName)
    }

    private static func wallpaperFileURL(fileName: String) throws -> URL {
        let safeFileName = URL(fileURLWithPath: fileName).lastPathComponent
        return try wallpapersDirectoryURL().appendingPathComponent(safeFileName)
    }

    private static func wallpapersDirectoryURL() throws -> URL {
        let dir = try baseDirectoryURL().appendingPathComponent(wallpapersDirectoryName, isDirectory: true)
        let fm = FileManager.default
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static func baseDirectoryURL() throws -> URL {
        let fm = FileManager.default
        let appSupport = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent(directoryName, isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static func resizedIfNeeded(image: UIImage) -> UIImage? {
        let maxDimension: CGFloat = 1800
        let size = image.size
        let largestSide = max(size.width, size.height)

        guard largestSide > maxDimension else { return image }

        let scale = maxDimension / largestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
