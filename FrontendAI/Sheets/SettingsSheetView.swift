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
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var apiManager: APIManager

    @AppStorage("selectedServerUUID") private var selectedServerUUID: String = ""
    @AppStorage("openRouterBalancePingEnabled") private var openRouterBalancePingEnabled = true
    @Query private var servers: [APIServer]

    @State private var openRouterBalanceState: OpenRouterBalanceState = .disabled
    var navName: String = "Settings"

    @Namespace private var settingsNavNamespace

    var body: some View {
        NavigationStack {
                List {
                    Section(header: Text("Customization")) {
                        NavigationLink(destination: ChatAppearanceSettingsView()) {
                            Label("Chat Appearance", systemImage: "paintpalette")
                        }
                        NavigationLink(destination: TokenSpeedChangeView()) {
                            Label("Token Speed", systemImage: "hare")
                        }
                        Toggle("Show API Status", systemImage:"network", isOn: $showAPIStatus)
                    }

                    Section(header: Text("Connection configuration")) {
                        NavigationLink(destination: APIManagerView(selectedServer: .constant(nil)).environmentObject(apiManager)) {
                            Label("Manage API Servers", systemImage: "server.rack")
                        }
                        NavigationLink(destination: VLESSProxiesManagerView()) {
                            Label("VLESS proxy", systemImage: "hat.widebrim")
                        }
/*                        NavigationLink(destination: HisteriumEnvironmentManager()) {
                            HStack {
                                Image(systemName: "network.badge.shield.half.filled")
                                Text("Histerium environment")
                            }
                        } */
                    }
                    Section(header: Text("Information")) {
                        Toggle("OpenRouter balance", isOn: $openRouterBalancePingEnabled)

                        if openRouterBalancePingEnabled {
                            HStack(spacing: 10) {
                                Image(systemName: "creditcard")
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
                .listStyle(.insetGrouped)
                .frame(maxWidth: 460, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .navigationTitle(navName)
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .onAppear {
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

        if server.migrateAPIKeyToKeychainIfNeeded() {
            try? modelContext.save()
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
                apiKey: apiKey,
                tlsPolicy: server.tlsPolicy
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
        .environmentObject(APIManager())
        .modelContainer(settingsPreviewModelContainer)
}

#Preview("Custom Nav Name") {
    SettingsSheetViewPreviewHost(navName: "App Settings")
        .environmentObject(APIManager())
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
