import SwiftUI
import SwiftData

@main
struct FrontendAIApp: App {

    @StateObject private var apiManager = APIManager()
    @State private var personaManager = PersonaManager()

    private let storeBootstrap = StoreBootstrap.bootstrap()

    var body: some Scene {
        WindowGroup {
            switch storeBootstrap {
            case let .ready(container, recoveryNotice):
                FrontendAIAppRoot(
                    modelContainer: container,
                    recoveryNotice: recoveryNotice,
                    personaManager: personaManager
                )
                .environmentObject(apiManager)
                .environment(personaManager)
            case let .failed(failure):
                StoreStartupFailureView(failure: failure)
            }
        }
    }
}

private struct FrontendAIAppRoot: View {
    let modelContainer: ModelContainer
    let personaManager: PersonaManager
    @State private var recoveryNotice: StoreRecoveryNotice?

    init(
        modelContainer: ModelContainer,
        recoveryNotice: StoreRecoveryNotice?,
        personaManager: PersonaManager
    ) {
        self.modelContainer = modelContainer
        self.personaManager = personaManager
        self._recoveryNotice = State(initialValue: recoveryNotice)
    }

    var body: some View {
        MainPage()
            .environment(personaManager)
            .modelContainer(modelContainer)
            .onAppear {
                Task {
                    let descriptor = FetchDescriptor<PersonaModel>()
                    let context = ModelContext(modelContainer)
                    let allPersonas = try? context.fetch(descriptor)
                    personaManager.restoreActivePersona(from: allPersonas ?? [])
                }
            }
            .alert(
                "Local Data Store Recovered",
                isPresented: Binding(
                    get: { recoveryNotice != nil },
                    set: { isPresented in
                        if !isPresented {
                            recoveryNotice = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    recoveryNotice = nil
                }
            } message: {
                Text(recoveryNotice?.message ?? "")
            }
    }
}

private enum StoreBootstrap {
    static func bootstrap() -> StoreBootstrapResult {
        let schema = Schema([
            BotModel.self,
            APIServer.self,
            ChatHistory.self,
            ChatMessageEntity.self,
            PersonaModel.self
        ])

        let modelConfiguration = ModelConfiguration(
            "FrontendAI",
            schema: schema,
            isStoredInMemoryOnly: false
        )
        let storeURL = modelConfiguration.url

        do {
            try StoreFileProtectionManager.protectStoreDirectory(for: storeURL)
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            try StoreFileProtectionManager.protectStoreFiles(for: storeURL)
            try? StoreFileProtectionManager.protectExistingStoreBackups(near: storeURL)
            return .ready(container, recoveryNotice: nil)
        } catch {
            print("SwiftData store open failed. Creating backup before recovery: \(error)")

            let backupDirectory: URL
            do {
                backupDirectory = try StoreBackupManager.backupStoreFiles(at: storeURL)
            } catch {
                return .failed(
                    StoreStartupFailure(
                        title: "Could Not Back Up Local Data",
                        message: "The app could not open the local data store and could not create a backup. No reset was performed.\n\n\(error.localizedDescription)"
                    )
                )
            }

            do {
                try StoreFileProtectionManager.protectStoreDirectory(for: storeURL)
                let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
                try StoreFileProtectionManager.protectStoreFiles(for: storeURL)
                try? StoreFileProtectionManager.protectExistingStoreBackups(near: storeURL)
                let notice = StoreRecoveryNotice(
                    backupDirectory: backupDirectory,
                    originalErrorDescription: error.localizedDescription
                )
                return .ready(container, recoveryNotice: notice)
            } catch {
                return .failed(
                    StoreStartupFailure(
                        title: "Could Not Create Local Data Store",
                        message: "The previous store was backed up at:\n\(backupDirectory.path)\n\nA fresh store could not be created.\n\n\(error.localizedDescription)"
                    )
                )
            }
        }
    }
}

private enum StoreBootstrapResult {
    case ready(ModelContainer, recoveryNotice: StoreRecoveryNotice?)
    case failed(StoreStartupFailure)
}

struct StoreRecoveryNotice: Identifiable {
    let id = UUID()
    let backupDirectory: URL
    let originalErrorDescription: String

    var message: String {
        "The previous local data store could not be opened, so it was moved to a backup and a fresh store was created.\n\nBackup:\n\(backupDirectory.path)"
    }
}

struct StoreStartupFailure {
    let title: String
    let message: String
}

enum StoreBackupManager {
    static func storeFileURLs(for storeURL: URL) -> [URL] {
        [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-shm"),
            URL(fileURLWithPath: storeURL.path + "-wal")
        ]
    }

    static func backupsRootURL(for storeURL: URL) -> URL {
        storeURL
            .deletingLastPathComponent()
            .appendingPathComponent("StoreBackups", isDirectory: true)
    }

    static func backupStoreFiles(at storeURL: URL, date: Date = Date()) throws -> URL {
        let fileManager = FileManager.default
        let backupsRoot = backupsRootURL(for: storeURL)

        try StoreFileProtectionManager.protectDirectory(backupsRoot, excludeFromDeviceBackup: true)

        let backupDirectory = backupsRoot.appendingPathComponent(
            "FrontendAI-\(backupTimestamp(for: date))-\(String(UUID().uuidString.prefix(8)))",
            isDirectory: true
        )
        try StoreFileProtectionManager.protectDirectory(backupDirectory, excludeFromDeviceBackup: true)

        for sourceURL in storeFileURLs(for: storeURL) where fileManager.fileExists(atPath: sourceURL.path) {
            let destinationURL = backupDirectory.appendingPathComponent(sourceURL.lastPathComponent)
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
            try StoreFileProtectionManager.protectItem(destinationURL)
        }

        return backupDirectory
    }

    private static func backupTimestamp(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
            .string(from: date)
            .replacingOccurrences(of: ":", with: "-")
    }
}

enum StoreFileProtectionManager {
    private static let protectionType = FileProtectionType.complete

    static func protectStoreDirectory(for storeURL: URL) throws {
        try protectDirectory(storeURL.deletingLastPathComponent(), excludeFromDeviceBackup: false)
    }

    static func protectStoreFiles(for storeURL: URL) throws {
        try protectStoreDirectory(for: storeURL)

        let fileManager = FileManager.default
        for fileURL in StoreBackupManager.storeFileURLs(for: storeURL)
        where fileManager.fileExists(atPath: fileURL.path) {
            try protectItem(fileURL)
        }
    }

    static func protectExistingStoreBackups(near storeURL: URL) throws {
        let backupsRoot = StoreBackupManager.backupsRootURL(for: storeURL)
        guard FileManager.default.fileExists(atPath: backupsRoot.path) else {
            return
        }

        try protectDirectory(backupsRoot, excludeFromDeviceBackup: true)
        try protectContentsRecursively(at: backupsRoot)
    }

    static func protectDirectory(_ directoryURL: URL, excludeFromDeviceBackup: Bool) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: protectionType]
        )
        try protectItem(directoryURL)

