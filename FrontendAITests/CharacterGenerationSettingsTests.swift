import Foundation
import Testing
@testable import FrontendAI

struct CharacterGenerationSettingsTests {
    @Test @MainActor
    func inheritedModelTracksLaterServerDefaultChanges() {
        let bot = makeBot()
        let server = APIServer(
            name: "Server",
            baseURL: "https://api.openai.com",
            selectedModel: "global-model-a",
            type: .openai
        )

        #expect(CharacterGenerationSettings.resolvedModel(for: bot, server: server) == "global-model-a")

        server.selectedModel = "global-model-b"
        #expect(CharacterGenerationSettings.resolvedModel(for: bot, server: server) == "global-model-b")

        CharacterGenerationSettings.setModelOverride(
            " character-model ",
            for: bot,
            server: server
        )
        #expect(CharacterGenerationSettings.resolvedModel(for: bot, server: server) == "character-model")
        #expect(bot.modelOverrideServerID == server.uuid)

        CharacterGenerationSettings.setModelOverride("  ", for: bot, server: server)
        #expect(CharacterGenerationSettings.resolvedModel(for: bot, server: server) == "global-model-b")
    }

    @Test @MainActor
    func modelOverrideDoesNotLeakToAnotherServer() {
        let bot = makeBot()
        let firstServer = APIServer(
            name: "First Server",
            baseURL: "https://first.example.com",
            selectedModel: "first-default",
            type: .openai
        )
        let secondServer = APIServer(
            name: "Second Server",
            baseURL: "https://second.example.com",
            selectedModel: "second-default",
            type: .openai
        )

        CharacterGenerationSettings.setModelOverride(
            "first-character-model",
            for: bot,
            server: firstServer
        )

        #expect(
            CharacterGenerationSettings.resolvedModel(for: bot, server: firstServer) ==
                "first-character-model"
        )
        #expect(
            CharacterGenerationSettings.resolvedModel(for: bot, server: secondServer) ==
                "second-default"
        )
    }

    @Test @MainActor
    func characterThinkingOverrideSupportsMaxAndCanReturnToDefault() {
        let suiteName = "CharacterGenerationSettingsTests.thinking.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let bot = makeBot()
        let server = APIServer(
            name: "OpenRouter",
            baseURL: "https://openrouter.ai",
            selectedModel: "openai/gpt-test",
            type: .openrouter,
            thinkingEffort: .low
        )

        #expect(CharacterGenerationSettings.resolvedThinkingEffort(
            for: bot,
            botID: bot.id,
            server: server,
            defaults: defaults
        ) == .low)

        CharacterGenerationSettings.setThinkingEffortOverride(
            .max,
            for: bot,
            server: server,
            defaults: defaults
        )
        #expect(CharacterGenerationSettings.resolvedThinkingEffort(
            for: bot,
            botID: bot.id,
            server: server,
            defaults: defaults
        ) == .max)
        #expect(APIThinkingEffort.max.rawValue == "max")
        #expect(APIThinkingEffort.max.displayName == "Max")

        CharacterGenerationSettings.setThinkingEffortOverride(
            nil,
            for: bot,
            server: server,
            defaults: defaults
        )
        server.thinkingEffort = .high
        #expect(CharacterGenerationSettings.resolvedThinkingEffort(
            for: bot,
            botID: bot.id,
            server: server,
            defaults: defaults
        ) == .high)
    }

    @Test @MainActor
    func legacyPerServerThinkingOverrideRemainsReadable() throws {
        let suiteName = "CharacterGenerationSettingsTests.legacyThinking.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let bot = makeBot()
        let server = APIServer(
            name: "OpenRouter",
            baseURL: "https://openrouter.ai",
            selectedModel: "openai/gpt-test",
            type: .openrouter,
            thinkingEffort: .none
        )
        let key = try #require(
            CharacterGenerationSettings.legacyThinkingEffortKey(
                botID: bot.id,
                serverID: server.uuid
            )
        )
        defaults.set(APIThinkingEffort.xhigh.rawValue, forKey: key)

        #expect(CharacterGenerationSettings.resolvedThinkingEffort(
            for: bot,
            botID: bot.id,
            server: server,
            defaults: defaults
        ) == .xhigh)
    }

    @Test
    func characterTextTurnsEscapedNewlinesIntoVisibleMarkdownBreaks() {
        let source = "First\\nSecond/nThird\r\nFourth"

        #expect(CharacterTextFormatting.normalized(source) == "First\nSecond\nThird\nFourth")
        #expect(
            CharacterTextFormatting.markdownPreservingLineBreaks("First\\nSecond") ==
                "First  \nSecond"
        )
    }

    @MainActor
    private func makeBot() -> BotModel {
        BotModel(
            name: "Assistant",
            subtitle: "Helpful",
            date: "Today",
            avatarSystemName: "person.crop.circle.fill",
            iconColorName: "blue",
            isPinned: false,
            greeting: "Hello"
        )
    }
}
