import Foundation
import LocalAuthentication
import Observation

@MainActor
@Observable
final class PrivateChatAccess {
    private(set) var isUnlocked = false
    private(set) var isAuthenticating = false
    private var authenticationID: UUID?
    private var context: LAContext?

    func authorize() async throws -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        return try await authorize(using: {
            self.context = context
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock private chats."
            )
        })
    }

    // The injected operation also lets tests exercise a late biometric response
    // after the app has entered the background.
    func authorize(using authenticate: () async throws -> Bool) async throws -> Bool {
        if isUnlocked { return true }
        guard !isAuthenticating else { return false }
        let requestID = UUID()
        authenticationID = requestID
        isAuthenticating = true
        defer {
            if authenticationID == requestID {
                authenticationID = nil
                isAuthenticating = false
                context = nil
            }
        }

        do {
            let succeeded = try await authenticate()
            guard authenticationID == requestID, !Task.isCancelled else { return false }
            isUnlocked = succeeded
            return succeeded
        } catch {
            guard authenticationID == requestID, !Task.isCancelled else { return false }
            throw error
        }
    }

    func lock() {
        authenticationID = nil
        isUnlocked = false
        isAuthenticating = false
        context?.invalidate()
        context = nil
    }

    func canModify(_ folder: ChatFolder) -> Bool {
        !folder.isPrivate || isUnlocked
    }

    func visibleBots(from bots: [BotModel], folders: [ChatFolder]) -> [BotModel] {
        if isUnlocked { return bots }
        return PrivateChatVisibility.visibleBots(
            from: bots,
            folders: folders,
            foldersEnabled: false,
            selectedFolderID: ChatFolder.allFolderID,
            unlockedPrivateFolderID: nil
        )
    }
}
