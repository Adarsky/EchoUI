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
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(servers) { server in
                    ServerRowView(
                        server: server,
                        apiManager: apiManager,
                        onEdit: { editServer = server },
                        onPing: { await ping(server: server) }
                    )
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
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
                for server in servers {
                    await ping(server: server)
                }
            }
        }
    }
    
    // MARK: - Ping Server
    
    func ping(server: APIServer) async {
        let endpoint: String
        switch server.type {
        case .openai:
            endpoint = "\(server.baseURL)/v1/models"
        case .openrouter:
            endpoint = "\(server.baseURL)/api/v1/models"
        }
        
        guard let url = URL(string: endpoint) else { return }
        var request = URLRequest(url: url)
        
        if let apiKey = server.apiKey, !apiKey.isEmpty {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            _ = try await URLSession.shared.data(for: request)
            server.isOnline = true
        } catch {
            server.isOnline = false
        }
        try? modelContext.save()
    }
}

// MARK: - Server Row View

struct ServerRowView: View {
    let server: APIServer
    let apiManager: APIManager
    let onEdit: () -> Void
    let onPing: () async -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header with status
            HStack {
                Text(server.name)
                    .bold()
                Spacer()
                Circle()
                    .fill(server.isOnline ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(server.isOnline ? "Online" : "Offline")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Model info
            Text("Model: \(server.selectedModel)")
                .font(.subheadline)
            
            // Type info
            Text("Type: \(server.type.rawValue.capitalized)")
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
                Button("Set Active") {
                    apiManager.selectedServer = server
                }
                
                Button("Restart") {
                    Task { await onPing() }
                }
                
                Button("Edit") {
                    onEdit()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Create/Edit API Server View

struct CreateAPIServerView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    @State private var name: String = ""
    @State private var baseURL: String = ""
    @State private var selectedModel: String = ""
    @State private var availableModels: [String] = []
    @State private var selectedType: APIType = .openai
    @State private var apiKey: String = ""
    @State private var isLoadingModels: Bool = false
    
    var editingServer: APIServer? = nil
    
    private var isOpenRouter: Bool { selectedType == .openrouter }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Server Details")) {
                    TextField("Name", text: $name)
                        .autocorrectionDisabled()
                    
                    TextField("Base URL", text: $baseURL)
                        .autocapitalization(.none)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .onSubmit {
                            if !isOpenRouter {
                                Task { await fetchModels() }
                            }
                        }
                    
                    Picker("Type", selection: $selectedType) {
                        ForEach(APIType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    
                    SecureField("API Key (optional)", text: $apiKey)
                        .autocapitalization(.none)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                Section(header: Text("Model Selection")) {
                    if isOpenRouter {
                        TextField("Model name (e.g. openrouter/xxx)", text: $selectedModel)
                            .autocapitalization(.none)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        
                        Text("Enter the exact model ID as specified by OpenRouter. The list of models is not loaded for OpenRouter.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        if availableModels.isEmpty {
                            Button {
                                Task { await fetchModels() }
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
                                Task { await fetchModels() }
                            }
                            .disabled(isLoadingModels)
                        }
                    }
                }
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
        }
    }
    
    // MARK: - Computed Properties
    
    private var canSave: Bool {
        !name.isEmpty && !baseURL.isEmpty && !selectedModel.isEmpty
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
    }
    
    private func saveServer() {
        if let server = editingServer {
            // Update existing server
            server.name = name
            server.baseURL = baseURL
            server.selectedModel = selectedModel
            server.availableModels = isOpenRouter ? [] : availableModels
            server.type = selectedType
            server.apiKey = apiKey.isEmpty ? nil : apiKey
        } else {
            // Create new server
            let newServer = APIServer(
                name: name,
                baseURL: baseURL,
                selectedModel: selectedModel,
                availableModels: isOpenRouter ? [] : availableModels,
                type: selectedType,
                apiKey: apiKey.isEmpty ? nil : apiKey
            )
            modelContext.insert(newServer)
        }
        
        try? modelContext.save()
        dismiss()
    }
    
    private func fetchModels() async {
        guard !isOpenRouter else { return }
        
        isLoadingModels = true
        defer { isLoadingModels = false }
        
        let modelURL: String
        switch selectedType {
        case .openai:
            modelURL = "\(baseURL)/v1/models"
        case .openrouter:
            modelURL = "\(baseURL)/api/v1/models"
        }
        
        guard let url = URL(string: modelURL) else {
            print("Invalid URL: \(modelURL)")
            return
        }
        
        var request = URLRequest(url: url)
        
        if !apiKey.isEmpty {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
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
    APIManagerView(
        selectedServer: .constant(nil)
    )
    .modelContainer(for: APIServer.self, inMemory: true)
    .environmentObject(APIManager())
}
