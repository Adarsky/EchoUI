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
        let status = await Self.evaluateConnectionStatus(for: server)
        server.updateConnectionStatus(status)
        try? modelContext.save()
    }

    static func evaluateConnectionStatus(for server: APIServer) async -> APIConnectionStatus {
        _ = server.migrateAPIKeyToKeychainIfNeeded()
        let endpoint = server.type.endpoint(baseURL: server.baseURL, path: "models")
        
        guard let url = URL(string: endpoint) else { return .offline }
        
        var request = URLRequest(url: url)

        if server.type == .openrouter {
            request.applyOpenRouterAttributionHeaders()
        }
        
        if let bearerToken = APIAuthorization.bearerHeaderValue(apiKey: server.apiKey, for: url) {
            request.addValue(bearerToken, forHTTPHeaderField: "Authorization")
        }
        
        do {
            let session = TLSSessionFactory.makeSession(policy: server.tlsPolicy)
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .offline
            }
            return APIConnectionStatusMapper.status(forHTTPStatusCode: httpResponse.statusCode)
        } catch {
            return .offline
        }
    }
}
