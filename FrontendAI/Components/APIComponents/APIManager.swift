//
//  APIManager.swift
//  FrontendAI
//
//  Created by macbook on 28.03.2025.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
class APIManager: ObservableObject {
    @Published var selectedServer: APIServer? {
        didSet {
            selectedServerUUID = selectedServer?.uuid.uuidString ?? ""
        }
    }

    @AppStorage("selectedServerUUID") private var selectedServerUUID: String = ""

    init() {}

    func restoreLastSelectedServer(from servers: [APIServer]) {
        guard let uuid = UUID(uuidString: selectedServerUUID) else { return }
        if let server = servers.first(where: { $0.uuid == uuid }) {
            selectedServer = server
        }
    }

    func ping(server: APIServer, modelContext: ModelContext) async {
        let endpoint: String
        switch server.type {
        case .openai:
            endpoint = "\(server.baseURL)/v1/models"
        case .openrouter:
            endpoint = "\(server.baseURL)/api/v1/models"
        }
        
        guard let url = URL(string: endpoint) else { return }
        
        var request = URLRequest(url: url)
        
        // Добавляем API ключ если есть
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