        if excludeFromDeviceBackup {
            var mutableURL = directoryURL
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try mutableURL.setResourceValues(resourceValues)
        }
    }

    static func protectContentsRecursively(at rootURL: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: rootURL.path) else {
            return
        }

        try protectItem(rootURL)

        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return
        }

        for case let itemURL as URL in enumerator {
            try protectItem(itemURL)
        }
    }

    static func protectItem(_ itemURL: URL) throws {
        try FileManager.default.setAttributes(
            [.protectionKey: protectionType],
            ofItemAtPath: itemURL.path
        )
    }

    static func isProtected(_ itemURL: URL) -> Bool {
        if let resourceValues = try? itemURL.resourceValues(forKeys: [.fileProtectionKey]),
           let protection = resourceValues.fileProtection {
            return protection == .complete
        }

        if let attributes = try? FileManager.default.attributesOfItem(atPath: itemURL.path),
           let value = attributes[.protectionKey] {
            if let protection = value as? FileProtectionType {
                return protection == protectionType
            }

            if let rawValue = value as? String {
                return rawValue == protectionType.rawValue
            }
        }

        return false
    }

    static func volumeSupportsFileProtection(at itemURL: URL) -> Bool {
        let resourceURL: URL
        if FileManager.default.fileExists(atPath: itemURL.path) {
            resourceURL = itemURL
        } else {
            resourceURL = itemURL.deletingLastPathComponent()
        }

        guard let resourceValues = try? resourceURL.resourceValues(
            forKeys: [.volumeSupportsFileProtectionKey]
        ) else {
            return true
        }

        return (resourceValues.allValues[.volumeSupportsFileProtectionKey] as? Bool) ?? true
    }
}

private struct StoreStartupFailureView: View {
    let failure: StoreStartupFailure

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 42))
                .foregroundStyle(.red)

            Text(failure.title)
                .font(.title2.weight(.semibold))

            Text(failure.message)
                .font(.body)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
