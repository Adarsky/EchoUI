import Foundation

enum CharacterGenerationSettings {
    static func modelOverride(for bot: BotModel?) -> String? {
        guard let rawValue = bot?.modelOverride else { return nil }
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    static func modelOverride(for bot: BotModel?, server: APIServer) -> String? {
        guard bot?.modelOverrideServerID == server.uuid else { return nil }
        return modelOverride(for: bot)
    }

    static func resolvedModel(for bot: BotModel?, server: APIServer) -> String {
        modelOverride(for: bot, server: server) ?? server.selectedModel
    }

    static func setModelOverride(
        _ model: String?,
        for bot: BotModel,
        server: APIServer
    ) {
        let normalized = model?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let normalized, !normalized.isEmpty {
            bot.modelOverride = normalized
            bot.modelOverrideServerID = server.uuid
        } else if bot.modelOverrideServerID == nil || bot.modelOverrideServerID == server.uuid {
            bot.modelOverride = nil
            bot.modelOverrideServerID = nil
        }
    }

    static func thinkingEffortOverride(
        for bot: BotModel?,
        botID: UUID?,
        server: APIServer,
        defaults: UserDefaults = .standard
    ) -> APIThinkingEffort? {
        if let rawValue = bot?.thinkingEffortOverrideRawValue,
           let effort = APIThinkingEffort(rawValue: rawValue) {
            return effort
        }

        guard let key = legacyThinkingEffortKey(botID: botID, serverID: server.uuid),
              let rawValue = defaults.string(forKey: key) else {
            return nil
        }
        return APIThinkingEffort(rawValue: rawValue)
    }

    static func resolvedThinkingEffort(
        for bot: BotModel?,
        botID: UUID?,
        server: APIServer,
        defaults: UserDefaults = .standard
    ) -> APIThinkingEffort {
        thinkingEffortOverride(
            for: bot,
            botID: botID,
            server: server,
            defaults: defaults
        ) ?? server.thinkingEffort
    }

    static func setThinkingEffortOverride(
        _ effort: APIThinkingEffort?,
        for bot: BotModel,
        server: APIServer,
        defaults: UserDefaults = .standard
    ) {
        bot.thinkingEffortOverrideRawValue = effort?.rawValue
        clearLegacyThinkingEffortOverride(
            botID: bot.id,
            serverID: server.uuid,
            defaults: defaults
        )
    }

    static func clearLegacyThinkingEffortOverride(
        botID: UUID?,
        serverID: UUID,
        defaults: UserDefaults = .standard
    ) {
        guard let key = legacyThinkingEffortKey(botID: botID, serverID: serverID) else {
            return
        }
        defaults.removeObject(forKey: key)
    }

    static func legacyThinkingEffortKey(botID: UUID?, serverID: UUID) -> String? {
        guard let botID else { return nil }
        return "chatThinkingEffort.\(botID.uuidString.lowercased()).\(serverID.uuidString.lowercased())"
    }
}
