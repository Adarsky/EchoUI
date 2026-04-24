//
//  APIManagerView.swift
//  FrontendAI
//
//  Created by macbook on 21.10.2025.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

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
    
    // MARK: - Ping Server
    
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
            // Header with status
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
            
            // Model info
            Text("Model: \(server.selectedModel)")
                .font(.subheadline)
            
            // Type info
            Text("Type: \(server.type.displayName)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // API Key status
            if let apiKey = server.apiKey, !apiKey.isEmpty {
                Text("API Key: ••••••••")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Action buttons
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

// MARK: - Create/Edit API Server View

struct CreateAPIServerView: View {
    private enum HTTPAPIKeyWarningAction {
        case save
        case loadModels
    }

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    @State private var name: String = ""
    @State private var baseURL: String = ""
    @State private var selectedModel: String = ""
    @State private var availableModels: [String] = []
    @State private var selectedType: APIType = .openai
    @State private var apiKey: String = ""
    @State private var isLoadingModels: Bool = false
    @State private var allowInsecureTLS: Bool = false
    @State private var customCACertificateData: Data? = nil
    @State private var customCACertificateName: String = ""
    @State private var isImportingTLSCertificate: Bool = false
    @State private var showTLSImportError: Bool = false
    @State private var tlsImportErrorMessage: String = ""
    @State private var showTLSConfigurationAlert: Bool = false
    @State private var showHTTPAPIKeyWarning: Bool = false
    @State private var pendingHTTPAPIKeyWarningAction: HTTPAPIKeyWarningAction? = nil
    
    private let maxServerNameLength = 24
    
    var editingServer: APIServer? = nil
    
    private var isOpenRouter: Bool { selectedType == .openrouter }
    
    var body: some View {
        NavigationStack {
            Form {
                serverDetailsSection
                modelSelectionSection
                tlsSection
                
            }
            .navigationTitle(editingServer == nil ? "Add API Server" : "Edit API Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveServer()
                    }
                    .disabled(!canSave)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadExistingServerData()
            }
            .onChange(of: selectedType) { old, new in
                if new == .openrouter {
                    availableModels.removeAll()
                }
            }
            .fileImporter(
                isPresented: $isImportingTLSCertificate,
                allowedContentTypes: [.data],
                allowsMultipleSelection: false
            ) { result in
                handleTLSCertificateImport(result)
            }
            .alert("TLS Certificate Import Failed", isPresented: $showTLSImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(tlsImportErrorMessage)
            }
            .alert("TLS Certificate Required", isPresented: $showTLSConfigurationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Import the exact CA certificate for your endpoint before enabling custom TLS.")
            }
            .alert("API Key Over HTTP", isPresented: $showHTTPAPIKeyWarning) {
                Button("Continue", role: .destructive) {
                    continuePendingHTTPAPIKeyAction()
                }
                Button("Cancel", role: .cancel) {
                    pendingHTTPAPIKeyWarningAction = nil
                }
            } message: {
                Text("This endpoint uses plain HTTP. Your API key and chat traffic may be visible on the network. Continue only for local or fully trusted endpoints.")
            }
        }
    }
    
    private var serverDetailsSection: some View {
        Section(header: Text("Server Details")) {
            TextField("Name", text: $name)
                .autocorrectionDisabled()
                .onChange(of: name) { _, newValue in
                    name = String(newValue.prefix(maxServerNameLength))
                }
            
            TextField("Base URL", text: $baseURL)
                .autocapitalization(.none)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .onSubmit {
                    if !isOpenRouter {
                        requestFetchModels()
                    }
                }

            if isOpenRouter {
                Button("Use Official OpenRouter URL") {
                    baseURL = "https://openrouter.ai"
                }
            }
            
            Picker("Type", selection: $selectedType) {
                ForEach(APIType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            
            SecureField("API Key (optional)", text: $apiKey)
                .autocapitalization(.none)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.oneTimeCode)
                .privacySensitive()
        }
    }
    
    private var modelSelectionSection: some View {
        Section(header: Text("Model Selection"), footer: Text("Enter the exact OpenRouter model ID (provider/model). The list of models is not loaded for OpenRouter.")) {
            if isOpenRouter {
                TextField("Model name (e.g. openai/gpt-4o-mini)", text: $selectedModel)
                    .autocapitalization(.none)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else if availableModels.isEmpty {
                Button {
                    requestFetchModels()
                } label: {
                    HStack {
                        Text("Load Models")
                        if isLoadingModels {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(baseURL.isEmpty || isLoadingModels)
            } else {
                Picker("Select Model", selection: $selectedModel) {
                    ForEach(availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                
                Button("Reload Models") {
                    requestFetchModels()
                }
                .disabled(isLoadingModels)
            }
        }
    }
    
    private var tlsSection: some View {
        Section(header: Text("TLS"), footer: Text(tlsFooterText)) {
            
            Toggle("Use custom CA for self-signed TLS", isOn: $allowInsecureTLS)
            
            if allowInsecureTLS {
/*                Text("Connections are rejected unless the exact CA certificate is imported.")
                    .font(.footnote)
                    .foregroundStyle(.red)*/

                Button(customCACertificateData == nil ? "Import CA Certificate (.crt/.pem/.cer)" : "Replace CA Certificate") {
                    isImportingTLSCertificate = true
                }
                
                if customCACertificateData != nil {
                    Button("Remove Trusted Certificate", role: .destructive) {
                        customCACertificateData = nil
                        customCACertificateName = ""
                    }
                }
            }
        }
    }
    
    private var tlsFooterText: String {
        let guidance = "Enable this only when you can import the exact CA certificate for your endpoint. The app never trusts unknown certificates."
        if allowInsecureTLS && !customCACertificateName.isEmpty {
            return "Trusted certificate: \(customCACertificateName)\n\n\(guidance)"
        }
        return guidance
    }
    
    // MARK: - Computed Properties
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (!allowInsecureTLS || customCACertificateData != nil)
    }
    
    // MARK: - Methods
    
    private func loadExistingServerData() {
        guard let server = editingServer else { return }
        
        name = server.name
        baseURL = server.baseURL
        selectedModel = server.selectedModel
        availableModels = server.availableModels
        selectedType = server.type
        apiKey = server.apiKey ?? ""
        allowInsecureTLS = server.allowInsecureTLS
        customCACertificateData = server.customCACertificateData
        customCACertificateName = server.customCACertificateName ?? ""
    }
    
    private func saveServer(confirmedHTTPAPIKey: Bool = false) {
        let normalizedName = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxServerNameLength))
        let normalizedBaseURL = selectedType.normalizedBaseURL(baseURL)
        let normalizedModel = selectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if allowInsecureTLS && customCACertificateData == nil {
            showTLSConfigurationAlert = true
            return
        }

        if !confirmedHTTPAPIKey,
           selectedType.requiresHTTPAPIKeyConfirmation(baseURL: normalizedBaseURL, apiKey: normalizedAPIKey) {
            pendingHTTPAPIKeyWarningAction = .save
            showHTTPAPIKeyWarning = true
            return
        }

        if let server = editingServer {
            // Update existing server
            server.name = normalizedName
            server.baseURL = normalizedBaseURL
            server.selectedModel = normalizedModel
            server.availableModels = isOpenRouter ? [] : availableModels
            server.type = selectedType
            server.apiKey = normalizedAPIKey.isEmpty ? nil : normalizedAPIKey
            server.allowInsecureTLS = allowInsecureTLS
            server.customCACertificateData = customCACertificateData
            server.customCACertificateName = customCACertificateName.isEmpty ? nil : customCACertificateName
        } else {
            // Create new server
            let newServer = APIServer(
                name: normalizedName,
                baseURL: normalizedBaseURL,
                selectedModel: normalizedModel,
                availableModels: isOpenRouter ? [] : availableModels,
                type: selectedType,
                apiKey: normalizedAPIKey.isEmpty ? nil : normalizedAPIKey,
                allowInsecureTLS: allowInsecureTLS,
                customCACertificateData: customCACertificateData,
                customCACertificateName: customCACertificateName.isEmpty ? nil : customCACertificateName
            )
            modelContext.insert(newServer)
        }
        
        try? modelContext.save()
        dismiss()
    }

    private func requestFetchModels() {
        let normalizedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if selectedType.requiresHTTPAPIKeyConfirmation(baseURL: baseURL, apiKey: normalizedAPIKey) {
            pendingHTTPAPIKeyWarningAction = .loadModels
            showHTTPAPIKeyWarning = true
            return
        }

        Task { await fetchModels() }
    }

    private func continuePendingHTTPAPIKeyAction() {
        let action = pendingHTTPAPIKeyWarningAction
        pendingHTTPAPIKeyWarningAction = nil

        switch action {
        case .save:
            saveServer(confirmedHTTPAPIKey: true)
        case .loadModels:
            Task { await fetchModels() }
        case .none:
            break
        }
    }
    
    private func fetchModels() async {
        guard !isOpenRouter else { return }
        
        isLoadingModels = true
        defer { isLoadingModels = false }
        
        let modelURL = selectedType.endpoint(baseURL: baseURL, path: "models")
        
        guard let url = URL(string: modelURL) else {
            print("Invalid URL: \(modelURL)")
            return
        }
        
        var request = URLRequest(url: url)
        
        if !apiKey.isEmpty {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let tlsPolicy = TLSPolicy(
                allowInsecureTLS: allowInsecureTLS,
                customCACertificateData: customCACertificateData
            )
            let session = TLSSessionFactory.makeSession(policy: tlsPolicy)
            let (data, _) = try await session.data(for: request)
            
            if let result = try? JSONDecoder().decode(OpenAIModelList.self, from: data) {
                availableModels = result.data.map { $0.id }
                
                if selectedModel.isEmpty || !availableModels.contains(selectedModel) {
                    selectedModel = availableModels.first ?? ""
                }
            }
        } catch {
            print("Failed to fetch models: \(error.localizedDescription)")
        }
    }

    private func handleTLSCertificateImport(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }

            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            guard !TLSCertificateDecoder.decodeCertificates(from: data).isEmpty else {
                throw TLSCertificateImportError.invalidCertificate
            }

            customCACertificateData = data
            customCACertificateName = url.lastPathComponent
        } catch {
            tlsImportErrorMessage = error.localizedDescription
            showTLSImportError = true
        }
    }
}

private enum TLSCertificateImportError: LocalizedError {
    case invalidCertificate

    var errorDescription: String? {
        switch self {
        case .invalidCertificate:
            return "The selected file is not a valid X.509 certificate (.crt/.pem/.cer)."
        }
    }
}

// MARK: - Models

struct OpenAIModelList: Codable {
    struct Model: Codable {
        let id: String
    }
    let data: [Model]
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
