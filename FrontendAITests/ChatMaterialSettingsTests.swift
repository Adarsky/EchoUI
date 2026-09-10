import Foundation
import Testing
@testable import FrontendAI

struct ChatMaterialSettingsTests {
    @Test func globalMaterialsPersistIndependentlyAndResetToCurrentAppearance() throws {
        let suiteName = "ChatMaterialSettingsTests.global.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let original = ChatAppearanceSnapshot.global(defaults: defaults)
        #expect(original.messageMaterial == .ultraThinMaterial)
        #expect(original.notificationMaterial == .glass)

        var appearance = original
        appearance.messageMaterial = .glass
        appearance.notificationMaterial = .ultraThinMaterial
        ChatAppearanceStore.save(appearance, to: .global, botID: nil, chatID: nil, defaults: defaults)

        let restoredDefaults = try #require(UserDefaults(suiteName: suiteName))
        let restored = ChatAppearanceSnapshot.global(defaults: restoredDefaults)
        #expect(restored.messageMaterial == .glass)
        #expect(restored.notificationMaterial == .ultraThinMaterial)
        #expect(restored.userBubbleOpacity == original.userBubbleOpacity)
        #expect(defaults.integer(forKey: ChatAppearanceStorageKeys.appearanceRevision) == 1)

        ChatAppearanceStore.reset(scope: .global, botID: nil, chatID: nil, defaults: defaults)
        #expect(ChatAppearanceSnapshot.global(defaults: defaults) == original)
    }

    @Test(arguments: [false, true])
    func olderAndUnknownMaterialsKeepTheRestOfSavedStyles(useUnknownValues: Bool) throws {
        var appearance = ChatAppearanceSnapshot.defaultValue
        appearance.userBubbleOpacity = 0.37
        appearance.botBubbleTransparent = true
        appearance.wallpaperTintOpacity = 0.42
        var payload = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(appearance)) as? [String: Any]
        )
        for key in ["messageMaterial", "notificationMaterial"] {
            if useUnknownValues {
                payload[key] = "futureMaterial"
            } else {
                payload.removeValue(forKey: key)
            }
        }

        let restored = try JSONDecoder().decode(
            ChatAppearanceSnapshot.self,
            from: JSONSerialization.data(withJSONObject: payload)
        )
        #expect(restored == appearance)
    }

    @Test func unknownGlobalMaterialsUseTheirOwnDefaults() throws {
        let suiteName = "ChatMaterialSettingsTests.unknown.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("futureMaterial", forKey: ChatAppearanceStorageKeys.messageMaterial)
        defaults.set("futureMaterial", forKey: ChatAppearanceStorageKeys.notificationMaterial)

        let appearance = ChatAppearanceSnapshot.global(defaults: defaults)
        #expect(appearance.messageMaterial == .ultraThinMaterial)
        #expect(appearance.notificationMaterial == .glass)
    }

    @Test func scopedMaterialsFollowChatThenBotThenGlobalAndResetInheritance() throws {
        let suiteName = "ChatMaterialSettingsTests.scopes.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let botID = UUID()
        let chatID = "material-test-chat"

        var global = ChatAppearanceSnapshot.defaultValue
        global.messageMaterial = .glass
        global.notificationMaterial = .ultraThinMaterial
        ChatAppearanceStore.save(global, to: .global, botID: nil, chatID: nil, defaults: defaults)
        #expect(ChatAppearanceStore.resolved(botID: botID, chatID: chatID, defaults: defaults) == global)

        var bot = global
        bot.messageMaterial = .ultraThinMaterial
        ChatAppearanceStore.save(bot, to: .bot, botID: botID, chatID: nil, defaults: defaults)
        #expect(ChatAppearanceStore.resolved(botID: botID, chatID: chatID, defaults: defaults) == bot)

        var chat = bot
        chat.notificationMaterial = .glass
        ChatAppearanceStore.save(chat, to: .chat, botID: botID, chatID: chatID, defaults: defaults)
        #expect(ChatAppearanceStore.resolved(botID: botID, chatID: chatID, defaults: defaults) == chat)
        #expect(ChatAppearanceStore.resolved(botID: UUID(), chatID: nil, defaults: defaults) == global)

        ChatAppearanceStore.reset(scope: .chat, botID: botID, chatID: chatID, defaults: defaults)
        #expect(ChatAppearanceStore.resolved(botID: botID, chatID: chatID, defaults: defaults) == bot)
        ChatAppearanceStore.reset(scope: .bot, botID: botID, chatID: nil, defaults: defaults)
        #expect(ChatAppearanceStore.resolved(botID: botID, chatID: chatID, defaults: defaults) == global)
    }

    @Test func presetsKeepBothMaterialChoices() throws {
        let suiteName = "ChatMaterialSettingsTests.presets.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var appearance = ChatAppearanceSnapshot.defaultValue
        appearance.messageMaterial = .glass
        appearance.notificationMaterial = .ultraThinMaterial
        ChatAppearancePresetStore.savePreset(named: "Glass messages", appearance: appearance, defaults: defaults)

        let preset = try #require(ChatAppearancePresetStore.load(defaults: defaults).first)
        #expect(preset.appearance == appearance)
        ChatAppearanceStore.save(preset.appearance, to: .global, botID: nil, chatID: nil, defaults: defaults)
        #expect(ChatAppearanceSnapshot.global(defaults: defaults) == appearance)
    }
}
