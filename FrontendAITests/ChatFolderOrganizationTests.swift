import Foundation
import SwiftData
import Testing
@testable import FrontendAI

@MainActor
struct ChatFolderOrganizationTests {
    @Test func pinsAreIndependentInAllChatsAndEveryFolder() {
        let bot = makeBot("Character")
        let first = makeFolder("First", bots: [bot])
        let second = makeFolder("Second", bots: [bot])

        ChatFolderOrganization.togglePin(bot, in: nil, bots: [bot])
        #expect(bot.isPinned)
        #expect(!ChatFolderOrganization.isPinned(bot, in: first))
        #expect(!ChatFolderOrganization.isPinned(bot, in: second))

        ChatFolderOrganization.togglePin(bot, in: first, bots: [bot])
        ChatFolderOrganization.togglePin(bot, in: nil, bots: [bot])
        #expect(!bot.isPinned)
        #expect(ChatFolderOrganization.isPinned(bot, in: first))
        #expect(!ChatFolderOrganization.isPinned(bot, in: second))

        ChatFolderOrganization.togglePin(bot, in: second, bots: [bot])
        ChatFolderOrganization.togglePin(bot, in: first, bots: [bot])
        #expect(!ChatFolderOrganization.isPinned(bot, in: first))
        #expect(ChatFolderOrganization.isPinned(bot, in: second))
    }

    @Test func pinOrderIsIndependentAndPreservesHiddenPins() {
        let bots = [makeBot("A"), makeBot("B"), makeBot("C")]
        let folder = makeFolder("Stories", bots: bots)
        for bot in bots {
            ChatFolderOrganization.togglePin(bot, in: nil, bots: bots)
            ChatFolderOrganization.togglePin(bot, in: folder, bots: bots)
        }
        ChatFolderOrganization.applyPinnedOrder([bots[2], bots[0]], in: folder, bots: bots)
        #expect(ChatFolderOrganization.pinnedBots(from: bots, in: folder).map(\.id) == [bots[2].id, bots[1].id, bots[0].id])
        #expect(ChatFolderOrganization.pinnedBots(from: bots, in: nil).map(\.id) == bots.map(\.id))
        ChatFolderOrganization.applyPinnedOrder([bots[1], bots[0]], in: nil, bots: bots)
        #expect(ChatFolderOrganization.pinnedBots(from: bots, in: nil).map(\.id) == [bots[1].id, bots[0].id, bots[2].id])
        #expect(ChatFolderOrganization.pinnedBots(from: bots, in: folder).map(\.id) == [bots[2].id, bots[1].id, bots[0].id])
    }

    @Test func removingHiddenPinnedCharacterAppendsItToAllChatsPins() {
        let existing = makeBot("Existing pin")
        let returning = makeBot("Returning")
        let bots = [existing, returning]
        let folder = makeFolder("Stories", bots: [returning], hidden: true)
        ChatFolderOrganization.togglePin(existing, in: nil, bots: bots)
        ChatFolderOrganization.togglePin(returning, in: folder, bots: bots)

        ChatFolderOrganization.replaceMembers(of: folder, with: [], bots: bots, folders: [folder])

        #expect(returning.isPinned)
        #expect(ChatFolderOrganization.pinnedBots(from: bots, in: nil).map(\.id) == bots.map(\.id))
        #expect(folder.pinnedBotIDStrings.isEmpty)
        #expect(folder.botIDStrings.isEmpty)
    }

    @Test func removalDoesNotOverwritePinsForCharactersAlreadyInAllChatsOrStillHidden() {
        let visible = makeBot("Visible")
        let hidden = makeBot("Still hidden")
        let bots = [visible, hidden]
        let first = makeFolder("First", bots: bots)
        let second = makeFolder("Second", bots: [hidden], hidden: true)
        for bot in bots { ChatFolderOrganization.togglePin(bot, in: first, bots: bots) }

        ChatFolderOrganization.replaceMembers(of: first, with: [], bots: bots, folders: [first, second])

        #expect(!visible.isPinned)
        #expect(!hidden.isPinned)
        #expect(second.contains(botID: hidden.id))
    }

    @Test func deletingFolderReturnsCharactersWithoutDeletingThemOrTheirOtherMemberships() throws {
        let schema = Schema([BotModel.self, ChatFolder.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = container.mainContext
        let bots = [makeBot("Pinned"), makeBot("Regular")]
        let folder = makeFolder("Stories", bots: bots, hidden: true)
        let other = makeFolder("Other", bots: bots)
        for bot in bots { context.insert(bot) }
        context.insert(folder)
        context.insert(other)
        ChatFolderOrganization.togglePin(bots[0], in: folder, bots: bots)

        ChatFolderOrganization.replaceMembers(of: folder, with: [], bots: bots, folders: [folder, other])
        context.delete(folder)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<BotModel>()) == 2)
        let remainingFolders = try context.fetch(FetchDescriptor<ChatFolder>())
        #expect(remainingFolders.map(\.id) == [other.id])
        #expect(other.botIDStrings.count == 2)
        #expect(PrivateChatVisibility.visibleBots(from: bots, folders: remainingFolders, foldersEnabled: true,
                                                 selectedFolderID: ChatFolder.allFolderID, unlockedPrivateFolderID: nil).map(\.id) == bots.map(\.id))
        #expect(bots[0].isPinned)
        #expect(!bots[1].isPinned)
    }

    @Test func folderPinsPersistInOrder() throws {
        let schema = Schema([ChatFolder.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let bots = [makeBot("A"), makeBot("B")]
        let folder = makeFolder("Stories", bots: bots)
        container.mainContext.insert(folder)
        for bot in bots.reversed() { ChatFolderOrganization.togglePin(bot, in: folder, bots: bots) }
        try container.mainContext.save()

        let reader = ModelContext(container)
        let saved = try #require(reader.fetch(FetchDescriptor<ChatFolder>()).first)
        #expect(saved.pinnedBotIDStrings == bots.reversed().map { ChatFolder.storageID(for: $0.id) })
    }

    private func makeFolder(_ name: String, bots: [BotModel], hidden: Bool = false) -> ChatFolder {
        ChatFolder(name: name, hidesFromAllChats: hidden, botIDStrings: bots.map { ChatFolder.storageID(for: $0.id) })
    }

    private func makeBot(_ name: String) -> BotModel {
        BotModel(name: name, subtitle: "", date: "Today", avatarSystemName: "person", iconColorName: "blue", isPinned: false, greeting: "Hello")
    }
}
