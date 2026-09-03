import Foundation
import Testing
import UIKit
@testable import FrontendAI

struct ChatReplyFailureTests {
    @Test
    func interruptedConnectionUsesStructuredPresentation() {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNetworkConnectionLost
        )

        let failure = ChatReplyStreamService.userFacingFailure(from: error)

        #expect(failure.kind == .connectionInterrupted)
        #expect(failure.title == "Connection Interrupted")
        #expect(failure.systemImage == "wifi.exclamationmark")
        #expect(failure.message == "The connection dropped while the reply was being generated.")
    }

    @Test
    func authenticationErrorGetsActionablePresentation() {
        let error = NSError(
            domain: "APIService",
            code: -1003,
            userInfo: [
                NSLocalizedDescriptionKey: "Authentication failed. Check your API key and permissions."
            ]
        )

        let failure = ChatReplyStreamService.userFacingFailure(from: error)

        #expect(failure.kind == .authentication)
        #expect(failure.title == "Check Your API Key")
    }

    @Test
    @MainActor
    func everyFailurePresentationUsesAnAvailableSystemSymbol() {
        let kinds: [ChatReplyFailure.Kind] = [
            .offline,
            .timedOut,
            .connectionInterrupted,
            .serverUnavailable,
            .authentication,
            .rateLimited,
            .configuration,
            .requestRejected,
            .unknown
        ]

        for kind in kinds {
            let failure = ChatReplyFailure(kind: kind, message: "Test")
            #expect(UIImage(systemName: failure.systemImage) != nil)
        }
    }

    @Test
    @MainActor
    func failureStatePersistsWithoutBecomingAssistantContent() {
        let message = ChatMessageModel(content: "", isUser: false)
        let failure = ChatReplyFailure(
            kind: .offline,
            message: "Reconnect to the internet, then try sending your message again."
        )

        message.setFailure(failure)

        #expect(message.content.isEmpty)
        #expect(message.failure == failure)
        #expect(message.contentForConversation == nil)
        #expect(message.hasPersistableVariant)

        let values = message.persistenceValues(includeVariants: true)
        let restored = ChatMessageModel(
            content: values?.text ?? "",
            isUser: false,
            variants: values?.variants,
            currentIndex: values?.currentVariantIndex ?? 0,
            restorePersistedFailures: true
        )

        #expect(values != nil)
        #expect(restored.content.isEmpty)
        #expect(restored.failure == failure)
        #expect(restored.contentForConversation == nil)
    }

    @Test
    @MainActor
    func failedRegenerationRestoresBothTheReplyAndFailureAlternative() {
        let message = ChatMessageModel(content: "A complete reply", isUser: false)
        message.addNewVariant()
        let failure = ChatReplyFailure(
            kind: .timedOut,
            message: "The server didn’t respond in time. Try again in a moment."
        )
        message.setFailure(failure)

        let values = message.persistenceValues(includeVariants: true)
        let restored = ChatMessageModel(
            content: values?.text ?? "",
            isUser: false,
            variants: values?.variants,
            currentIndex: values?.currentVariantIndex ?? 0,
            restorePersistedFailures: true
        )

        #expect(message.contentForConversation == "A complete reply")
        #expect(values?.variants?.count == 2)
        #expect(values?.currentVariantIndex == 1)
        #expect(restored.content.isEmpty)
        #expect(restored.failure == failure)
        #expect(restored.contentForConversation == "A complete reply")
        #expect(restored.hasMultipleVariants)
    }

    @Test
    @MainActor
    func retryKeepsExistingVariantsAndAppendsTheNewReply() {
        let message = ChatMessageModel(content: "First reply", isUser: false)
        message.addNewVariant()
        message.setFailure(
            ChatReplyFailure(
                kind: .connectionInterrupted,
                message: "The reply stream ended unexpectedly. Try again."
            )
        )

        message.addNewVariant()
        message.setStreaming(true)
        message.appendChunk("Successful retry", to: message.currentIndex)
        message.setStreaming(false)

        let values = message.persistenceValues(includeVariants: true)
        let restored = ChatMessageModel(
            content: values?.text ?? "",
            isUser: false,
            variants: values?.variants,
            currentIndex: values?.currentVariantIndex ?? 0,
            restorePersistedFailures: true
        )

        #expect(message.allVariants.count == 3)
        #expect(message.currentIndex == 2)
        #expect(message.content == "Successful retry")
        #expect(values?.variants?.count == 3)
        #expect(restored.allVariants.count == 3)
        #expect(restored.currentIndex == 2)
        #expect(restored.content == "Successful retry")
    }

    @Test
    @MainActor
    func legacyPlainErrorRestoresAsStructuredFailure() {
        let message = ChatMessageModel(
            content: "Error: Network connection was interrupted.",
            isUser: false,
            restorePersistedFailures: true
        )

        #expect(message.content.isEmpty)
        #expect(message.failure?.kind == .connectionInterrupted)
        #expect(message.failure?.title == "Connection Interrupted")
        #expect(message.failure?.message == "The connection dropped while the reply was being generated.")
    }

    @Test
    @MainActor
    func legacyWarningPreservesPartialReplyAndRestoresFailure() {
        let message = ChatMessageModel(
            content: "Here is the partial reply.⚠️ Error: The request timed out.",
            isUser: false,
            restorePersistedFailures: true
        )

        #expect(message.content == "Here is the partial reply.")
        #expect(message.failure?.kind == .timedOut)
        #expect(message.contentForConversation == nil)
    }

    @Test
    @MainActor
    func userTextThatStartsWithErrorIsNotMigrated() {
        let message = ChatMessageModel(
            content: "Error: Network connection was interrupted.",
            isUser: true,
            restorePersistedFailures: true
        )

        #expect(message.content == "Error: Network connection was interrupted.")
        #expect(message.failure == nil)
    }

    @Test
    @MainActor
    func reopenedEmptyAssistantPlaceholderIsDiscardable() {
        let message = ChatMessageModel(
            content: "",
            isUser: false,
            restorePersistedFailures: true
        )

        #expect(message.isDiscardableEmptyAssistantPlaceholder)
        #expect(!message.hasPersistableVariant)
    }

}
