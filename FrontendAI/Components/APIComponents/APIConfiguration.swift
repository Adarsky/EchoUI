//
//  APIConfiguration.swift
//  FrontendAI
//
//  Created by macbook on 28.03.2025.
//

import Foundation
import SwiftData

enum APIType: String, Codable, CaseIterable {
    case openai
    case openrouter
}

extension APIType {
    func normalizedBaseURL(_ rawValue: String) -> String {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        while value.hasSuffix("/") {
            value.removeLast()
        }

        guard self == .openrouter else { return value }

        let lowercased = value.lowercased()
        if lowercased.hasSuffix("/api/v1") {
            value = String(value.dropLast("/api/v1".count))
        } else if lowercased.hasSuffix("/v1") {
            value = String(value.dropLast("/v1".count))
        }

        while value.hasSuffix("/") {
            value.removeLast()
        }

        return value
    }

    func endpoint(baseURL: String, path: String) -> String {
        let root = normalizedBaseURL(baseURL)
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path

        switch self {
        case .openai:
            return "\(root)/v1/\(normalizedPath)"
        case .openrouter:
            return "\(root)/api/v1/\(normalizedPath)"
        }
    }
}

@Model
final class APIServer {
    @Attribute(.unique) var uuid: UUID
    var name: String
    var baseURL: String
    var selectedModel: String
    var availableModels: [String]
    var type: APIType
    var isOnline: Bool
    var apiKey: String?
    
    init(
        uuid: UUID = UUID(),
        name: String,
        baseURL: String,
        selectedModel: String,
        availableModels: [String] = [],
        type: APIType,
        isOnline: Bool = false,
        apiKey: String? = nil
    ) {
        self.uuid = uuid
        self.name = name
        self.baseURL = baseURL
        self.selectedModel = selectedModel
        self.availableModels = availableModels
        self.type = type
        self.isOnline = isOnline
        self.apiKey = apiKey
    }
}
