import SwiftUI
import SwiftData

enum APIType: String, Codable, CaseIterable {
    case openai
    case kobold
}

@Model
class APIServer {
    @Attribute(.unique) var uuid: UUID = UUID()
    var name: String
    var baseURL: String
    var selectedModel: String
    var isOnline: Bool = false
    var type: APIType

    init(name: String, baseURL: String, selectedModel: String, type: APIType) {
        self.name = name
        self.baseURL = baseURL
        self.selectedModel = selectedModel
        self.type = type
    }
}

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
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(server.name).bold()
                            Spacer()
                            Circle()
                                .fill(server.isOnline ? Color.green : Color.red)
                                .frame(width: 10, height: 10)
                            Text(server.isOnline ? "Online" : "Offline")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Text("Model: \(server.selectedModel)")
                            .font(.subheadline)

                        Text("Type: \(server.type.rawValue.capitalized)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            Button("Set Active") {
                                apiManager.selectedServer = server
                            }

                            Button("Restart") {
                                Task { await ping(server: server) }
                            }

                            Button("Edit") {
                                editServer = server
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
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

    func ping(server: APIServer) async {
        guard let url = URL(string: server.type == .openai ? "\(server.baseURL)/v1/models" : "\(server.baseURL)/api/v1/model") else { return }
        let updated = server
        do {
            _ = try await URLSession.shared.data(from: url)
            updated.isOnline = true
        } catch {
            updated.isOnline = false
        }
        try? modelContext.save()
    }
}

struct CreateAPIServerView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext

    @State private var name: String = ""
    @State private var baseURL: String = ""
    @State private var selectedModel: String = ""
    @State private var availableModels: [String] = []
    @State private var selectedType: APIType = .openai
    @Environment(PersonaManager.self) var personaManager

    var editingServer: APIServer? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Details")) {
                    TextField("Name", text: $name)
                    TextField("Base URL", text: $baseURL)
                        .onSubmit {
                            Task {
                                await fetchModels()
                            }
                        }

                    Picker("Type", selection: $selectedType) {
                        ForEach(APIType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized)
                        }
                    }

                    if availableModels.isEmpty {
                        Button("Load Models") {
                            Task {
                                await fetchModels()
                            }
                        }
                    } else {
                        Picker("Select Model", selection: $selectedModel) {
                            ForEach(availableModels, id: \.self) { model in
                                Text(model)
                            }
                        }
                    }
                }
            }
            .navigationTitle(editingServer == nil ? "Add API Server" : "Edit API Server")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let server = editingServer {
                            server.name = name
                            server.baseURL = baseURL
                            server.selectedModel = selectedModel
                            server.type = selectedType
                        } else {
                            let newServer = APIServer(
                                name: name,
                                baseURL: baseURL,
                                selectedModel: selectedModel,
                                type: selectedType
                            )
                            modelContext.insert(newServer)
                        }
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(name.isEmpty || baseURL.isEmpty || selectedModel.isEmpty)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let server = editingServer {
                    name = server.name
                    baseURL = server.baseURL
                    selectedModel = server.selectedModel
                    selectedType = server.type
                }
            }
        }
    }

    func fetchModels() async {
        let modelURL: String
        switch selectedType {
        case .openai:
            modelURL = "\(baseURL)/v1/models"
        case .kobold:
            modelURL = "\(baseURL)/api/v1/model"
        }

        guard let url = URL(string: modelURL) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if selectedType == .openai,
               let result = try? JSONDecoder().decode(OpenAIModelList.self, from: data) {
                availableModels = result.data.map { $0.id }
                if selectedModel.isEmpty {
                    selectedModel = availableModels.first ?? ""
                }
            } else if selectedType == .kobold,
                      let string = String(data: data, encoding: .utf8) {
                availableModels = [string]
                if selectedModel.isEmpty {
                    selectedModel = string
                }
            }
        } catch {
            print("Failed to fetch models: \(error.localizedDescription)")
        }
    }
}

struct OpenAIModelList: Codable {
    struct Model: Codable {
        let id: String
    }
    let data: [Model]
}

#Preview {
    APIManagerView(
        selectedServer: .constant(nil)
    )
    .modelContainer(for: APIServer.self, inMemory: true)
}
