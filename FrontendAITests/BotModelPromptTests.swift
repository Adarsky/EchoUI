import Testing
@testable import FrontendAI

struct BotModelPromptTests {
    @Test @MainActor func characterSystemPromptIsNotTruncated() {
        let prompt = String(repeating: "A", count: 20_000)

        let bot = BotModel(
            name: "Long Prompt",
            subtitle: prompt,
            date: "Today",
            avatarSystemName: "person.crop.circle.fill",
            iconColorName: "blue",
            isPinned: false,
            greeting: "Hello"
        )

        #expect(bot.subtitle == prompt)
    }
}
