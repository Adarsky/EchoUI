import Foundation
import Testing
@testable import FrontendAI

@MainActor
struct PrivateChatAccessTests {
    @Test
    func privateFolderEditsAndBotListsRequireAuthentication() async throws {
        let access = PrivateChatAccess()
        let privateBot = makeBot("Private character")
        let publicBot = makeBot("Public character")
        let folder = ChatFolder(name: "Private", botIDStrings: [ChatFolder.storageID(for: privateBot.id)])
        let work = ChatFolder(name: "Work", botIDStrings: folder.botIDStrings)
        let bots = [privateBot, publicBot]
        let folders = [folder, work]

        #expect(!access.canModify(folder))
        #expect(access.canModify(work))
        #expect(access.visibleBots(from: bots, folders: folders).map(\.id) == [publicBot.id])
        #expect(try await !access.authorize(using: { false }))
        #expect(!access.canModify(folder))

        #expect(try await access.authorize(using: { true }))
        #expect(access.canModify(folder))
        #expect(access.visibleBots(from: bots, folders: folders).map(\.id) == bots.map(\.id))

        access.lock()
        #expect(!access.canModify(folder))
        #expect(access.visibleBots(from: bots, folders: folders).map(\.id) == [publicBot.id])
    }

    @Test
    func backgroundLockRejectsALateAuthenticationSuccess() async throws {
        let access = PrivateChatAccess()
        var response: CheckedContinuation<Bool, Never>?
        let authentication = Task {
            try await access.authorize(using: {
                await withCheckedContinuation { response = $0 }
            })
        }
        // The task suspends inside the injected biometric request.
        while response == nil { await Task.yield() }
        #expect(access.isAuthenticating)
        access.lock()
        response?.resume(returning: true)

        #expect(try await !authentication.value)
        #expect(!access.isUnlocked)
        #expect(!access.isAuthenticating)
        #expect(try await access.authorize(using: { true }))
    }

    @Test
    func backgroundLockRequiresAFreshAuthentication() async throws {
        let access = PrivateChatAccess()
        var requests = 0
        let authenticate = { requests += 1; return true }
        #expect(try await access.authorize(using: authenticate))
        #expect(try await access.authorize(using: authenticate))
        #expect(requests == 1)
        access.lock()
        #expect(try await access.authorize(using: authenticate))
        #expect(requests == 2)
    }

    private func makeBot(_ name: String) -> BotModel {
        BotModel(name: name, subtitle: "", date: "Today", avatarSystemName: "person", iconColorName: "blue", isPinned: false, greeting: "Hello")
    }
}
