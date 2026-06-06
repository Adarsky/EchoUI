import SwiftUI
import SwiftData

struct SettingsSheetView: View {
    @Binding var isPresented: Bool
    @Binding var messageLength: Int
    @Binding var endpoint: String
    @Binding var apiStatusDisplayStyle: String
    var navName: String = "Settings"

    var body: some View {
        NavigationStack {
            SettingsPageView(
                messageLength: $messageLength,
                endpoint: $endpoint,
                apiStatusDisplayStyle: $apiStatusDisplayStyle,
                navName: navName
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}

struct SettingsPageView: View {
    @Binding var messageLength: Int
    @Binding var endpoint: String
    @Binding var apiStatusDisplayStyle: String
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var apiManager: APIManager

    @AppStorage("selectedServerUUID") private var selectedServerUUID: String = ""
    @AppStorage("openRouterBalancePingEnabled") private var openRouterBalancePingEnabled = true
    @AppStorage(OpenRouterAttributionStorageKeys.httpReferer) private var openRouterHTTPReferer = OpenRouterAttributionHeaders.defaultReferer
    @AppStorage(OpenRouterAttributionStorageKeys.xTitle) private var openRouterXTitle = OpenRouterAttributionHeaders.defaultTitle
    @AppStorage(OpenRouterAttributionStorageKeys.userAgent) private var openRouterUserAgent = OpenRouterAttributionHeaders.defaultUserAgent
    @Query private var servers: [APIServer]

    @State private var openRouterBalanceState: OpenRouterBalanceState = .disabled
    @State private var openRouterBalanceLastUpdated: Date?
    var navName: String = "Settings"

    var body: some View {
        List {
            Section(header: Text("Balance information")) {
                Toggle("OpenRouter balance", isOn: $openRouterBalancePingEnabled)

                if openRouterBalancePingEnabled {
                    Button {
                        Task {
                            await refreshOpenRouterBalance()
                        }
                    } label: {
                        OpenRouterBalancePanel(
                            server: selectedOpenRouterServer,
                            state: openRouterBalanceState,
                            balanceValue: openRouterBalanceValue,
                            subtitle: openRouterBalanceSubtitle,
                            valueColor: balanceValueColor,
                            accentColor: balanceAccentColor,
                            isLoading: isLoadingBalance,
                            lastUpdated: openRouterBalanceLastUpdated
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedOpenRouterServer == nil || isLoadingBalance)
                }
            }
            Section(header: Text("Customization")) {
                NavigationLink(destination: ChatAppearanceSettingsView()) {
                    Label("Chat Appearance", systemImage: "paintpalette")
                }
                NavigationLink(destination: FoldersSettingsSheet()) {
                    Label("Chat Folders", systemImage: "folder")
                }
                NavigationLink(destination: TokenSpeedChangeView()) {
                    Label("Token Speed", systemImage: "hare")
                }
                NavigationLink(destination: AppIconSettingsView()) {
                    Label("App Icon", systemImage: "app.dashed")
                }
                Picker(selection: $apiStatusDisplayStyle) {
                    ForEach(MainPageAPIStatusDisplayStyle.allCases) { style in
                        Text(style.displayName).tag(style.rawValue)
                    }
                } label: {
                    Label("Main Page API", systemImage: "network")
                }
            }

            Section(header: Text("Connection configuration")) {
                NavigationLink(destination: APIManagerView(selectedServer: .constant(nil)).environmentObject(apiManager)) {
                    Label("Manage API Servers", systemImage: "server.rack")
                }
            }
            Section(header: Text("iCloud settings")) {
                NavigationLink(destination: DeveloperSettingsView()) {
                    Label("iCloud backup", systemImage: "icloud")
                }
            }
            Section(header: Text("Data and storage")) {
                NavigationLink(destination: CacheView()) {
                    Label("Storage usage", systemImage: "chart.pie")
                }

                NavigationLink(destination: DataNetworkManagerView()) {
                    Label("Data usage", systemImage: "chart.bar")
                }
                NavigationLink(destination: TokenUsageView()) {
                    Label("Token usage", systemImage: "t.square")
                }
                NavigationLink(destination: StatsView()) {
                    Label("Characters statistics", systemImage: "crown")
                }
            }
            Section(header: Text("Developer settings")) {
                NavigationLink(destination: LocalDataRecoveryView()) {
                    Label("Local data recovery", systemImage: "externaldrive.badge.timemachine")
                }
                NavigationLink(destination: DeveloperSettingsView()) {
                    Label("Call settings", systemImage: "hammer")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationTitle(navName)
        .navigationBarTitleDisplayMode(.inline)
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
            server.apiKey ?? "",
            openRouterHTTPReferer,
            openRouterXTitle,
            openRouterUserAgent
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

    private var balanceAccentColor: Color {
        switch openRouterBalanceState {
        case .loaded:
            return .green
        case .loading:
            return .blue
        case .failed:
            return .red
        case .missingKey, .noActiveOpenRouter:
            return .orange
        case .disabled:
            return .secondary
        }
    }

    @MainActor
    private func refreshOpenRouterBalance() async {
        guard openRouterBalancePingEnabled else {
            openRouterBalanceState = .disabled
            openRouterBalanceLastUpdated = nil
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
            openRouterBalanceLastUpdated = .now
        } catch {
            openRouterBalanceState = .failed(error.localizedDescription)
            openRouterBalanceLastUpdated = .now
        }
    }
}

private struct OpenRouterBalancePanel: View {
    let server: APIServer?
    let state: OpenRouterBalanceState
    let balanceValue: String
    let subtitle: String
    let valueColor: Color
    let accentColor: Color
    let isLoading: Bool
    let lastUpdated: Date?

    private var serverLine: String {
        guard let server else { return "Select an OpenRouter server to enable credits." }
        let host = URL(string: server.baseURL)?.host ?? server.baseURL
        return "\(server.name) • \(host)"
    }

    private var badgeTitle: String {
        switch state {
        case .disabled:
            return "Off"
        case .noActiveOpenRouter:
            return "No server"
        case .missingKey:
            return "Needs key"
        case .loading:
            return "Checking"
        case .loaded:
            return "Live"
        case .failed:
            return "Error"
        }
    }

    private var badgeIcon: String {
        switch state {
        case .disabled:
            return "pause.circle"
        case .noActiveOpenRouter:
            return "server.rack"
        case .missingKey:
            return "key.slash"
        case .loading:
            return "arrow.triangle.2.circlepath"
        case .loaded:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private var lastUpdatedText: String? {
        guard let lastUpdated else { return nil }
        return "Checked \(lastUpdated.formatted(date: .omitted, time: .shortened))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image("AICompanyOpenRouter")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(accentColor)
                    .frame(width: 22, height: 22)
                    .padding(9)
                    .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("OpenRouter Credits")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(serverLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Label(badgeTitle, systemImage: badgeIcon)
                    .font(.caption2.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(accentColor.opacity(0.12), in: Capsule())
            }

            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(balanceValue)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 8)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                if let lastUpdatedText {
                    Text(lastUpdatedText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if case let .loaded(snapshot) = state,
               snapshot.totalCredits != nil || snapshot.totalUsage != nil {
                Divider()

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        balanceMetricViews(for: snapshot)
                    }

                    VStack(spacing: 8) {
                        balanceMetricViews(for: snapshot)
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func balanceMetricViews(for snapshot: OpenRouterBalanceSnapshot) -> some View {
        if let totalCredits = snapshot.totalCredits {
            OpenRouterBalanceMetricView(
                icon: "plus.circle",
                title: "Credits",
                value: totalCredits.formatted(.currency(code: "USD"))
            )
        }

        if let totalUsage = snapshot.totalUsage {
            OpenRouterBalanceMetricView(
                icon: "chart.line.uptrend.xyaxis",
                title: "Usage",
                value: totalUsage.formatted(.currency(code: "USD"))
            )
        }
    }
}

private struct OpenRouterBalanceMetricView: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
    @State private var apiStatusDisplayStyle = MainPageAPIStatusDisplayStyle.coloredDot.rawValue
    var navName: String = "Settings"

    var body: some View {
        SettingsSheetView(
            isPresented: $isPresented,
            messageLength: $messageLength,
            endpoint: $endpoint,
            apiStatusDisplayStyle: $apiStatusDisplayStyle,
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
    let schema = Schema([
        APIServer.self,
        BotModel.self,
        ChatHistory.self,
        ChatFolder.self,
        ChatMessageEntity.self
    ])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
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
