import Foundation

enum PortableStoreBackup {
    static let fileExtension = "frontendai-backup"

    private static let format = "frontendai-store-backup-v1"
    private static let allowedFileNames = Set([
        "FrontendAI.store",
        "FrontendAI.store-shm",
        "FrontendAI.store-wal"
    ])

    static func makeBackupData(from files: [StoreRecoveryFileSnapshot]) throws -> Data {
        let existingFiles = files.filter(\.exists)
        guard existingFiles.contains(where: { $0.name == "FrontendAI.store" }) else {
            throw PortableStoreBackupError.noStoreFile
        }

        let payloadFiles = try existingFiles
            .filter { allowedFileNames.contains($0.name) }
            .map { file in
                PortableStoreBackupFile(
                    name: file.name,
                    data: try Data(contentsOf: file.url),
                    modifiedAt: file.modifiedAt
                )
            }

        let payload = PortableStoreBackupPayload(
            format: format,
            createdAt: Date(),
            files: payloadFiles
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    static func importBackupData(_ data: Data) throws -> StoreBackupSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(PortableStoreBackupPayload.self, from: data)

        guard payload.format == format else {
            throw PortableStoreBackupError.unsupportedFormat
        }

        guard payload.files.contains(where: { $0.name == "FrontendAI.store" }) else {
            throw PortableStoreBackupError.noStoreFile
        }

        let storeURL = StoreRecoveryManager.defaultStoreURL()
        let backupsRootURL = StoreBackupManager.backupsRootURL(for: storeURL)
        let importedBackupURL = backupsRootURL.appendingPathComponent(
            "Imported-\(backupTimestamp(for: Date()))-\(String(UUID().uuidString.prefix(8)))",
            isDirectory: true
        )

        try StoreFileProtectionManager.protectDirectory(importedBackupURL, excludeFromDeviceBackup: true)

        for file in payload.files {
            guard allowedFileNames.contains(file.name) else {
                continue
            }

            let destinationURL = importedBackupURL.appendingPathComponent(file.name)
            try file.data.write(to: destinationURL, options: [.atomic])
            try StoreFileProtectionManager.protectItem(destinationURL)
        }

        return StoreBackupSnapshot(
            url: importedBackupURL,
            files: StoreBackupManager.storeFileURLs(for: storeURL)
                .map { importedBackupURL.appendingPathComponent($0.lastPathComponent) }
                .map { StoreRecoveryFileSnapshot(url: $0) }
                .filter(\.exists)
        )
    }

    static func defaultFileName(prefix: String = "FrontendAI") -> String {
        "\(prefix)-\(backupTimestamp(for: Date())).\(fileExtension)"
    }

    private static func backupTimestamp(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
            .string(from: date)
            .replacingOccurrences(of: ":", with: "-")
    }
}

private struct PortableStoreBackupPayload: Codable {
    let format: String
    let createdAt: Date
    let files: [PortableStoreBackupFile]
}

private struct PortableStoreBackupFile: Codable {
    let name: String
    let data: Data
    let modifiedAt: Date
}

enum PortableStoreBackupError: LocalizedError {
    case noStoreFile
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .noStoreFile:
            return "No FrontendAI.store file was found in this backup."
        case .unsupportedFormat:
            return "This file is not a supported FrontendAI backup."
        }
    }
}
