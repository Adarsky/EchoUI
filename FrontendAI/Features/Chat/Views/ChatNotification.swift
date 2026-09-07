import Foundation

struct ChatNotification: Identifiable, Equatable {
    enum Kind {
        case success
        case error
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let message: String

    static var branched: Self {
        Self(kind: .success, title: "Chat branched", message: "You’re now in a new chat.")
    }

    static func error(_ title: String, message: String) -> Self {
        Self(kind: .error, title: title, message: message)
    }
}
