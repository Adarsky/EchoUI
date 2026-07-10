import Foundation

enum ChatDraftStore {
    static let didChangeNotification = Notification.Name("ChatDraftStoreDidChange")
    static let maximumDraftByteCount = 8 * 1_024 * 1_024

    static func loadDraft(
        for botID: UUID,
        storageDirectoryURL: URL? = nil
    ) -> String? {
        let fileURL = draftFileURL(for: botID, storageDirectoryURL: storageDirectoryURL)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
              let fileSize = resourceValues.fileSize,
              fileSize <= maximumDraftByteCount,
              let data = try? Data(contentsOf: fileURL, options: [.mappedIfSafe]),
              data.count <= maximumDraftByteCount,
              let text = String(data: data, encoding: .utf8),
              hasMeaningfulText(text) else {
            return nil
        }

        return text
    }

    @discardableResult
    static func saveDraft(
        _ text: String,
        for botID: UUID,
        storageDirectoryURL: URL? = nil
    ) -> Bool {
        guard hasMeaningfulText(text) else {
            return removeDraft(for: botID, storageDirectoryURL: storageDirectoryURL)
        }
        guard let data = text.data(using: .utf8),
              data.count <= maximumDraftByteCount else {
            return false
        }

        let directoryURL = resolvedStorageDirectoryURL(storageDirectoryURL)
        let fileURL = draftFileURL(for: botID, storageDirectoryURL: directoryURL)

        do {
            try StoreFileProtectionManager.protectDirectory(
                directoryURL,
                excludeFromDeviceBackup: false
            )
            try data.write(
                to: fileURL,
                options: [.atomic, .completeFileProtection]
            )
            try StoreFileProtectionManager.protectItem(fileURL)
            postChange(for: botID)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    static func removeDraft(
        for botID: UUID,
        storageDirectoryURL: URL? = nil
    ) -> Bool {
        let fileURL = draftFileURL(for: botID, storageDirectoryURL: storageDirectoryURL)

        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            postChange(for: botID)
            return true
        } catch {
            return false
        }
    }

    static func draftFileURL(
        for botID: UUID,
        storageDirectoryURL: URL? = nil
    ) -> URL {
        resolvedStorageDirectoryURL(storageDirectoryURL)
            .appendingPathComponent(botID.uuidString.lowercased())
            .appendingPathExtension("draft")
    }

    private static func resolvedStorageDirectoryURL(_ suppliedURL: URL?) -> URL {
        if let suppliedURL { return suppliedURL }

        let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        return applicationSupportURL.appendingPathComponent("ChatDrafts", isDirectory: true)
    }

    private static func hasMeaningfulText(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func postChange(for botID: UUID) {
        NotificationCenter.default.post(name: didChangeNotification, object: botID)
    }
}
