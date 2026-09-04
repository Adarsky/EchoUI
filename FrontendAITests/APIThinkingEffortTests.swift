import Foundation
import Testing
@testable import FrontendAI

struct APIThinkingEffortTests {
    @Test
    func availableSettingsUseTheRequestedOrder() {
        #expect(APIThinkingEffort.allCases.map(\.displayName) == [
            "None", "On", "Low", "Medium", "High", "Extra High", "Max"
        ])
        #expect(APIThinkingEffort.on.pickerDisplayName == "ON (Small/Older Models)")
        #expect(APIThinkingEffort.xhigh.rawValue == "xhigh")
    }

    @Test
    func openAICompatibleEffortUsesReasoningEffort() {
        let body = APIService.makeOpenAIRequestBody(
            messages: [ChatPayloadMessage(role: "user", content: "Hello")],
            config: makeConfig(type: .openai, thinkingEffort: .xhigh)
        )

        #expect(body["reasoning_effort"] as? String == "xhigh")
        #expect(body["enable_thinking"] == nil)
    }

    @Test
    func openAICompatibleNoneUsesExplicitNoneEffort() {
        let body = APIService.makeOpenAIRequestBody(
            messages: [],
            config: makeConfig(type: .openai, thinkingEffort: .none)
        )

        #expect(body["reasoning_effort"] as? String == "none")
        #expect(body["enable_thinking"] == nil)
    }

    @Test
    func openAICompatibleOnUsesEnableThinking() {
        let enabledBody = APIService.makeOpenAIRequestBody(
            messages: [],
            config: makeConfig(type: .openai, thinkingEffort: .on)
        )

        #expect(enabledBody["enable_thinking"] as? Bool == true)
        #expect(enabledBody["reasoning_effort"] == nil)
    }

    @Test
    func openRouterKeepsNestedReasoningShape() throws {
        let effortBody = APIService.makeOpenRouterRequestBody(
            messages: [],
            config: makeConfig(type: .openrouter, thinkingEffort: .max)
        )
        let toggleBody = APIService.makeOpenRouterRequestBody(
            messages: [],
            config: makeConfig(type: .openrouter, thinkingEffort: .on)
        )
        let effort = try #require(effortBody["reasoning"] as? [String: Any])
        let toggle = try #require(toggleBody["reasoning"] as? [String: Any])

        #expect(effort["effort"] as? String == "max")
        #expect(effort["enabled"] == nil)
        #expect(toggle["enabled"] as? Bool == true)
        #expect(toggle["effort"] == nil)
    }

    @Test
    func legacyOffValueMigratesToNone() {
        #expect(APIThinkingEffort.value(from: "off") == .none)
    }

    private func makeConfig(
        type: APIType,
        thinkingEffort: APIThinkingEffort
    ) -> ServerConfig {
        ServerConfig(
            type: type,
            baseURL: "https://api.example.com",
            selectedModel: "test-model",
            apiKey: nil,
            allowInsecureTLS: false,
            customCACertificateData: nil,
            thinkingEffort: thinkingEffort
        )
    }
}
