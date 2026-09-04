import SwiftData
import Testing
@testable import FrontendAI

struct ChatFolderColorTests {
    @Test func folderUsesItsSavedColor() {
        let folder = ChatFolder(name: "Creative", colorName: ChatFolderColor.purple.rawValue)

        #expect(folder.displayColor == .purple)
    }

    @Test func folderFallsBackToTheDefaultForAnUnknownColor() {
        let folder = ChatFolder(name: "Legacy", colorName: "unknown")

        #expect(folder.colorName == ChatFolderColor.defaultValue.rawValue)
        #expect(folder.displayColor == .defaultValue)
    }

    @Test @MainActor func folderColorPersistsWithSwiftData() throws {
        let schema = Schema([ChatFolder.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let folder = ChatFolder(name: "Research", colorName: ChatFolderColor.teal.rawValue)

        context.insert(folder)
        try context.save()

        let persistedFolder = try #require(context.fetch(FetchDescriptor<ChatFolder>()).first)
        #expect(persistedFolder.colorName == ChatFolderColor.teal.rawValue)
        #expect(persistedFolder.displayColor == .teal)
    }
}
