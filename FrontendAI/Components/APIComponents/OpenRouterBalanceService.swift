//
//  OpenRouterBalanceService.swift
//  FrontendAI
//
//  Created by Codex on 12.03.2026.
//

import Foundation

struct OpenRouterBalanceSnapshot: Sendable {
    let totalUsage: Double?
    let totalCredits: Double?
    let balance: Double?
}

enum OpenRouterBalanceServiceError: LocalizedError {
    case missingAPIKey
    case invalidURL(String)
    case invalidResponse
    case invalidPayload
    case server(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Missing OpenRouter API key."
        case .invalidURL:
            return "Invalid OpenRouter URL."
        case .invalidResponse:
            return "Invalid response from OpenRouter."
        case .invalidPayload:
            return "OpenRouter returned an unexpected payload."
        case let .server(statusCode, message):
            if let message, !message.isEmpty {
                return "OpenRouter error \(statusCode): \(message)"
            }
            return "OpenRouter error \(statusCode)."
        }
    }
}

enum OpenRouterBalanceService {
    static func fetchBalance(baseURL: String, apiKey: String) async throws -> OpenRouterBalanceSnapshot {
        let normalizedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKey.isEmpty else {
            throw OpenRouterBalanceServiceError.missingAPIKey
        }

        let endpoint = APIType.openrouter.endpoint(baseURL: baseURL, path: "credits")
        guard let url = URL(string: endpoint) else {
            throw OpenRouterBalanceServiceError.invalidURL(endpoint)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(normalizedKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("https://echo-ui.app", forHTTPHeaderField: "HTTP-Referer")
        request.addValue("Echo UI", forHTTPHeaderField: "X-Title")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterBalanceServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw OpenRouterBalanceServiceError.server(
                statusCode: httpResponse.statusCode,
                message: parseErrorMessage(from: data)
            )
        }

        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let payload = root["data"] as? [String: Any]
        else {
            throw OpenRouterBalanceServiceError.invalidPayload
        }

        let totalCredits = parseNumber(payload["total_credits"])
        let totalUsage = parseNumber(payload["total_usage"])
        let computedBalance: Double?
        if let totalCredits, let totalUsage {
            computedBalance = roundTo3(totalCredits - totalUsage)
        } else {
            computedBalance = nil
        }

        return OpenRouterBalanceSnapshot(
            totalUsage: totalUsage.map(roundTo3),
            totalCredits: totalCredits.map(roundTo3),
            balance: computedBalance
        )
    }

    private static func roundTo3(_ value: Double) -> Double {
        (value * 1000).rounded() / 1000
    }

    private static func parseNumber(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let string = value as? String {
            return Double(string)
        }
        return nil
    }

    private static func parseErrorMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }

        if
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let error = root["error"] as? [String: Any]
        {
            if let message = error["message"] as? String, !message.isEmpty {
                return message
            }
        }

        if
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let message = root["message"] as? String,
            !message.isEmpty
        {
            return message
        }

        if let plain = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !plain.isEmpty {
            return plain
        }

        return nil
    }
}
