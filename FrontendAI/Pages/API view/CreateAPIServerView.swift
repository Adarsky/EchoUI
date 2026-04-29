//
//  CreateAPIServerView.swift
//  FrontendAI
//
//  Created by Codex on 25.04.2026.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

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
    @State private var openRouterModels: [OpenRouterModel] = []
    @State private var loadedOpenRouterModelsBaseURL: String? = nil
    @State private var openRouterModelLoadMessage: String = ""
    @State private var selectedType: APIType = .openai
    @State private var apiKey: String = ""
    @State private var isLoadingModels: Bool = false
    @State private var isSavingServer: Bool = false
    @State private var allowInsecureTLS: Bool = false
    @State private var customCACertificateData: Data? = nil
    @State private var customCACertificateName: String = ""
    @State private var isImportingTLSCertificate: Bool = false
    @State private var showTLSImportError: Bool = false
    @State private var tlsImportErrorMessage: String = ""
    @State private var showTLSConfigurationAlert: Bool = false
    @State private var showHTTPAPIKeyWarning: Bool = false
    @State private var pendingHTTPAPIKeyWarningAction: HTTPAPIKeyWarningAction? = nil
    @State private var showOpenRouterModelAlert: Bool = false
    @State private var openRouterModelAlertMessage: String = ""
    @State private var showOpenRouterModelSearch: Bool = false
    @State private var openRouterModelSearchText: String = ""

    private let maxServerNameLength = 24

    var editingServer: APIServer? = nil

    private var isOpenRouter: Bool { selectedType == .openrouter }

    private var usesOfficialOpenRouterCatalog: Bool {
        isOpenRouter && OpenRouterModelCatalogService.requiresOfficialCatalogValidation(baseURL: baseURL)
    }

    var body: some View {
        NavigationStack {
            formContent
        }
    }

    private var formContent: some View {
        Form {
            serverDetailsSection
            modelSelectionSection
            tlsSection
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onAppear {
            loadExistingServerData()
            loadCachedModelsForCurrentConfiguration()
        }
        .onChange(of: selectedType, handleSelectedTypeChange)
        .onChange(of: baseURL, handleBaseURLChange)
        .fileImporter(
            isPresented: $isImportingTLSCertificate,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false,
            onCompletion: handleTLSCertificateImport
        )
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
            httpAPIKeyWarningButtons
        } message: {
            Text("This endpoint uses plain HTTP. API keys are not sent over HTTP, but chat traffic may still be visible on the network. Continue only for local or fully trusted endpoints.")
        }
        .alert("OpenRouter Model", isPresented: $showOpenRouterModelAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(openRouterModelAlertMessage)
        }
        .fullScreenCover(isPresented: $showOpenRouterModelSearch) {
            OpenRouterModelSearchView(
                searchText: $openRouterModelSearchText,
                models: openRouterModels,
                isLoadingModels: isLoadingModels,
                isModelLoadDisabled: baseURL.isEmpty || isLoadingModels,
                onLoadModels: requestFetchModels,
                onUseTypedModel: useTypedOpenRouterModelID,
                onCancel: {
                    showOpenRouterModelSearch = false
                },
                onSelectModel: selectOpenRouterModelFromSearch
            )
        }
    }

    private var navigationTitle: String {
        editingServer == nil ? "Add API Server" : "Edit API Server"
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                Task { await saveServer() }
            }
            .disabled(!canSave || isSavingServer)
        }

        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                dismiss()
            }
        }
    }

    @ViewBuilder
    private var httpAPIKeyWarningButtons: some View {
        Button("Continue", role: .destructive) {
            continuePendingHTTPAPIKeyAction()
        }
        Button("Cancel", role: .cancel) {
            pendingHTTPAPIKeyWarningAction = nil
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
        Section(header: Text("Model Selection"), footer: modelSelectionFooterContent) {
            if isOpenRouter {
                openRouterModelSelectionContent
            } else if availableModels.isEmpty {
                ModelLoadButton(
                    title: "Load Models",
                    isLoading: isLoadingModels,
                    action: requestFetchModels
                )
                .disabled(baseURL.isEmpty || isLoadingModels)
            } else {
                openAIModelPickerContent
            }
        }
    }

    @ViewBuilder
    private var modelSelectionFooterContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(modelSelectionFooterText)

            if isOpenRouter {
                openRouterLoadMessageView
            }
        }
    }

    @ViewBuilder
    private var openRouterModelSelectionContent: some View {
        if usesOfficialOpenRouterCatalog {
            Button {
                openOpenRouterModelSearch()
            } label: {
                NavigationLink(destination: TokenSpeedChangeView()) {
                    Label(selectedModel.isEmpty ? "Search OpenRouter models" : selectedModel, systemImage: "magnifyingglass")
                }
            }
        } else {
            TextField("Model ID (e.g. z-ai/glm-5v-turbo)", text: $selectedModel)
                .autocapitalization(.none)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        
        if !usesOfficialOpenRouterCatalog {
            openRouterSearchResultContent
        }
    }

    @ViewBuilder
    private var openRouterLoadMessageView: some View {
        if !openRouterModelLoadMessage.isEmpty {
            Text(openRouterModelLoadMessage)
                .font(.footnote)
                .foregroundColor(openRouterModels.isEmpty ? .red : .secondary)
        }
    }

    @ViewBuilder
    private var openRouterSearchResultContent: some View {
        if !openRouterSearchResults.isEmpty {
            ForEach(openRouterSearchResults) { model in
                OpenRouterModelSuggestionRow(model: model) {
                    selectedModel = model.id
                }
            }
        } else if hasOpenRouterModelQuery && !openRouterModels.isEmpty {
            Text("No matching OpenRouter models.")
                .font(.footnote)
                .foregroundColor(.secondary)
        } else if hasOpenRouterModelQuery && openRouterModels.isEmpty {
            Text("Load OpenRouter models to search and verify this ID.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var openAIModelPickerContent: some View {
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

    private var tlsSection: some View {
        Section(header: Text("TLS"), footer: Text(tlsFooterText)) {
            Toggle("Use custom CA for self-signed TLS", isOn: $allowInsecureTLS)

            if allowInsecureTLS {
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

    private var modelSelectionFooterText: String {
        if isOpenRouter {
            if OpenRouterModelCatalogService.requiresOfficialCatalogValidation(baseURL: baseURL) {
                return "Tap the model field to search the official OpenRouter catalog. Models are verified before saving."
            }
            return "Enter the exact model ID for this custom OpenRouter-compatible endpoint."
        }
        return "Load the model list from this OpenAI-compatible endpoint."
    }

    private var openRouterSearchResults: [OpenRouterModel] {
        OpenRouterModelCatalogService.search(openRouterModels, matching: selectedModel)
    }

    private var hasOpenRouterModelQuery: Bool {
        !selectedModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (!allowInsecureTLS || customCACertificateData != nil)
    }

    private func loadExistingServerData() {
        guard let server = editingServer else { return }

        name = server.name
        baseURL = server.baseURL
        selectedModel = server.selectedModel
        availableModels = server.availableModels
        selectedType = server.type
        if server.type == .openrouter {
            openRouterModels = server.availableModels.map { OpenRouterModel(id: $0) }
            loadedOpenRouterModelsBaseURL = server.availableModels.isEmpty ? nil : APIType.openrouter.normalizedBaseURL(server.baseURL)
        }
        apiKey = server.apiKey ?? ""
        allowInsecureTLS = server.allowInsecureTLS
        customCACertificateData = server.customCACertificateData
        customCACertificateName = server.customCACertificateName ?? ""
    }

    private func handleSelectedTypeChange(_ oldValue: APIType, _ newValue: APIType) {
        openRouterModelLoadMessage = ""

        if newValue == .openrouter {
            availableModels.removeAll()
        } else {
            openRouterModels.removeAll()
            loadedOpenRouterModelsBaseURL = nil
        }

        loadCachedModelsForCurrentConfiguration()
    }

    private func handleBaseURLChange(_ oldValue: String, _ newValue: String) {
        if editingServer != nil && oldValue.isEmpty {
            return
        }
        resetLoadedModelsForBaseURLChange()
        loadCachedModelsForCurrentConfiguration()
    }

    private func openOpenRouterModelSearch() {
        loadCachedModelsForCurrentConfiguration()
        openRouterModelSearchText = selectedModel
        showOpenRouterModelSearch = true
    }

    private func useTypedOpenRouterModelID() {
        let normalizedModel = openRouterModelSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedModel.isEmpty else { return }

        selectedModel = normalizedModel
        showOpenRouterModelSearch = false
    }

    private func selectOpenRouterModelFromSearch(_ model: OpenRouterModel) {
        selectedModel = model.id
        openRouterModelSearchText = model.id
        showOpenRouterModelSearch = false
    }

    @MainActor
    private func saveServer(confirmedHTTPAPIKey: Bool = false) async {
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

        isSavingServer = true
        defer { isSavingServer = false }

        guard await validateOpenRouterModelIfNeeded(
            baseURL: normalizedBaseURL,
            modelID: normalizedModel,
            apiKey: normalizedAPIKey
        ) else {
            return
        }

        let modelsToPersist = isOpenRouter ? openRouterModels.map(\.id) : availableModels

        if let server = editingServer {
            server.name = normalizedName
            server.baseURL = normalizedBaseURL
            server.selectedModel = normalizedModel
            server.availableModels = modelsToPersist
            server.type = selectedType
            server.apiKey = normalizedAPIKey.isEmpty ? nil : normalizedAPIKey
            server.allowInsecureTLS = allowInsecureTLS
            server.customCACertificateData = customCACertificateData
            server.customCACertificateName = customCACertificateName.isEmpty ? nil : customCACertificateName
        } else {
            let newServer = APIServer(
                name: normalizedName,
                baseURL: normalizedBaseURL,
                selectedModel: normalizedModel,
                availableModels: modelsToPersist,
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
            Task { await saveServer(confirmedHTTPAPIKey: true) }
        case .loadModels:
            Task { await fetchModels() }
        case .none:
            break
        }
    }

    private func fetchModels() async {
        isLoadingModels = true
        defer { isLoadingModels = false }

        if isOpenRouter {
            do {
                let models = try await loadOpenRouterModels(
                    baseURL: selectedType.normalizedBaseURL(baseURL),
                    apiKey: apiKey
                )
                openRouterModelLoadMessage = "Loaded \(models.count) OpenRouter models."
            } catch {
                openRouterModelLoadMessage = error.localizedDescription
            }
            return
        }

        let modelURL = selectedType.endpoint(baseURL: baseURL, path: "models")

        guard let url = URL(string: modelURL) else {
            print("Invalid URL: \(modelURL)")
            return
        }

        var request = URLRequest(url: url)

        if let bearerToken = APIAuthorization.bearerHeaderValue(apiKey: apiKey, for: url) {
            request.addValue(bearerToken, forHTTPHeaderField: "Authorization")
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
                APIModelCatalogCache.storeOpenAIModels(
                    availableModels,
                    for: selectedType,
                    baseURL: selectedType.normalizedBaseURL(baseURL)
                )

                if selectedModel.isEmpty || !availableModels.contains(selectedModel) {
                    selectedModel = availableModels.first ?? ""
                }
            }
        } catch {
            print("Failed to fetch models: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func loadOpenRouterModels(baseURL: String, apiKey: String) async throws -> [OpenRouterModel] {
        let models = try await OpenRouterModelCatalogService.fetchModels(
            baseURL: baseURL,
            apiKey: apiKey,
            tlsPolicy: TLSPolicy(
                allowInsecureTLS: allowInsecureTLS,
                customCACertificateData: customCACertificateData
            )
        )

        openRouterModels = models
        availableModels = models.map(\.id)
        loadedOpenRouterModelsBaseURL = APIType.openrouter.normalizedBaseURL(baseURL)
        APIModelCatalogCache.storeOpenRouterModels(models, for: baseURL)
        return models
    }

    @MainActor
    private func validateOpenRouterModelIfNeeded(
        baseURL: String,
        modelID: String,
        apiKey: String
    ) async -> Bool {
        guard isOpenRouter else { return true }
        guard OpenRouterModelCatalogService.requiresOfficialCatalogValidation(baseURL: baseURL) else {
            return true
        }

        let normalizedBaseURL = APIType.openrouter.normalizedBaseURL(baseURL)

        if openRouterModels.isEmpty || loadedOpenRouterModelsBaseURL != normalizedBaseURL {
            loadCachedModelsForCurrentConfiguration()
        }

        if openRouterModels.isEmpty || loadedOpenRouterModelsBaseURL != normalizedBaseURL {
            isLoadingModels = true
            defer { isLoadingModels = false }

            do {
                let models = try await loadOpenRouterModels(baseURL: normalizedBaseURL, apiKey: apiKey)
                openRouterModelLoadMessage = "Loaded \(models.count) OpenRouter models."
            } catch {
                openRouterModelAlertMessage = error.localizedDescription
                showOpenRouterModelAlert = true
                return false
            }
        }

        guard OpenRouterModelCatalogService.containsModel(id: modelID, in: openRouterModels) else {
            openRouterModelAlertMessage = "\"\(modelID)\" is not available in the official OpenRouter model catalog."
            showOpenRouterModelAlert = true
            return false
        }

        return true
    }

    private func resetLoadedModelsForBaseURLChange() {
        availableModels.removeAll()
        openRouterModels.removeAll()
        loadedOpenRouterModelsBaseURL = nil
        openRouterModelLoadMessage = ""
    }

    private func loadCachedModelsForCurrentConfiguration() {
        let normalizedBaseURL = selectedType.normalizedBaseURL(baseURL)
        guard !normalizedBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        if isOpenRouter {
            guard let cachedModels = APIModelCatalogCache.cachedOpenRouterModels(for: normalizedBaseURL) else {
                return
            }

            openRouterModels = cachedModels
            availableModels = cachedModels.map(\.id)
            loadedOpenRouterModelsBaseURL = APIType.openrouter.normalizedBaseURL(normalizedBaseURL)
            openRouterModelLoadMessage = "Loaded \(cachedModels.count) cached OpenRouter models."
            return
        }

        guard let cachedModels = APIModelCatalogCache.cachedOpenAIModels(
            for: selectedType,
            baseURL: normalizedBaseURL
        ) else {
            return
        }

        availableModels = cachedModels
        if selectedModel.isEmpty || !availableModels.contains(selectedModel) {
            selectedModel = availableModels.first ?? ""
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

private struct OpenAIModelList: Codable {
    struct Model: Codable {
        let id: String
    }
    let data: [Model]
}

struct ModelLoadButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                if isLoading {
                    Spacer()
                    ProgressView()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Add API Server") {
    CreateAPIServerView()
        .modelContainer(apiServerFormPreviewModelContainer)
}

#Preview("Edit OpenRouter Server") {
    CreateAPIServerViewEditPreviewHost()
        .modelContainer(apiServerFormPreviewModelContainer)
}

@MainActor
private let apiServerFormPreviewModelContainer: ModelContainer = {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: APIServer.self, configurations: config)
    let context = container.mainContext

    context.insert(
        APIServer(
            name: "OpenRouter Preview",
            baseURL: "https://openrouter.ai",
            selectedModel: "z-ai/glm-4.5-air:free",
            availableModels: [
                "z-ai/glm-4.5",
                "z-ai/glm-4.5-air:free",
                "openai/gpt-4o-mini"
            ],
            type: .openrouter,
            isOnline: true,
            apiKey: "sk-preview"
        )
    )
    try? context.save()

    return container
}()

private struct CreateAPIServerViewEditPreviewHost: View {
    @Query private var servers: [APIServer]

    var body: some View {
        if let server = servers.first {
            CreateAPIServerView(editingServer: server)
        } else {
            Text("No preview server")
        }
    }
}
