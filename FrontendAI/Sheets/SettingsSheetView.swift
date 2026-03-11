//
//  SettingsSheetView.swift
//  FrontendAI
//
//  Created by macbook on 27.03.2025.
//

import SwiftUI
import SwiftData

struct SettingsSheetView: View {
    @Binding var isPresented: Bool
    @Binding var messageLength: Int
    @Binding var endpoint: String
    @Binding var showAPIStatus: Bool
    @AppStorage(ChatStreamingStorageKeys.chunkFlushIntervalMs) private var streamChunkFlushIntervalMs = ChatStreamingDefaults.chunkFlushIntervalMs
    @AppStorage("selectedServerUUID") private var selectedServerUUID: String = ""
    @AppStorage("openRouterBalancePingEnabled") private var openRouterBalancePingEnabled = true
    @Query private var servers: [APIServer]

    @State private var showChunkTimeInfo = false
    @State private var openRouterBalanceState: OpenRouterBalanceState = .disabled
    var navName: String = "Settings"

    @Namespace private var settingsNavNamespace

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                List {
                    Section(header: Text("Customization")) {
                        NavigationLink(destination: ChatAppearanceSettingsView()) {
                            HStack {
                                Image(systemName: "paintpalette")
                                Text("Chat Appearance")
                            }
                        }
                        Toggle("Show API Status", isOn: $showAPIStatus)
                    }

                    Section(header: Text("Connection configuration")) {
                        NavigationLink(destination: APIManagerView(selectedServer: .constant(nil))) {
                            HStack {
                                Image(systemName: "server.rack")
                                Text("Manage API Servers")
                            }
                        }
                        HStack {
                            Image(systemName: "hare")
                            Text("Chunk time: \(Int(streamChunkFlushIntervalMs.rounded())) ms")
                            Spacer()
                            Button {
                                showChunkTimeInfo = true
                            } label: {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityLabel("Chunk time info")
                        }
                        HStack {
                            Slider(
                                value: $streamChunkFlushIntervalMs,
                                in: ChatStreamingDefaults.minChunkFlushIntervalMs...ChatStreamingDefaults.maxChunkFlushIntervalMs,
                                step: 10
                            )
                            Button() {
                                streamChunkFlushIntervalMs = ChatStreamingDefaults.chunkFlushIntervalMs
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                            }
                            .buttonStyle(.glass)
                        }
                    }
                    Section(header: Text("Information")) {
                        Toggle("OpenRouter balance", isOn: $openRouterBalancePingEnabled)

                        if openRouterBalancePingEnabled {
                            HStack(spacing: 10) {
                                Image(systemName: "creditcard")
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("OpenRouter balance")
                                    Text(openRouterBalanceSubtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                if isLoadingBalance {
                                    ProgressView()
                                }
                                Text(openRouterBalanceValue)
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(balanceValueColor)
                            }

                            Button {
                                Task {
                                    await refreshOpenRouterBalance()
                                }
                            } label: {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                            .disabled(selectedOpenRouterServer == nil || isLoadingBalance)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .frame(maxWidth: 460, alignment: .leading)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .navigationTitle(navName)
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .onAppear {
                streamChunkFlushIntervalMs = ChatStreamingDefaults.clampedChunkFlushIntervalMs(streamChunkFlushIntervalMs)
                Task {
                    await refreshOpenRouterBalance()
                }
            }
            .onChange(of: openRouterBalancePingEnabled) { _, _ in
                Task {
                    await refreshOpenRouterBalance()
                }
            }
            .onChange(of: openRouterServerSignature) { _, _ in
                Task {
                    await refreshOpenRouterBalance()
                }
            }
            .alert("Chunk Time", isPresented: $showChunkTimeInfo) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This controls how often streamed LLM text is flushed to the chat UI. Lower values update text more frequently with smaller chunks. Higher values batch more text per update, which can feel less live but may reduce UI update overhead.")
            }
        }
    }

    private var selectedServer: APIServer? {
        guard let selectedUUID = UUID(uuidString: selectedServerUUID) else { return nil }
        return servers.first(where: { $0.uuid == selectedUUID })
    }

    private var selectedOpenRouterServer: APIServer? {
        guard let selectedServer, selectedServer.type == .openrouter else { return nil }
        return selectedServer
    }

    private var openRouterServerSignature: String {
        guard let server = selectedOpenRouterServer else { return "none" }
        return [
            server.uuid.uuidString,
            server.baseURL,
            server.apiKey ?? ""
        ].joined(separator: "|")
    }

    private var isLoadingBalance: Bool {
        if case .loading = openRouterBalanceState {
            return true
        }
        return false
    }

    private var openRouterBalanceValue: String {
        switch openRouterBalanceState {
        case .disabled:
            return "Off"
        case .noActiveOpenRouter, .missingKey:
            return "N/A"
        case .loading:
            return "--"
        case let .loaded(snapshot):
            if let balance = snapshot.balance {
                return balance.formatted(.currency(code: "USD"))
            }
            if let totalCredits = snapshot.totalCredits {
                return totalCredits.formatted(.currency(code: "USD"))
            }
            return "N/A"
        case .failed:
            return "Error"
        }
    }

    private var openRouterBalanceSubtitle: String {
        switch openRouterBalanceState {
        case .disabled:
            return "Ping is disabled"
        case .noActiveOpenRouter:
            return "No active OpenRouter API"
        case .missingKey:
            return "Active OpenRouter server has no API key"
        case .loading:
            return "Fetching balance..."
        case let .loaded(snapshot):
            if let totalUsage = snapshot.totalUsage, let totalCredits = snapshot.totalCredits {
                return "Usage \(totalUsage.formatted(.currency(code: "USD"))) / Credits \(totalCredits.formatted(.currency(code: "USD")))."
            }
            if let totalUsage = snapshot.totalUsage {
                return "Usage \(totalUsage.formatted(.currency(code: "USD")))."
            }
            return "Connected, but no balance fields were returned"
        case let .failed(message):
            return message
        }
    }

    private var balanceValueColor: Color {
        switch openRouterBalanceState {
        case .loaded:
            return .green
        case .failed:
            return .red
        default:
            return .secondary
        }
    }

    @MainActor
    private func refreshOpenRouterBalance() async {
        guard openRouterBalancePingEnabled else {
            openRouterBalanceState = .disabled
            return
        }

        guard let server = selectedOpenRouterServer else {
            openRouterBalanceState = .noActiveOpenRouter
            return
        }

        let apiKey = (server.apiKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            openRouterBalanceState = .missingKey
            return
        }

        openRouterBalanceState = .loading

        do {
            let snapshot = try await OpenRouterBalanceService.fetchBalance(
                baseURL: server.baseURL,
                apiKey: apiKey
            )
            openRouterBalanceState = .loaded(snapshot)
        } catch {
            openRouterBalanceState = .failed(error.localizedDescription)
        }
    }
}

private enum OpenRouterBalanceState {
    case disabled
    case noActiveOpenRouter
    case missingKey
    case loading
    case loaded(OpenRouterBalanceSnapshot)
    case failed(String)
}

private struct SettingsSheetViewPreviewHost: View {
    @State private var isPresented = true
    @State private var messageLength = 1024
    @State private var endpoint = "http://localhost:1234/v1"
    @State private var showAPIStatus = true
    var navName: String = "Settings"

    var body: some View {
        SettingsSheetView(
            isPresented: $isPresented,
            messageLength: $messageLength,
            endpoint: $endpoint,
            showAPIStatus: $showAPIStatus,
            navName: navName
        )
    }
}

#Preview {
    SettingsSheetViewPreviewHost()
        .modelContainer(settingsPreviewModelContainer)
}

#Preview("Custom Nav Name") {
    SettingsSheetViewPreviewHost(navName: "App Settings")
        .environment(\.locale, .init(identifier: "en"))
        .modelContainer(settingsPreviewModelContainer)
}

@MainActor
private let settingsPreviewModelContainer: ModelContainer = {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: APIServer.self, configurations: config)
    let context = container.mainContext

    context.insert(
        APIServer(
            name: "OpenRouter Preview",
            baseURL: "https://openrouter.ai",
            selectedModel: "openai/gpt-4o-mini",
            type: .openrouter,
            apiKey: "sk-preview"
        )
    )
    try? context.save()

    return container
}()
