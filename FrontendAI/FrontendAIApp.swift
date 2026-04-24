//
//  FrontendAIApp.swift
//  FrontendAI
//
//  Created by macbook on 25.03.2025.
//

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
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
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
                let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
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

    static func backupStoreFiles(at storeURL: URL, date: Date = Date()) throws -> URL {
        let fileManager = FileManager.default
        let backupsRoot = storeURL
            .deletingLastPathComponent()
            .appendingPathComponent("StoreBackups", isDirectory: true)

        try fileManager.createDirectory(at: backupsRoot, withIntermediateDirectories: true)

        let backupDirectory = backupsRoot.appendingPathComponent(
            "FrontendAI-\(backupTimestamp(for: date))-\(String(UUID().uuidString.prefix(8)))",
            isDirectory: true
        )
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)

        for sourceURL in storeFileURLs(for: storeURL) where fileManager.fileExists(atPath: sourceURL.path) {
            let destinationURL = backupDirectory.appendingPathComponent(sourceURL.lastPathComponent)
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
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
