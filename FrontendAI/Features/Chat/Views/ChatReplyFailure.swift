import Foundation

struct ChatReplyFailure: Codable, Hashable, Sendable {
    enum Kind: String, Codable, Hashable, Sendable {
        case offline
        case timedOut
        case connectionInterrupted
        case serverUnavailable
        case authentication
        case rateLimited
        case configuration
        case requestRejected
        case unknown
    }

    let kind: Kind
    let message: String

    static func classified(message rawMessage: String) -> ChatReplyFailure {
        let message = rawMessage
            .replacing("\n", with: " ")
            .replacing("\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = message.isEmpty
            ? "Something interrupted the request. Please try again."
            : message
        let lowercased = normalized.lowercased()

        if lowercased == "no internet connection."
            || lowercased.contains("not connected to the internet")
            || lowercased.contains("you appear to be offline") {
            return ChatReplyFailure(
                kind: .offline,
                message: "Reconnect to the internet, then try sending your message again."
            )
        }

        if lowercased == "the request timed out."
            || lowercased.contains("timed out")
            || lowercased.contains("timeout") {
            return ChatReplyFailure(
                kind: .timedOut,
                message: "The server didn’t respond in time. Try again in a moment."
            )
        }

        if lowercased == "network connection was interrupted."
            || lowercased.contains("network connection was lost")
            || lowercased.contains("connection interrupted")
            || lowercased.contains("connection dropped") {
            return ChatReplyFailure(
                kind: .connectionInterrupted,
                message: "The connection dropped while the reply was being generated."
            )
        }

        if lowercased == "cannot connect to the server."
            || lowercased.contains("server unavailable")
            || lowercased.contains("cannot connect to host")
            || lowercased.contains("could not connect to the server") {
            return ChatReplyFailure(
                kind: .serverUnavailable,
                message: "Check the server address and your connection, then try again."
            )
        }

        let kind: Kind
        if lowercased.contains("authentication failed")
            || lowercased.contains("api key")
            || lowercased.contains("unauthorized") {
            kind = .authentication
        } else if lowercased.contains("rate limit") || lowercased.contains("too many requests") {
            kind = .rateLimited
        } else if lowercased.contains("base url")
                    || lowercased.contains("endpoint was not found")
                    || lowercased.contains("must use https")
                    || lowercased.contains("certificate") {
            kind = .configuration
        } else if lowercased.contains("request rejected") {
            kind = .requestRejected
        } else {
            kind = .unknown
        }

        return ChatReplyFailure(kind: kind, message: normalized)
    }

    var title: String {
        switch kind {
        case .offline:
            "You’re Offline"
        case .timedOut:
            "That Took Too Long"
        case .connectionInterrupted:
            "Connection Interrupted"
        case .serverUnavailable:
            "Can’t Reach the Server"
        case .authentication:
            "Check Your API Key"
        case .rateLimited:
            "Too Many Requests"
        case .configuration:
            "Check Server Settings"
        case .requestRejected:
            "Request Couldn’t Be Sent"
        case .unknown:
            "Couldn’t Generate a Reply"
        }
    }

    var systemImage: String {
        switch kind {
        case .offline:
            "wifi.slash"
        case .timedOut:
            "clock"
        case .connectionInterrupted:
            "wifi.exclamationmark"
        case .serverUnavailable:
            "network.slash"
        case .authentication:
            "key.fill"
        case .rateLimited:
            "hourglass"
        case .configuration:
            "gearshape.2.fill"
        case .requestRejected:
            "exclamationmark.bubble.fill"
        case .unknown:
            "exclamationmark.triangle.fill"
        }
    }
}
