import Foundation

struct OpenRouterBalanceSnapshot: Sendable {
    let totalUsage: Double?
    let totalCredits: Double?
    let balance: Double?
}

enum OpenRouterBalanceServiceError: LocalizedError {
    case missingAPIKey
    case invalidURL(String)
    case insecureTransportRequired
    case insecureAPIKeyTransport
    case invalidResponse
    case invalidPayload
    case server(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Missing OpenRouter API key."
        case .invalidURL:
            return "Invalid OpenRouter URL."
        case .insecureTransportRequired:
            return "Official OpenRouter endpoints must use HTTPS."
        case .insecureAPIKeyTransport:
            return "OpenRouter balance requires HTTPS because it uses an API key."
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
    static func fetchBalance(
        baseURL: String,
        apiKey: String,
        tlsPolicy: TLSPolicy = .strict
    ) async throws -> OpenRouterBalanceSnapshot {
        let normalizedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKey.isEmpty else {
            throw OpenRouterBalanceServiceError.missingAPIKey
        }

        let endpoint = APIType.openrouter.endpoint(baseURL: baseURL, path: "credits")
        guard let url = URL(string: endpoint) else {
            throw OpenRouterBalanceServiceError.invalidURL(endpoint)
        }
        guard APIType.openrouter.isSecureTransportURL(url, baseURL: baseURL) else {
            throw OpenRouterBalanceServiceError.insecureTransportRequired
        }
        guard let bearerToken = APIAuthorization.bearerHeaderValue(apiKey: normalizedKey, for: url) else {
            throw OpenRouterBalanceServiceError.insecureAPIKeyTransport
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(bearerToken, forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.applyOpenRouterAttributionHeaders()

        let session = TLSSessionFactory.makeSession(policy: tlsPolicy)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterBalanceServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw OpenRouterBalanceServiceError.server(
                statusCode: httpResponse.statusCode,
                message: userFacingServerMessage(statusCode: httpResponse.statusCode, data: data)
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

    private static func userFacingServerMessage(statusCode: Int, data: Data) -> String? {
        switch statusCode {
        case 401, 403:
            return "Authentication failed. Check your OpenRouter API key."
        case 404:
            return "OpenRouter endpoint was not found."
        case 408, 504:
            return "OpenRouter timed out. Please try again."
        case 429:
            return "OpenRouter rate limit reached. Please retry shortly."
        case 500...599:
            return "OpenRouter is currently unavailable."
        default:
            break
        }

        if let parsed = parseStructuredErrorMessage(from: data) {
            return parsed
        }

        if (400..<500).contains(statusCode) {
            return "OpenRouter rejected the request."
        }

        return nil
    }

    private static func parseStructuredErrorMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }

        if
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let error = root["error"] as? [String: Any]
        {
            if let message = error["message"] as? String {
                return sanitizedMessageForDisplay(message)
            }
        }

        if
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let message = root["message"] as? String
        {
            return sanitizedMessageForDisplay(message)
        }

        return nil
    }

    private static func sanitizedMessageForDisplay(_ raw: String) -> String? {
        let normalized = raw
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return nil }

        let lowercased = normalized.lowercased()
        let blockedTokens = [
            "<script",
            "file://",
            "/users/",
            "/var/",
            "begin private key",
            "secret=",
            "token=",
            "authorization:"
        ]
        if blockedTokens.contains(where: { lowercased.contains($0) }) {
            return nil
        }

        let maxCount = 140
        if normalized.count > maxCount {
            return String(normalized.prefix(maxCount)) + "…"
        }
        return normalized
    }
}
