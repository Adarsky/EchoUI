import SwiftUI

struct LocalDataRecoveryView: View {
    @State private var snapshot = StoreRecoveryManager.recoverySnapshot()
    @State private var backupPendingRestore: StoreBackupSnapshot?
    @State private var exportDocument = FrontendAIBackupDocument()
    @State private var exportFileName = PortableStoreBackup.defaultFileName()
    @State private var recoveryMessage: StoreRecoveryMessage?
    @State private var isShowingRestoreConfirmation = false
    @State private var isShowingRestartNotice = false
    @State private var isShowingExporter = false
    @State private var isShowingImporter = false

    var body: some View {
        List {
            Section {
                Button {
                    exportFiles(snapshot.activeFiles, prefix: "FrontendAI-active")
                } label: {
                    Label("Export Active Store", systemImage: "square.and.arrow.up")
                }
                .disabled(snapshot.activeFiles.isEmpty)

                Button {
                    isShowingImporter = true
                } label: {
                    Label("Import Backup File", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("Portable Backup")
            } footer: {
                Text("Portable backup files contain local chats and settings. Keep them private.")
            }

            Section("Active Store") {
                if snapshot.activeFiles.isEmpty {
                    ContentUnavailableView(
                        "No Active Store Files",
                        systemImage: "externaldrive.badge.questionmark",
                        description: Text("No SwiftData store files were found in Application Support.")
                    )
                } else {
                    ForEach(snapshot.activeFiles) { file in
                        StoreRecoveryFileRow(file: file)
                    }
                }
            }

            Section("Backups") {
                if snapshot.backupDirectories.isEmpty {
                    ContentUnavailableView(
                        "No Backups Found",
                        systemImage: "tray",
                        description: Text("No StoreBackups folder with SwiftData store files was found.")
                    )
                } else {
                    ForEach(snapshot.backupDirectories) { backup in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(backup.name)
                                        .font(.headline)
                                        .lineLimit(2)
                                    Text(backup.modifiedAt, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(Self.byteString(backup.totalByteCount))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }

                            ForEach(backup.files) { file in
                                StoreRecoveryFileRow(file: file)
                                    .font(.caption)
                            }

                            Button {
                                backupPendingRestore = backup
                                isShowingRestoreConfirmation = true
                            } label: {
                                Label("Restore This Backup", systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)

                            Button {
                                exportFiles(backup.files, prefix: backup.name)
                            } label: {
                                Label("Export This Backup", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section {
                Button {
                    refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            } footer: {
                Text("This screen shows file names, sizes, and dates only. It does not open or export chat contents.")
            }
        }
        .navigationTitle("Local Data Recovery")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $isShowingExporter,
            document: exportDocument,
            contentType: .frontendAIBackup,
            defaultFilename: exportFileName
        ) { result in
            switch result {
            case .success:
                recoveryMessage = StoreRecoveryMessage(
                    title: "Backup Exported",
                    message: "The portable backup file was saved."
                )
            case let .failure(error):
                recoveryMessage = StoreRecoveryMessage(
                    title: "Export Failed",
                    message: error.localizedDescription
                )
            }
        }
        .fileImporter(
            isPresented: $isShowingImporter,
            allowedContentTypes: [.frontendAIBackup, .data],
            allowsMultipleSelection: false
        ) { result in
            importBackup(from: result)
        }
        .alert("Restore local data backup?", isPresented: $isShowingRestoreConfirmation) {
            Button("Restore", role: .destructive) {
                if let backupPendingRestore {
                    StoreRecoveryManager.scheduleRestore(backupPendingRestore)
                    snapshot = StoreRecoveryManager.recoverySnapshot()
                    isShowingRestartNotice = true
                }
            }
            Button("Cancel", role: .cancel) {
                backupPendingRestore = nil
            }
        } message: {
            Text("The app will restore this backup on the next launch. The current active store will be backed up first.")
        }
        .alert("Restore Scheduled", isPresented: $isShowingRestartNotice) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Close FrontendAI from the app switcher, then open it again. The selected backup will be restored during startup.")
        }
        .alert(item: $recoveryMessage) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        snapshot = StoreRecoveryManager.recoverySnapshot()
    }

    private func exportFiles(_ files: [StoreRecoveryFileSnapshot], prefix: String) {
        do {
            exportDocument = FrontendAIBackupDocument(
                data: try PortableStoreBackup.makeBackupData(from: files)
            )
            exportFileName = PortableStoreBackup.defaultFileName(prefix: prefix)
            isShowingExporter = true
        } catch {
            recoveryMessage = StoreRecoveryMessage(
                title: "Export Failed",
                message: error.localizedDescription
            )
        }
    }

    private func importBackup(from result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let backup = try PortableStoreBackup.importBackupData(Data(contentsOf: url))
            snapshot = StoreRecoveryManager.recoverySnapshot()
            backupPendingRestore = backup
            isShowingRestoreConfirmation = true
        } catch {
            recoveryMessage = StoreRecoveryMessage(
                title: "Import Failed",
                message: error.localizedDescription
            )
        }
    }

    private static func byteString(_ byteCount: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }
}

private struct StoreRecoveryMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct StoreRecoveryFileRow: View {
    let file: StoreRecoveryFileSnapshot

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .lineLimit(1)
                Text(file.modifiedAt, style: .time)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(ByteCountFormatter.string(fromByteCount: file.byteCount, countStyle: .file))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        LocalDataRecoveryView()
    }
}
