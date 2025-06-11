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
        guard let url = URL(string: server.type == .openai
                            ? "\(server.baseURL)/v1/models"
                            : "\(server.baseURL)/api/v1/model") else { return }
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
