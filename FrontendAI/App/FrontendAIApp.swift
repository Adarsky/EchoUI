import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

@main
struct FrontendAIApp: App {

    @StateObject private var apiManager = APIManager()
    @State private var personaManager = PersonaManager()
    @State private var storeBootstrap = StoreBootstrap.bootstrap()

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
            case .protectedDataUnavailable:
                LoadScreen()
                    .onAppear(perform: retryStoreBootstrapIfProtectedDataIsAvailable)
                    .retryingWhenProtectedDataBecomesAvailable(retryStoreBootstrap)
            }
        }
    }

    private func retryStoreBootstrapIfProtectedDataIsAvailable() {
        guard StoreBootstrap.isProtectedDataAvailable else { return }
        retryStoreBootstrap()
    }

    private func retryStoreBootstrap() {
        storeBootstrap = StoreBootstrap.bootstrap()
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
        Group {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--message-editor-ui-testing") {
                MessageEditorUITestHost()
            } else {
                MainPage()
            }
            #else
            MainPage()
            #endif
        }
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
            ChatFolder.self,
            ChatMessageEntity.self,
            PersonaModel.self
        ])

        let modelConfiguration = ModelConfiguration(
            "FrontendAI",
            schema: schema,
            isStoredInMemoryOnly: false
        )
        let storeURL = modelConfiguration.url

        guard isProtectedDataAvailable else {
            return .protectedDataUnavailable
        }

        let restoreNotice: StoreRecoveryNotice?
        do {
            restoreNotice = try StoreRecoveryManager.performPendingRestoreIfNeeded(storeURL: storeURL)
        } catch {
            return .failed(
                StoreStartupFailure(
                    title: "Could Not Restore Local Data",
                    message: "The app could not restore the selected local data backup. No fresh store was created.\n\n\(error.localizedDescription)"
                )
            )
        }

        do {
            try StoreFileProtectionManager.protectStoreDirectory(for: storeURL)
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            try StoreFileProtectionManager.protectStoreFiles(for: storeURL)
            try? StoreFileProtectionManager.protectExistingStoreBackups(near: storeURL)
            return .ready(container, recoveryNotice: restoreNotice)
        } catch {
            print("SwiftData store open failed. No automatic recovery was performed: \(error)")
            return .failed(
                StoreStartupFailure(
                    title: "Could Not Open Local Data",
                    message: "The app could not open the local data store. No reset was performed, and no store files were moved.\n\n\(error.localizedDescription)"
                )
            )
        }
    }

    static var isProtectedDataAvailable: Bool {
        #if os(iOS)
        UIApplication.shared.isProtectedDataAvailable
        #else
        true
        #endif
    }
}

private enum StoreBootstrapResult {
    case ready(ModelContainer, recoveryNotice: StoreRecoveryNotice?)
    case failed(StoreStartupFailure)
    case protectedDataUnavailable
}

struct StoreRecoveryNotice: Identifiable {
    let id = UUID()
    let backupDirectory: URL
    let originalErrorDescription: String
    var didRestoreBackup = false

