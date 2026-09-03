import Foundation

struct ChatStoredVariant: Equatable, Sendable {
    let content: String
    let failure: ChatReplyFailure?

    var encodedValue: String {
        guard let failure else { return content }

        let envelope = FailureEnvelope(content: content, failure: failure)
        guard let data = try? JSONEncoder().encode(envelope) else { return content }
        return Self.envelopePrefix + data.base64EncodedString()
    }

    var displayText: String {
        guard let failure else { return content }

        let visibleContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !visibleContent.isEmpty else { return failure.title }
        return "\(visibleContent) — \(failure.title)"
    }

    static func restored(
        from storedValue: String,
        migrateLegacyError: Bool
    ) -> ChatStoredVariant {
        if let decoded = decodedEnvelope(from: storedValue) {
            return decoded
        }

        if migrateLegacyError, let migrated = migratedLegacyError(from: storedValue) {
            return migrated
        }

        return ChatStoredVariant(content: storedValue, failure: nil)
    }

    private struct FailureEnvelope: Codable {
        let content: String
        let failure: ChatReplyFailure
    }

    private static let envelopePrefix = "frontendai-internal://reply-failure/v1/"
    private static let legacyWarningMarker = "⚠️ Error:"
    private static let legacyPlainMarker = "Error:"

    private static func decodedEnvelope(from storedValue: String) -> ChatStoredVariant? {
        guard storedValue.hasPrefix(envelopePrefix) else { return nil }

        let encodedPayload = storedValue.dropFirst(envelopePrefix.count)
        guard
            let data = Data(base64Encoded: String(encodedPayload)),
            let envelope = try? JSONDecoder().decode(FailureEnvelope.self, from: data)
        else {
            return nil
        }

        return ChatStoredVariant(content: envelope.content, failure: envelope.failure)
    }

    private static func migratedLegacyError(from storedValue: String) -> ChatStoredVariant? {
        let warningWindow = storedValue.suffix(256)
        if let markerRange = warningWindow.range(of: legacyWarningMarker) {
            let message = String(storedValue[markerRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !message.isEmpty else { return nil }

            let content = String(storedValue[..<markerRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return ChatStoredVariant(
                content: content,
                failure: ChatReplyFailure.classified(message: message)
            )
        }

        guard
            storedValue.hasPrefix(legacyPlainMarker),
            storedValue.count <= 220
        else {
            return nil
        }

        let message = String(storedValue.dropFirst(legacyPlainMarker.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return nil }

        return ChatStoredVariant(
            content: "",
            failure: ChatReplyFailure.classified(message: message)
        )
    }
}
