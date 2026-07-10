import Foundation
import SQLite3

enum PortableStoreBackup {
    static let fileExtension = "frontendai-backup"
    static let maximumArchiveByteCount = 128 * 1_024 * 1_024

    private static let format = "frontendai-store-backup-v1"
    private static let maximumDecodedByteCount = 96 * 1_024 * 1_024
    private static let allowedFileNames = Set([
        "FrontendAI.store",
        "FrontendAI.store-shm",
        "FrontendAI.store-wal"
    ])

    static func makeBackupData(
        from files: [StoreRecoveryFileSnapshot],
        snapshotLiveStore: Bool = false
    ) throws -> Data {
        let existingFiles = files.filter(\.exists)
        guard let storeFile = existingFiles.first(where: { $0.name == "FrontendAI.store" }) else {
            throw PortableStoreBackupError.noStoreFile
        }

        let payloadFiles: [PortableStoreBackupFile]
        if snapshotLiveStore {
            payloadFiles = [
                PortableStoreBackupFile(
                    name: storeFile.name,
                    data: try SQLiteStoreSnapshot.makeSnapshotData(
                        from: storeFile.url,
                        maximumByteCount: maximumDecodedByteCount
                    ),
                    modifiedAt: storeFile.modifiedAt
                )
            ]
        } else {
            let eligibleFiles = existingFiles.filter { allowedFileNames.contains($0.name) }
            let totalFileBytes = eligibleFiles.reduce(Int64(0)) { total, file in
                total + max(0, file.byteCount)
            }
            guard totalFileBytes <= Int64(maximumDecodedByteCount) else {
                throw PortableStoreBackupError.decodedPayloadTooLarge
            }

            payloadFiles = try eligibleFiles
                .map { file in
                    PortableStoreBackupFile(
                        name: file.name,
                        data: try Data(contentsOf: file.url),
                        modifiedAt: file.modifiedAt
                    )
                }
        }

        let totalPayloadBytes = payloadFiles.reduce(into: 0) { total, file in
            total += file.data.count
        }
        guard totalPayloadBytes <= maximumDecodedByteCount else {
            throw PortableStoreBackupError.decodedPayloadTooLarge
        }

        let payload = PortableStoreBackupPayload(
            format: format,
            createdAt: Date(),
            files: payloadFiles
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(payload)
        guard encoded.count <= maximumArchiveByteCount else {
            throw PortableStoreBackupError.archiveTooLarge
        }
        return encoded
    }

    static func importBackupData(_ data: Data) throws -> StoreBackupSnapshot {
        guard data.count <= maximumArchiveByteCount else {
            throw PortableStoreBackupError.archiveTooLarge
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(PortableStoreBackupPayload.self, from: data)

        guard payload.format == format else {
            throw PortableStoreBackupError.unsupportedFormat
        }

        guard payload.files.contains(where: { $0.name == "FrontendAI.store" }) else {
            throw PortableStoreBackupError.noStoreFile
        }

        let fileNames = payload.files.map(\.name)
        guard payload.files.count <= allowedFileNames.count,
              Set(fileNames).count == fileNames.count,
              fileNames.allSatisfy(allowedFileNames.contains) else {
            throw PortableStoreBackupError.invalidFileList
        }

        let totalDecodedBytes = payload.files.reduce(into: 0) { total, file in
            total += file.data.count
        }
        guard totalDecodedBytes <= maximumDecodedByteCount else {
            throw PortableStoreBackupError.decodedPayloadTooLarge
        }

        guard let mainStore = payload.files.first(where: { $0.name == "FrontendAI.store" }),
              mainStore.data.starts(with: Data("SQLite format 3\0".utf8)) else {
            throw PortableStoreBackupError.invalidStoreFile
        }

        let storeURL = StoreRecoveryManager.defaultStoreURL()
        let backupsRootURL = StoreBackupManager.backupsRootURL(for: storeURL)
        let importedBackupURL = backupsRootURL.appendingPathComponent(
            "Imported-\(backupTimestamp(for: Date()))-\(String(UUID().uuidString.prefix(8)))",
            isDirectory: true
        )

        do {
            try StoreFileProtectionManager.protectDirectory(importedBackupURL, excludeFromDeviceBackup: true)

            for file in payload.files {
                let destinationURL = importedBackupURL.appendingPathComponent(file.name)
                try file.data.write(to: destinationURL, options: [.atomic])
                try StoreFileProtectionManager.protectItem(destinationURL)
            }
        } catch {
            try? FileManager.default.removeItem(at: importedBackupURL)
            throw error
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

    static func readImportData(from url: URL) throws -> Data {
        let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        if let fileSize, fileSize > maximumArchiveByteCount {
            throw PortableStoreBackupError.archiveTooLarge
        }

        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard data.count <= maximumArchiveByteCount else {
            throw PortableStoreBackupError.archiveTooLarge
        }
        return data
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
    case archiveTooLarge
    case decodedPayloadTooLarge
    case invalidFileList
    case invalidStoreFile
    case snapshotFailed(String)

    var errorDescription: String? {
        switch self {
        case .noStoreFile:
            return "No FrontendAI.store file was found in this backup."
        case .unsupportedFormat:
            return "This file is not a supported FrontendAI backup."
        case .archiveTooLarge:
            return "This backup file is too large to import safely."
        case .decodedPayloadTooLarge:
            return "The decoded backup contents are too large to import safely."
        case .invalidFileList:
            return "The backup contains unexpected or duplicate store files."
        case .invalidStoreFile:
            return "The backup does not contain a valid SQLite store file."
        case let .snapshotFailed(message):
            return "The active store snapshot could not be created: \(message)"
        }
    }
}

private enum SQLiteStoreSnapshot {
    static func makeSnapshotData(from sourceURL: URL, maximumByteCount: Int) throws -> Data {
        let fileManager = FileManager.default
        let temporaryURL = fileManager.temporaryDirectory
            .appendingPathComponent("FrontendAI-Snapshot-\(UUID().uuidString).store")
        defer { try? fileManager.removeItem(at: temporaryURL) }

        var sourceDatabase: OpaquePointer?
        var destinationDatabase: OpaquePointer?

        guard sqlite3_open_v2(
            sourceURL.path,
            &sourceDatabase,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK else {
            let message = sqliteMessage(from: sourceDatabase)
            if let sourceDatabase { sqlite3_close(sourceDatabase) }
            throw PortableStoreBackupError.snapshotFailed(message)
        }
        defer {
            if let sourceDatabase {
                sqlite3_close(sourceDatabase)
            }
        }

        guard sqlite3_open_v2(
            temporaryURL.path,
            &destinationDatabase,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK else {
            let message = sqliteMessage(from: destinationDatabase)
            if let destinationDatabase { sqlite3_close(destinationDatabase) }
            throw PortableStoreBackupError.snapshotFailed(message)
        }
        defer {
            if let destinationDatabase {
                sqlite3_close(destinationDatabase)
            }
        }

        var backupHandle = sqlite3_backup_init(destinationDatabase, "main", sourceDatabase, "main")
        guard let backup = backupHandle else {
            throw PortableStoreBackupError.snapshotFailed(sqliteMessage(from: destinationDatabase))
        }
        defer {
            if let backupHandle {
                sqlite3_backup_finish(backupHandle)
            }
        }

        var result = sqlite3_backup_step(backup, 256)
        var retryCount = 0
        while result == SQLITE_OK || result == SQLITE_BUSY || result == SQLITE_LOCKED {
            if result == SQLITE_BUSY || result == SQLITE_LOCKED {
                retryCount += 1
                guard retryCount <= 200 else {
                    throw PortableStoreBackupError.snapshotFailed("The database remained busy.")
                }
                sqlite3_sleep(25)
            }
            result = sqlite3_backup_step(backup, 256)
        }

        guard result == SQLITE_DONE else {
            throw PortableStoreBackupError.snapshotFailed(sqliteMessage(from: destinationDatabase))
        }

        let finishResult = sqlite3_backup_finish(backup)
        backupHandle = nil
        guard finishResult == SQLITE_OK else {
            throw PortableStoreBackupError.snapshotFailed(sqliteMessage(from: destinationDatabase))
        }

        // The source store normally uses WAL mode. A single-file export should
        // not require a sidecar WAL/SHM file just to be opened read-only.
        guard sqlite3_exec(destinationDatabase, "PRAGMA journal_mode=DELETE", nil, nil, nil) == SQLITE_OK else {
            throw PortableStoreBackupError.snapshotFailed(sqliteMessage(from: destinationDatabase))
        }

        guard sqlite3_close(destinationDatabase) == SQLITE_OK else {
            throw PortableStoreBackupError.snapshotFailed(sqliteMessage(from: destinationDatabase))
        }
        destinationDatabase = nil
        sqlite3_close(sourceDatabase)
        sourceDatabase = nil

        let snapshotByteCount = try temporaryURL
            .resourceValues(forKeys: [.fileSizeKey])
            .fileSize ?? 0
        guard snapshotByteCount <= maximumByteCount else {
            throw PortableStoreBackupError.decodedPayloadTooLarge
        }

        return try Data(contentsOf: temporaryURL)
    }

    private static func sqliteMessage(from database: OpaquePointer?) -> String {
        guard let database, let message = sqlite3_errmsg(database) else {
            return "Unknown SQLite error."
        }
        return String(cString: message)
    }
}
