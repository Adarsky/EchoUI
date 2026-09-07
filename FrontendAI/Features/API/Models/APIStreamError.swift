import Foundation

enum APIStreamError: LocalizedError {
    case incompleteStream

    var errorDescription: String? {
        "The reply stream ended before the server finished. Try again."
    }
}
