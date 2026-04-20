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
        _ = server.migrateAPIKeyToKeychainIfNeeded()
        let endpoint = server.type.endpoint(baseURL: server.baseURL, path: "models")
        
        guard let url = URL(string: endpoint) else { return }
        
        var request = URLRequest(url: url)
        
        if let apiKey = server.apiKey, !apiKey.isEmpty {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let session = TLSSessionFactory.makeSession(policy: server.tlsPolicy)
            _ = try await session.data(for: request)
            server.isOnline = true
        } catch {
            server.isOnline = false
        }
        try? modelContext.save()
    }
}
