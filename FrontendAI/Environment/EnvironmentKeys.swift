//
//  EnvironmentKeys.swift
//  FrontendAI
//
//  Created by macbook on 30.05.2025.
//

import SwiftUI

// MARK: - Bot
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

// MARK: - PersonaManager
struct PersonaManagerKey: EnvironmentKey {
    static let defaultValue = PersonaManager()
}
extension EnvironmentValues {
    var personaManager: PersonaManager {
        get { self[PersonaManagerKey.self] }
        set { self[PersonaManagerKey.self] = newValue }
    }
}

// MARK: - IsGenerating
struct IsGeneratingKey: EnvironmentKey {
    static let defaultValue: Bool = false
}
extension EnvironmentValues {
    var isGenerating: Bool {
        get { self[IsGeneratingKey.self] }
        set { self[IsGeneratingKey.self] = newValue }
    }
}

// MARK: - ShowCursor
struct ShowCursorKey: EnvironmentKey {
    static let defaultValue: Bool = true
}
extension EnvironmentValues {
    var showCursor: Bool {
        get { self[ShowCursorKey.self] }
        set { self[ShowCursorKey.self] = newValue }
    }
}

// MARK: - ShowAvatars
struct ShowAvatarsKey: EnvironmentKey {
    static let defaultValue: Bool = true
}
extension EnvironmentValues {
    var showAvatars: Bool {
        get { self[ShowAvatarsKey.self] }
        set { self[ShowAvatarsKey.self] = newValue }
    }
}
