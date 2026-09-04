import Foundation

enum APIServerOrganization {
    static func pinnedServers(from servers: [APIServer]) -> [APIServer] {
        manuallyOrdered(servers.filter(\.isPinned))
    }

    static func groups(from servers: [APIServer]) -> [APIServerGroup] {
        let unpinnedServers = servers.filter { !$0.isPinned }
        let groupedServers = Dictionary(grouping: unpinnedServers, by: groupID)

        return groupedServers.compactMap { id, groupServers in
            guard let representative = groupServers.first else { return nil }
            return APIServerGroup(
                id: id,
                title: groupTitle(for: representative),
                isOfficial: representative.type.requiresHTTPSForOfficialEndpoint(baseURL: representative.baseURL),
                servers: manuallyOrdered(groupServers)
            )
        }
        .sorted { lhs, rhs in
            if lhs.isOfficial != rhs.isOfficial {
                return lhs.isOfficial
            }
            let titleComparison = lhs.title.localizedStandardCompare(rhs.title)
            if titleComparison != .orderedSame {
                return titleComparison == .orderedAscending
            }
            return lhs.id < rhs.id
        }
    }

    static func peers(of server: APIServer, in servers: [APIServer]) -> [APIServer] {
        let matchingServers = servers.filter { candidate in
            candidate.isPinned == server.isPinned
                && (server.isPinned || groupID(for: candidate) == groupID(for: server))
        }
        return manuallyOrdered(matchingServers)
    }

    static func applyManualOrder(_ orderedServers: [APIServer]) {
        for (index, server) in orderedServers.enumerated() {
            server.sortOrder = index
        }
    }

    static func sorted(_ servers: [APIServer], by option: APIServerSortOption) -> [APIServer] {
        servers.sorted { lhs, rhs in
            let primaryComparison: ComparisonResult
            switch option {
            case .name:
                primaryComparison = lhs.name.localizedStandardCompare(rhs.name)
            case .model:
                primaryComparison = lhs.selectedModel.localizedStandardCompare(rhs.selectedModel)
            }

            if primaryComparison != .orderedSame {
                return primaryComparison == .orderedAscending
            }
            return stableComparison(lhs, rhs)
        }
    }

    static func suggestedCloneName(for server: APIServer, among servers: [APIServer]) -> String {
        let baseName = server.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingNames = Set(servers.map { $0.name.lowercased() })
        let firstCandidate = cloneName(baseName: baseName, suffix: " Copy")

        guard existingNames.contains(firstCandidate.lowercased()) else {
            return firstCandidate
        }

        var copyNumber = 2
        var candidate = cloneName(baseName: baseName, suffix: " Copy \(copyNumber)")
        while existingNames.contains(candidate.lowercased()) {
            copyNumber += 1
            candidate = cloneName(baseName: baseName, suffix: " Copy \(copyNumber)")
        }
        return candidate
    }

    static func groupID(for server: APIServer) -> String {
        let normalizedBaseURL = server.type.normalizedBaseURL(server.baseURL)
        guard var components = URLComponents(string: normalizedBaseURL),
              components.host != nil else {
            return "\(server.type.rawValue)|\(normalizedBaseURL)"
        }

        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        return "\(server.type.rawValue)|\(components.string ?? normalizedBaseURL)"
    }

    static func groupTitle(for server: APIServer) -> String {
        if server.type.requiresHTTPSForOfficialEndpoint(baseURL: server.baseURL) {
            return "Official \(server.type.displayName)"
        }

        let normalizedBaseURL = server.type.normalizedBaseURL(server.baseURL)
        if let components = URLComponents(string: normalizedBaseURL),
           let host = components.host,
           !host.isEmpty {
            let scheme = components.scheme.map { "\($0.lowercased())://" } ?? ""
            let port = components.port.map { ":\($0)" } ?? ""
            let path = components.path == "/" ? "" : components.path
            return "\(server.type.displayName) · \(scheme)\(host)\(port)\(path)"
        }
        return "Custom \(server.type.displayName)"
    }

    private static func manuallyOrdered(_ servers: [APIServer]) -> [APIServer] {
        servers.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return stableComparison(lhs, rhs)
        }
    }

    private static func stableComparison(_ lhs: APIServer, _ rhs: APIServer) -> Bool {
        let nameComparison = lhs.name.localizedStandardCompare(rhs.name)
        if nameComparison != .orderedSame {
            return nameComparison == .orderedAscending
        }
        return lhs.uuid.uuidString < rhs.uuid.uuidString
    }

    private static func cloneName(baseName: String, suffix: String) -> String {
        let availableCharacterCount = max(APIServer.maximumNameLength - suffix.count, 0)
        let shortenedBaseName = String(baseName.prefix(availableCharacterCount))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(shortenedBaseName)\(suffix)"
    }
}
