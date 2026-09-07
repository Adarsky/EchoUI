import Foundation
import SwiftData
import Testing
@testable import FrontendAI

@MainActor
struct ChatFolderVisibilityTests {
    @Test func toggleHidesAndRestoresCharactersInAllChats() {
        let character = makeBot("Character")
        let other = makeBot("Other")
        let folder = ChatFolder(name: "Stories", botIDStrings: [ChatFolder.storageID(for: character.id)])
        let bots = [character, other]

        #expect(!folder.hidesFromAllChats)
        #expect(visibleIDs(bots, folders: [folder]) == bots.map(\.id))
        folder.hidesFromAllChats = true
        #expect(visibleIDs(bots, folders: [folder]) == [other.id])
        #expect(visibleIDs(bots, folders: [folder], selected: folder.id.uuidString) == [character.id])
        folder.hidesFromAllChats = false
        #expect(visibleIDs(bots, folders: [folder]) == bots.map(\.id))
    }

    @Test func anyHiddenMembershipWinsOnlyInAllChats() {
        let character = makeBot("Shared character")
        let ids = [ChatFolder.storageID(for: character.id)]
        let hidden = ChatFolder(name: "Hidden", hidesFromAllChats: true, botIDStrings: ids)
        let otherHidden = ChatFolder(name: "Also hidden", hidesFromAllChats: true, botIDStrings: ids)
        let ordinary = ChatFolder(name: "Ordinary", botIDStrings: ids)
        let folders = [hidden, otherHidden, ordinary]

        #expect(visibleIDs([character], folders: folders).isEmpty)
        #expect(visibleIDs([character], folders: folders, selected: ordinary.id.uuidString) == [character.id])
        hidden.hidesFromAllChats = false
        #expect(visibleIDs([character], folders: folders).isEmpty)
        otherHidden.setContains(false, botID: character.id)
        #expect(visibleIDs([character], folders: folders) == [character.id])
    }

    @Test func missingFolderFallsBackToFilteredAllChats() {
        let character = makeBot("Hidden")
        let folder = ChatFolder(name: "Stories", hidesFromAllChats: true, botIDStrings: [ChatFolder.storageID(for: character.id)])

        #expect(visibleIDs([character], folders: [folder], selected: UUID().uuidString).isEmpty)
        #expect(visibleIDs([character], folders: []) == [character.id])
    }

    @Test func disablingFoldersAndEditingStillExposeNonPrivateCharacters() {
        let character = makeBot("Hidden")
        let folder = ChatFolder(name: "Stories", hidesFromAllChats: true, botIDStrings: [ChatFolder.storageID(for: character.id)])

        #expect(visibleIDs([character], folders: [folder], foldersEnabled: false) == [character.id])
        #expect(PrivateChatAccess().visibleBots(from: [character], folders: [folder]).map(\.id) == [character.id])
    }

    @Test func privateCharactersStayProtectedRegardlessOfToggle() {
        let character = makeBot("Private character")
        let ids = [ChatFolder.storageID(for: character.id)]
        let privateFolder = ChatFolder(name: "Private", botIDStrings: ids)
        let ordinary = ChatFolder(name: "Stories", botIDStrings: ids)
        let folders = [privateFolder, ordinary]

        for hidden in [false, true] {
            privateFolder.hidesFromAllChats = hidden
            #expect(visibleIDs([character], folders: folders).isEmpty)
            #expect(visibleIDs([character], folders: folders, foldersEnabled: false).isEmpty)
            #expect(visibleIDs([character], folders: folders, selected: ordinary.id.uuidString).isEmpty)
            #expect(visibleIDs([character], folders: folders, selected: privateFolder.id.uuidString).isEmpty)
            #expect(visibleIDs([character], folders: folders, selected: privateFolder.id.uuidString,
                               unlocked: privateFolder.id.uuidString) == [character.id])
        }
    }

    @Test func visibilityPreferencePersistsAcrossContexts() throws {
        let schema = Schema([ChatFolder.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let writer = ModelContext(container)
        writer.insert(ChatFolder(name: "Stories", hidesFromAllChats: true))
        try writer.save()

        let reader = ModelContext(container)
        let saved = try #require(reader.fetch(FetchDescriptor<ChatFolder>()).first)
        #expect(saved.hidesFromAllChats)
        saved.hidesFromAllChats = false
        try reader.save()
        let freshReader = ModelContext(container)
        #expect(try #require(freshReader.fetch(FetchDescriptor<ChatFolder>()).first).hidesFromAllChats == false)
    }

    private func visibleIDs(
        _ bots: [BotModel],
        folders: [ChatFolder],
        selected: String = ChatFolder.allFolderID,
        foldersEnabled: Bool = true,
        unlocked: String? = nil
    ) -> [UUID] {
        PrivateChatVisibility.visibleBots(
            from: bots, folders: folders, foldersEnabled: foldersEnabled,
            selectedFolderID: selected, unlockedPrivateFolderID: unlocked
        ).map(\.id)
    }

    private func makeBot(_ name: String) -> BotModel {
        BotModel(name: name, subtitle: "", date: "Today", avatarSystemName: "person", iconColorName: "blue", isPinned: false, greeting: "Hello")
    }
}
