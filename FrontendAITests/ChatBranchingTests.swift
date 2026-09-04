import Foundation
import SwiftData
import Testing
@testable import FrontendAI

struct ChatBranchingTests {
    @Test @MainActor
    func branchingThroughAssistantCopiesTheInclusivePrefixWithFreshIDs() throws {
        let (container, bot) = try makeContainerAndBot()
        let context = container.mainContext
        let personaID = UUID()
        let greeting = ChatMessageEntity(text: "Hello", isUser: false, index: 0)
        let prompt = ChatMessageEntity(text: "First question", isUser: true, index: 1)
        let selectedReply = ChatMessageEntity(
            text: "Second version",
            isUser: false,
            index: 2,
            variants: ["First version", "Second version"],
            currentVariantIndex: 1
        )
        let laterPrompt = ChatMessageEntity(text: "Later question", isUser: true, index: 3)
        let parent = ChatHistory(
            messages: [laterPrompt, selectedReply, greeting, prompt],
            bot: bot,
            personaID: personaID,
            hasPersonaOverride: true
        )
        context.insert(parent)
        try context.save()

        let branch = try #require(
            ChatHistoryPersistence.createBranch(
                from: parent,
                throughMessageID: selectedReply.id,
                context: context
            )
        )
        try context.save()

        let copiedMessages = branch.messages.sorted { $0.index < $1.index }
        #expect(copiedMessages.map(\.text) == ["Hello", "First question", "Second version"])
        #expect(copiedMessages.last?.variants == ["First version", "Second version"])
        #expect(copiedMessages.last?.currentVariantIndex == 1)
        #expect(branch.parentHistoryID == parent.historyID)
        #expect(branch.personaID == personaID)
        #expect(branch.hasPersonaOverride)

        let parentMessageIDs = Set(parent.messages.map(\.id))
        let branchMessageIDs = Set(branch.messages.map(\.id))
        #expect(parentMessageIDs.isDisjoint(with: branchMessageIDs))
        #expect(parent.selectionIdentifier != branch.selectionIdentifier)
        #expect(try context.fetchCount(FetchDescriptor<ChatHistory>()) == 2)
    }

    @Test @MainActor
    func userMessagesCannotCreateBranchesButGreetingCan() throws {
        let (container, bot) = try makeContainerAndBot()
        let context = container.mainContext
        let greeting = ChatMessageEntity(text: "Hello", isUser: false, index: 0)
        let prompt = ChatMessageEntity(text: "Question", isUser: true, index: 1)
        let parent = ChatHistory(messages: [greeting, prompt], bot: bot)
        context.insert(parent)
        try context.save()

        let rejectedBranch = ChatHistoryPersistence.createBranch(
            from: parent,
            throughMessageID: prompt.id,
            context: context
        )
        #expect(rejectedBranch == nil)
        #expect(try context.fetchCount(FetchDescriptor<ChatHistory>()) == 1)

        let greetingBranch = try #require(
            ChatHistoryPersistence.createBranch(
                from: parent,
                throughMessageID: greeting.id,
                context: context
            )
        )
        #expect(greetingBranch.messages.count == 1)
        #expect(greetingBranch.messages.first?.text == "Hello")
    }

    @Test @MainActor
    func deletingParentPromotesItsBranchesToRoots() throws {
        let (container, bot) = try makeContainerAndBot()
        let context = container.mainContext
        let greeting = ChatMessageEntity(text: "Hello", isUser: false, index: 0)
        let parent = ChatHistory(messages: [greeting], bot: bot)
        context.insert(parent)
        try context.save()

        let branch = try #require(
            ChatHistoryPersistence.createBranch(
                from: parent,
                throughMessageID: greeting.id,
                context: context
            )
        )
        try context.save()

        ChatHistoryPersistence.delete(parent, context: context)
        try context.save()

        #expect(branch.parentHistoryID == nil)
        #expect(try context.fetchCount(FetchDescriptor<ChatHistory>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<ChatMessageEntity>()) == 1)
    }

    @MainActor
    private func makeContainerAndBot() throws -> (ModelContainer, BotModel) {
        let schema = Schema([BotModel.self, ChatHistory.self, ChatMessageEntity.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let bot = BotModel(
            name: "Branching",
            subtitle: "Tests",
            date: "Today",
            avatarSystemName: "bubble.left",
            iconColorName: "blue",
            isPinned: false,
            greeting: "Hello"
        )
        container.mainContext.insert(bot)
        return (container, bot)
    }
}
