import Foundation
import SwiftData
import Testing
@testable import FrontendAI

@MainActor
struct ChatHistoryWriterTests {
    @Test
    func submittedMessageIsDurableBeforeThereIsAnAssistantReply() throws {
        let (container, bot) = try makeContainer()
        let message = ChatMessageModel(content: "Keep this submitted prompt", isUser: true)
        let history = try #require(try ChatHistoryWriter.save(
            messages: [message], history: nil, bot: bot, personaID: nil,
            hasPersonaOverride: false, context: container.mainContext
        ))

        let reloaded = try ModelContext(container).fetch(FetchDescriptor<ChatHistory>())
        #expect(reloaded.count == 1)
        #expect(reloaded.first?.historyID == history.historyID)
        #expect(reloaded.first?.messages.map(\.text) == ["Keep this submitted prompt"])
    }

    @Test
    func deletingTheLastMessagePersistsAnEmptySelectableHistory() throws {
        let (container, bot) = try makeContainer()
        let context = container.mainContext
        let history = try #require(try ChatHistoryWriter.save(
            messages: [ChatMessageModel(content: "Delete me", isUser: false)], history: nil,
            bot: bot, personaID: nil, hasPersonaOverride: false, context: context
        ))
        _ = try ChatHistoryWriter.save(
            messages: [], history: history, bot: bot, personaID: nil,
            hasPersonaOverride: false, context: context
        )

        let reloadedContext = ModelContext(container)
        let reloaded = try #require(try reloadedContext.fetch(FetchDescriptor<ChatHistory>()).first)
        #expect(reloaded.messages.isEmpty)
        #expect(reloaded.selectionIdentifier != nil)
        #expect(try reloadedContext.fetchCount(FetchDescriptor<ChatMessageEntity>()) == 0)
    }

    @Test
    func failedSubmissionSaveDoesNotLeaveAPhantomMessage() throws {
        let (container, bot) = try makeContainer()
        let context = container.mainContext
        let original = ChatMessageModel(content: "Original", isUser: false)
        let history = try #require(try ChatHistoryWriter.save(
            messages: [original], history: nil, bot: bot, personaID: nil,
            hasPersonaOverride: false, context: context
        ))
        #expect(throws: CocoaError.self) {
            _ = try ChatHistoryWriter.save(
                messages: [original, ChatMessageModel(content: "Unsaved", isUser: true)],
                history: history, bot: bot, personaID: nil, hasPersonaOverride: false,
                context: context, saveContext: { _ in throw CocoaError(.fileWriteOutOfSpace) }
            )
        }
        #expect(history.messages.map(\.text) == ["Original"])
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<ChatMessageEntity>()) == 1)
        // A later autosave must not reintroduce the failed submission.
        try context.save()
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<ChatMessageEntity>()) == 1)
    }

    @Test
    func failedDeletionRestoresTheLastMessage() throws {
        let (container, bot) = try makeContainer()
        let context = container.mainContext
        let history = try #require(try ChatHistoryWriter.save(
            messages: [ChatMessageModel(content: "Keep on failure", isUser: true)],
            history: nil, bot: bot, personaID: nil, hasPersonaOverride: false, context: context
        ))
        #expect(throws: CocoaError.self) {
            _ = try ChatHistoryWriter.save(
                messages: [], history: history, bot: bot, personaID: nil,
                hasPersonaOverride: false, context: context,
                saveContext: { _ in throw CocoaError(.fileWriteOutOfSpace) }
            )
        }
        #expect(history.messages.map(\.text) == ["Keep on failure"])
        try context.save()
        #expect(try ModelContext(container).fetch(FetchDescriptor<ChatMessageEntity>()).map(\.text) == ["Keep on failure"])
    }

    @Test
    func missingCharacterIsASaveFailure() throws {
        let (container, _) = try makeContainer()
        #expect(throws: CocoaError.self) {
            _ = try ChatHistoryWriter.save(
                messages: [ChatMessageModel(content: "Do not discard my draft", isUser: true)],
                history: nil, bot: nil, personaID: nil, hasPersonaOverride: false,
                context: container.mainContext
            )
        }
    }

    private func makeContainer() throws -> (ModelContainer, BotModel) {
        let schema = Schema([BotModel.self, ChatHistory.self, ChatMessageEntity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let bot = BotModel(name: "Test", subtitle: "", date: "Today", avatarSystemName: "person", iconColorName: "blue", isPinned: false, greeting: "Hello")
        container.mainContext.insert(bot)
        try container.mainContext.save()
        return (container, bot)
    }
}
