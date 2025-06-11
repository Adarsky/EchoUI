//
//  BotKey.swift
//  FrontendAI
//
//  Created by macbook on 30.05.2025.
//


import SwiftUI

// MARK: - bot
struct BotKey: EnvironmentKey {
    static let defaultValue = Bot(
        id: UUID(),
        name: "Bot",
        avatarSystemName: "person.fill",
        iconColor: .gray,
        subtitle: "",
        date: "",
        isPinned: false,
        greeting: "",
        avatarData: nil
    )
}
extension EnvironmentValues {
    var bot: Bot {
        get { self[BotKey.self] }
        set { self[BotKey.self] = newValue }
    }
}

// MARK: - personaManager
struct PersonaManagerKey: EnvironmentKey {
    static let defaultValue = PersonaManager()
}
extension EnvironmentValues {
    var personaManager: PersonaManager {
        get { self[PersonaManagerKey.self] }
        set { self[PersonaManagerKey.self] = newValue }
    }
}

// MARK: - streamingReply
struct StreamingReplyKey: EnvironmentKey {
    static let defaultValue: ChatView.ChatMessage? = nil
}
extension EnvironmentValues {
    var streamingReply: ChatView.ChatMessage? {
        get { self[StreamingReplyKey.self] }
        set { self[StreamingReplyKey.self] = newValue }
    }
}

// MARK: - isGenerating
struct IsGeneratingKey: EnvironmentKey {
    static let defaultValue: Bool = false
}
extension EnvironmentValues {
    var isGenerating: Bool {
        get { self[IsGeneratingKey.self] }
        set { self[IsGeneratingKey.self] = newValue }
    }
}

// MARK: - showCursor
struct ShowCursorKey: EnvironmentKey {
    static let defaultValue: Bool = true
}
extension EnvironmentValues {
    var showCursor: Bool {
        get { self[ShowCursorKey.self] }
        set { self[ShowCursorKey.self] = newValue }
    }
}

// MARK: - showAvatars
struct ShowAvatarsKey: EnvironmentKey {
    static let defaultValue: Bool = true
}
extension EnvironmentValues {
    var showAvatars: Bool {
        get { self[ShowAvatarsKey.self] }
        set { self[ShowAvatarsKey.self] = newValue }
    }
}
