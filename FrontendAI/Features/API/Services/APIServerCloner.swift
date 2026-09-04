import Foundation
import SwiftData

private enum APIServerCloningError: LocalizedError {
    case cleanupFailed(copyError: Error, cleanupError: Error)

    var errorDescription: String? {
        switch self {
        case let .cleanupFailed(copyError, cleanupError):
            return "\(copyError.localizedDescription) The incomplete clone could not be removed: \(cleanupError.localizedDescription)"
        }
    }
}

@MainActor
enum APIServerCloner {
    /// Persists a configuration clone before copying its keychain-backed secret to the new UUID.
    static func clone(
        _ source: APIServer,
        name: String,
        sortOrder: Int,
        in modelContext: ModelContext,
        readAPIKey: (APIServer) throws -> String? = { server in
            try server.readAPIKeyFromKeychain()
        }
    ) throws -> APIServer {
        _ = try source.migrateAPIKeyToKeychain()
        let sourceAPIKey = try readAPIKey(source)
        let clone = source.makeConfigurationClone(name: name, sortOrder: sortOrder)
        modelContext.insert(clone)

        do {
            try modelContext.save()
        } catch {
            modelContext.delete(clone)
            throw error
        }

        if let sourceAPIKey {
            do {
                try clone.setAPIKeyInKeychain(sourceAPIKey)
            } catch {
                let copyError = error
                modelContext.delete(clone)
                do {
                    try modelContext.save()
                } catch {
                    throw APIServerCloningError.cleanupFailed(
                        copyError: copyError,
                        cleanupError: error
                    )
                }
                throw copyError
            }
        }

        return clone
    }
}
