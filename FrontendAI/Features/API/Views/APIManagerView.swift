import SwiftUI
import SwiftData

// MARK: - API Manager View

struct APIManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var servers: [APIServer]
    @Binding private var selectedServer: APIServer?
    @EnvironmentObject private var apiManager: APIManager
    private let showsAddButton: Bool

    @State private var showCreateSheet = false
    @State private var editServer: APIServer? = nil
    @State private var operationErrorMessage = ""
    @State private var showOperationError = false

    init(selectedServer: Binding<APIServer?>, showsAddButton: Bool = true) {
        self._selectedServer = selectedServer
        self.showsAddButton = showsAddButton
    }

    private var activeServer: APIServer? {
        selectedServer ?? apiManager.selectedServer
    }

    private var activeServerName: String {
        activeServer?.name ?? "Not set"
    }

    private var pinnedServers: [APIServer] {
        APIServerOrganization.pinnedServers(from: servers)
    }

    private var serverGroups: [APIServerGroup] {
        APIServerOrganization.groups(from: servers)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .foregroundStyle(.tint)
                        Text("Active endpoint:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(activeServerName)
                            .font(.subheadline)
                            .bold()
                        Spacer()
                    }
                }

                if servers.isEmpty {
                    ContentUnavailableView(
                        "No API Servers",
                        systemImage: "server.rack",
                        description: Text("Add a server to choose an endpoint and model.")
                    )
                } else {
                    if !pinnedServers.isEmpty {
                        Section("Pinned") {
                            ForEach(pinnedServers) { server in
                                ServerRowView(
                                    server: server,
                                    isActive: activeServer?.uuid == server.uuid,
                                    onEdit: { editServer = server },
                                    onSetActive: { setActiveServer(server) },
                                    onPing: { await ping(server: server) },
                                    onDuplicate: { duplicateServer(server) },
                                    onTogglePin: { togglePin(for: server) },
                                    onDelete: { deleteServer(server) }
                                )
                            }
                            .onMove { source, destination in
                                moveServers(pinnedServers, from: source, to: destination)
                            }
                        }
                    }

                    ForEach(serverGroups) { group in
                        Section(group.title) {
                            ForEach(group.servers) { server in
                                ServerRowView(
                                    server: server,
                                    isActive: activeServer?.uuid == server.uuid,
                                    onEdit: { editServer = server },
                                    onSetActive: { setActiveServer(server) },
                                    onPing: { await ping(server: server) },
                                    onDuplicate: { duplicateServer(server) },
                                    onTogglePin: { togglePin(for: server) },
                                    onDelete: { deleteServer(server) }
                                )
                            }
                            .onMove { source, destination in
                                moveServers(group.servers, from: source, to: destination)
                            }
                        }
                    }
                }
            }
            .navigationTitle("API Servers")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if servers.count > 1 {
                        EditButton()

                        Menu("Sort Servers", systemImage: "arrow.up.arrow.down") {
                            ForEach(APIServerSortOption.allCases) { option in
                                Button(option.displayName, systemImage: option.systemImage) {
                                    sortServers(by: option)
                                }
                            }
                        }
                    }

                    if showsAddButton {
                        Button("Add API Server", systemImage: "plus") {
                            showCreateSheet = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateAPIServerView()
            }
            .sheet(item: $editServer) { server in
                CreateAPIServerView(editingServer: server)
            }
            .task {
                migrateLegacyAPIKeysIfNeeded()
            }
            .alert("Could Not Update API Servers", isPresented: $showOperationError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(operationErrorMessage)
            }
        }
    }

    private func setActiveServer(_ server: APIServer) {
        selectedServer = server
        apiManager.selectedServer = server
    }

    @MainActor
    private func migrateLegacyAPIKeysIfNeeded() {
        let didMigrateLegacyKeys = servers.reduce(into: false) { didMigrate, server in
            didMigrate = server.migrateAPIKeyToKeychainIfNeeded() || didMigrate
        }

        if didMigrateLegacyKeys {
            try? modelContext.save()
        }
    }

    private func ping(server: APIServer) async {
        let status = await APIManager.evaluateConnectionStatus(for: server)
        server.updateConnectionStatus(status)
        saveChanges()
    }

    @MainActor
    private func duplicateServer(_ server: APIServer) {
        let peers = APIServerOrganization.peers(of: server, in: servers)
        let sourceIndex = peers.firstIndex { $0.uuid == server.uuid } ?? max(peers.count - 1, 0)
        let insertionIndex = sourceIndex + 1

        for (index, peer) in peers.enumerated() where index >= insertionIndex {
            peer.sortOrder = index + 1
        }
        for (index, peer) in peers.enumerated() where index < insertionIndex {
            peer.sortOrder = index
        }

        do {
            let clone = try APIServerCloner.clone(
                server,
                name: APIServerOrganization.suggestedCloneName(for: server, among: servers),
                sortOrder: insertionIndex,
                in: modelContext
            )
            editServer = clone
        } catch {
            modelContext.rollback()
            presentOperationError(error)
        }
    }

    @MainActor
    private func togglePin(for server: APIServer) {
        let sourcePeers = APIServerOrganization.peers(of: server, in: servers)
            .filter { $0.uuid != server.uuid }
        APIServerOrganization.applyManualOrder(sourcePeers)

        server.isPinned.toggle()
        let destinationPeers = APIServerOrganization.peers(of: server, in: servers)
            .filter { $0.uuid != server.uuid }
        APIServerOrganization.applyManualOrder(destinationPeers + [server])
        saveChanges()
    }

    @MainActor
    private func moveServers(_ orderedServers: [APIServer], from source: IndexSet, to destination: Int) {
        var reorderedServers = orderedServers
        reorderedServers.move(fromOffsets: source, toOffset: destination)
        APIServerOrganization.applyManualOrder(reorderedServers)
        saveChanges()
    }

    @MainActor
    private func sortServers(by option: APIServerSortOption) {
        APIServerOrganization.applyManualOrder(
            APIServerOrganization.sorted(pinnedServers, by: option)
        )
        for group in serverGroups {
            APIServerOrganization.applyManualOrder(
                APIServerOrganization.sorted(group.servers, by: option)
            )
        }
        saveChanges()
    }

    @MainActor
    private func deleteServer(_ server: APIServer) {
        let uuid = server.uuid
        let wasActive = activeServer?.uuid == uuid

        let previousAPIKey: String?
        do {
            previousAPIKey = try server.readAPIKeyFromKeychain()
            try server.setAPIKeyInKeychain(nil)
        } catch {
            presentOperationError(error)
            return
        }

        modelContext.delete(server)
        do {
            try modelContext.save()
            if wasActive {
                selectedServer = nil
                apiManager.selectedServer = nil
            }
        } catch {
            let persistenceError = error
            modelContext.rollback()
            do {
                try server.setAPIKeyInKeychain(previousAPIKey)
            } catch {
                operationErrorMessage = "\(persistenceError.localizedDescription)\n\nThe previous API key could not be restored: \(error.localizedDescription)"
                showOperationError = true
                return
            }
            presentOperationError(persistenceError)
        }
    }

    @MainActor
    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            presentOperationError(error)
        }
    }

    private func presentOperationError(_ error: Error) {
        operationErrorMessage = error.localizedDescription
        showOperationError = true
    }
}

