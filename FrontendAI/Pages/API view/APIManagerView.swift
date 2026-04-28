//
//  APIManagerView.swift
//  FrontendAI
//
//  Created by macbook on 21.10.2025.
//

import SwiftUI
import SwiftData

// MARK: - API Manager View

struct APIManagerView: View {
    @Environment(\.modelContext) var modelContext
    @Query var servers: [APIServer]
    @Binding var selectedServer: APIServer?
    @EnvironmentObject var apiManager: APIManager

    @State private var showCreateSheet = false
    @State private var editServer: APIServer? = nil

    private var activeServer: APIServer? {
        selectedServer ?? apiManager.selectedServer
    }

    private var activeServerName: String {
        activeServer?.name ?? "Not set"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .foregroundColor(.accentColor)
                        Text("Active endpoint:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(activeServerName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }

                ForEach(servers) { server in
                    ServerRowView(
                        server: server,
                        isActive: activeServer?.uuid == server.uuid,
                        onEdit: { editServer = server },
                        onSetActive: {
                            selectedServer = server
                            apiManager.selectedServer = server
                        },
                        onPing: { await ping(server: server) }
                    )
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            server.deleteAPIKeyFromKeychain()
                            modelContext.delete(server)
                            try? modelContext.save()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("API Servers")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreateSheet = true }) {
                        Label("Add", systemImage: "plus")
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
                var didMigrateLegacyKeys = false
                for server in servers {
                    if server.migrateAPIKeyToKeychainIfNeeded() {
                        didMigrateLegacyKeys = true
                    }
                }
                if didMigrateLegacyKeys {
                    try? modelContext.save()
                }

                for server in servers {
                    await ping(server: server)
                }
            }
        }
    }

    func ping(server: APIServer) async {
        let status = await APIManager.evaluateConnectionStatus(for: server)
        server.updateConnectionStatus(status)
        try? modelContext.save()
    }
}

// MARK: - Server Row View

struct ServerRowView: View {
    let server: APIServer
    let isActive: Bool
    let onEdit: () -> Void
    let onSetActive: () -> Void
    let onPing: () async -> Void

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
                Text(server.name)
                    .bold()
                if isActive {
                    Label("Active", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                Spacer()
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(server.connectionStatus.displayName)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Text("Model: \(server.selectedModel)")
                .font(.subheadline)

            Text("Type: \(server.type.displayName)")
                .font(.caption)
                .foregroundColor(.secondary)

            if let apiKey = server.apiKey, !apiKey.isEmpty {
                Text("API Key: ••••••••")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