    var message: String {
        if didRestoreBackup {
            return "The selected local data backup was restored.\n\nBackup:\n\(backupDirectory.path)"
        }

        return "The previous local data store could not be opened, so it was moved to a backup and a fresh store was created.\n\nBackup:\n\(backupDirectory.path)"
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

enum StoreRecoveryManager {
    private static let pendingRestoreBackupNameKey = "pendingStoreBackupRestoreName"

    static func defaultStoreURL() -> URL {
        let schema = Schema([
            BotModel.self,
            APIServer.self,
            ChatHistory.self,
            ChatFolder.self,
            ChatMessageEntity.self,
            PersonaModel.self
        ])
        return ModelConfiguration(
            "FrontendAI",
            schema: schema,
            isStoredInMemoryOnly: false
        ).url
    }

    static func recoverySnapshot() -> StoreRecoverySnapshot {
        let storeURL = defaultStoreURL()
        let fileManager = FileManager.default

        let activeFiles = StoreBackupManager.storeFileURLs(for: storeURL)
            .map { StoreRecoveryFileSnapshot(url: $0) }
            .filter(\.exists)

        let backupsRootURL = StoreBackupManager.backupsRootURL(for: storeURL)
        let backupDirectories = backupDirectories(in: backupsRootURL, fileManager: fileManager)
            .map { directoryURL in
                StoreBackupSnapshot(
                    url: directoryURL,
                    files: StoreBackupManager.storeFileURLs(for: storeURL)
                        .map { directoryURL.appendingPathComponent($0.lastPathComponent) }
                        .map { StoreRecoveryFileSnapshot(url: $0) }
                        .filter(\.exists)
                )
            }
            .filter { !$0.files.isEmpty }

        return StoreRecoverySnapshot(
            activeFiles: activeFiles,
            backupDirectories: backupDirectories.sorted { lhs, rhs in
                lhs.modifiedAt > rhs.modifiedAt
            },
            pendingRestoreBackupName: UserDefaults.standard.string(forKey: pendingRestoreBackupNameKey)
        )
    }

    static func scheduleRestore(_ backup: StoreBackupSnapshot) {
        UserDefaults.standard.set(backup.url.lastPathComponent, forKey: pendingRestoreBackupNameKey)
    }

    @discardableResult
    static func performPendingRestoreIfNeeded(storeURL: URL) throws -> StoreRecoveryNotice? {
        guard let backupName = UserDefaults.standard.string(forKey: pendingRestoreBackupNameKey) else {
            return nil
        }

        let fileManager = FileManager.default
        let backupsRootURL = StoreBackupManager.backupsRootURL(for: storeURL)
        let backupURL = backupsRootURL.appendingPathComponent(backupName, isDirectory: true)
        guard fileManager.fileExists(atPath: backupURL.path) else {
            UserDefaults.standard.removeObject(forKey: pendingRestoreBackupNameKey)
            throw StoreRecoveryError.backupNotFound(backupName)
        }

        let currentBackupURL = try StoreBackupManager.backupStoreFiles(at: storeURL)
        for storeFileURL in StoreBackupManager.storeFileURLs(for: storeURL) {
            let sourceURL = backupURL.appendingPathComponent(storeFileURL.lastPathComponent)
            guard fileManager.fileExists(atPath: sourceURL.path) else {
                continue
            }

            try fileManager.copyItem(at: sourceURL, to: storeFileURL)
            try StoreFileProtectionManager.protectItem(storeFileURL)
        }

        UserDefaults.standard.removeObject(forKey: pendingRestoreBackupNameKey)
        return StoreRecoveryNotice(
            backupDirectory: backupURL,
            originalErrorDescription: "Previous active store was backed up at \(currentBackupURL.path)",
            didRestoreBackup: true
        )
    }

    private static func backupDirectories(in backupsRootURL: URL, fileManager: FileManager) -> [URL] {
        guard
            let urls = try? fileManager.contentsOfDirectory(
                at: backupsRootURL,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return []
        }

        return urls.filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
    }
}

struct StoreRecoverySnapshot {
    let activeFiles: [StoreRecoveryFileSnapshot]
    let backupDirectories: [StoreBackupSnapshot]
    let pendingRestoreBackupName: String?

    var latestBackup: StoreBackupSnapshot? {
        backupDirectories.first
    }
}

struct StoreBackupSnapshot: Identifiable {
    let url: URL
    let files: [StoreRecoveryFileSnapshot]

    var id: String {
        url.path
    }

    var name: String {
        url.lastPathComponent
    }

    var totalByteCount: Int64 {
        files.reduce(0) { $0 + $1.byteCount }
    }

    var modifiedAt: Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            ?? .distantPast
    }
}

struct StoreRecoveryFileSnapshot: Identifiable {
    let url: URL

    var id: String {
        url.path
    }

    var name: String {
        url.lastPathComponent
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    var byteCount: Int64 {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            let size = attributes[.size] as? NSNumber
        else {
            return 0
        }
        return size.int64Value
    }

    var modifiedAt: Date {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            let date = attributes[.modificationDate] as? Date
        else {
            return .distantPast
        }
        return date
    }
}

enum StoreRecoveryError: LocalizedError {
    case backupNotFound(String)

    var errorDescription: String? {
        switch self {
        case let .backupNotFound(name):
            return "The selected backup folder could not be found: \(name)"
        }
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
    @State private var isShowingRecovery = false

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

            Button {
                isShowingRecovery = true
            } label: {
                Label("Open Recovery", systemImage: "externaldrive.badge.clock")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .sheet(isPresented: $isShowingRecovery) {
            NavigationStack {
                LocalDataRecoveryView()
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func retryingWhenProtectedDataBecomesAvailable(_ retry: @escaping () -> Void) -> some View {
        #if os(iOS)
        self.onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.protectedDataDidBecomeAvailableNotification
            )
        ) { _ in
            retry()
        }
        #else
        self
        #endif
    }
}