// MARK: - Server Row View

struct ServerRowView: View {
    let server: APIServer
    let isActive: Bool
    let onEdit: () -> Void
    let onSetActive: () -> Void
    let onPing: () async -> Void
    let onDuplicate: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    private var statusColor: Color {
        switch server.connectionStatus {
        case .online:
            return .green
        case .warning:
            return .orange
        case .offline:
            return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                OpenRouterCompanyIconView(
                    assetName: server.type == .openrouter ? "AICompanyOpenRouter" : "AICompanyOpenAI"
                )

                Text(server.name)
                    .bold()
                if isActive {
                    Label("Active", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                if server.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Pinned")
                }
                Spacer()
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(server.connectionStatus.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Model: \(server.selectedModel)")
                .font(.subheadline)

            Text("Type: \(server.type.displayName)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Thinking: \(server.thinkingEffort.displayName)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let apiKey = server.apiKey, !apiKey.isEmpty {
                Text("API Key: ••••••••")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button(isActive ? "Active" : "Set Active") {
                    onSetActive()
                }
                .disabled(isActive)

                Button("Restart") {
                    Task { await onPing() }
                }

                Button("Edit") {
                    onEdit()
                }
            }
            .buttonStyle(.glass)
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(server.isPinned ? "Unpin" : "Pin", systemImage: server.isPinned ? "pin.slash" : "pin", action: onTogglePin)
                .tint(.orange)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            Button("Duplicate", systemImage: "plus.square.on.square", action: onDuplicate)
                .tint(.blue)
        }
        .contextMenu {
            Button(isActive ? "Active" : "Set Active", systemImage: "checkmark.circle", action: onSetActive)
                .disabled(isActive)
            Button("Edit", systemImage: "pencil", action: onEdit)
            Button("Duplicate", systemImage: "plus.square.on.square", action: onDuplicate)
            Button(server.isPinned ? "Unpin" : "Pin", systemImage: server.isPinned ? "pin.slash" : "pin", action: onTogglePin)
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}

// MARK: - Preview

#Preview {
    APIManagerViewPreviewHost()
        .modelContainer(previewModelContainer)
        .environmentObject(APIManager())
}

@MainActor
private let previewModelContainer: ModelContainer = {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: APIServer.self, configurations: config)
    let context = container.mainContext

    context.insert(
        APIServer(
            name: "OpenAI Prod",
            baseURL: "https://api.openai.com",
            selectedModel: "gpt-4.1-mini",
            availableModels: ["gpt-4.1-mini", "gpt-4.1"],
            type: .openai,
            isOnline: true,
            apiKey: "sk-preview"
        )
    )
    context.insert(
        APIServer(
            name: "OpenRouter Backup",
            baseURL: "https://openrouter.ai",
            selectedModel: "openai/gpt-4o-mini",
            type: .openrouter,
            isOnline: false
        )
    )
    try? context.save()

    return container
}()

private struct APIManagerViewPreviewHost: View {
    @State private var selectedServer: APIServer?

    var body: some View {
        APIManagerView(selectedServer: $selectedServer)
    }
}
