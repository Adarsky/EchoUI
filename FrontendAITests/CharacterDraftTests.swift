import Foundation
import SwiftData
import Testing
@testable import FrontendAI

struct CharacterDraftTests {
    @Test func creationRequiresPhotoAndNonblankNameAndDescription() {
        var draft = CharacterDraft()
        draft.name = " \n "
        draft.description = "Helpful"
        draft.avatarData = Data([1])
        #expect(draft.validationMessage(requiresPhoto: true) != nil)

        draft.name = "Luna"
        draft.description = " \n "
        #expect(draft.validationMessage(requiresPhoto: true) != nil)

        draft.description = "Helpful"
        draft.avatarData = nil
        #expect(draft.validationMessage(requiresPhoto: true) != nil)

        draft.avatarData = Data([1])
        #expect(draft.validationMessage(requiresPhoto: true) == nil)
        #expect(draft.greeting.isEmpty)
    }

    @Test func existingCharactersCanKeepTheirSystemAvatar() {
        let draft = CharacterDraft(bot: makeBot())
        #expect(draft.avatarData == nil)
        #expect(draft.validationMessage(requiresPhoto: false) == nil)
    }

    @Test func changeDetectionIgnoresWhitespaceAndRecognizesRevertedEdits() {
        let bot = makeBot()
        var draft = CharacterDraft(bot: bot)
        #expect(!draft.hasChanges(from: bot))
        draft.name = "  Luna\n"
        draft.description += "\n "
        draft.greeting += " "
        #expect(!draft.hasChanges(from: bot))

        draft.greeting = "A new greeting"
        #expect(draft.hasChanges(from: bot))
        draft.greeting = bot.greeting
        #expect(!draft.hasChanges(from: bot))

        draft.avatarData = Data([1, 2, 3])
        #expect(draft.hasChanges(from: bot))
    }

    @Test @MainActor func editingIsIsolatedUntilSaveAndPreservesOtherSettings() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let bot = makeBot()
        bot.isPinned = true
        bot.pinnedSortIndex = 3
        bot.modelOverride = "custom-model"
        bot.modelOverrideServerID = UUID()
        bot.thinkingEffortOverrideRawValue = "high"
        context.insert(bot)
        try context.save()
        let originalID = bot.id
        let originalServerID = bot.modelOverrideServerID

        var draft = CharacterDraft(bot: bot)
        draft.name = "  New name  "
        draft.description = "  New description\n"
        draft.greeting = "  Hello again\n"
        draft.avatarData = Data([1, 2, 3])
        #expect(bot.name == "Luna")
        #expect(bot.avatarData == nil)

        try draft.save(in: context, editing: bot)
        let readContext = ModelContext(container)
        let saved = try #require(readContext.fetch(FetchDescriptor<BotModel>()).first)
        #expect(saved.id == originalID)
        #expect(saved.name == "New name")
        #expect(saved.subtitle == "New description")
        #expect(saved.greeting == "Hello again")
        #expect(saved.avatarData == draft.avatarData)
        #expect(saved.date == "Sep 7, 2026")
        #expect(saved.isPinned)
        #expect(saved.pinnedSortIndex == 3)
        #expect(saved.modelOverride == "custom-model")
        #expect(saved.modelOverrideServerID == originalServerID)
        #expect(saved.thinkingEffortOverrideRawValue == "high")
        #expect(!draft.hasChanges(from: bot))
    }

    @Test @MainActor func creationPreservesLongPromptsAndClampsName() throws {
        let container = try makeContainer()
        var draft = CharacterDraft()
        draft.name = String(repeating: "🌙", count: 30)
        draft.description = "  " + String(repeating: "Prompt\n", count: 4_000) + "End  "
        draft.avatarData = Data([1, 2, 3])

        try draft.save(in: container.mainContext, editing: nil)
        let saved = try #require(ModelContext(container).fetch(FetchDescriptor<BotModel>()).first)
        #expect(saved.name.count == BotModel.maxNameLength)
        #expect(saved.subtitle == draft.description.trimmingCharacters(in: .whitespacesAndNewlines))
        #expect(saved.greeting.isEmpty)
        #expect(saved.avatarData == draft.avatarData)
        #expect(!saved.date.isEmpty)
        #expect(!saved.isPinned)
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: BotModel.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func makeBot() -> BotModel {
        BotModel(
            name: "Luna",
            subtitle: "A thoughtful creative partner.",
            date: "Sep 7, 2026",
            avatarSystemName: "sparkles",
            iconColorName: "purple",
            isPinned: false,
            greeting: "Hello!"
        )
    }
}
