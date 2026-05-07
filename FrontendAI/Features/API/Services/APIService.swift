import Foundation

// MARK: - Stream chunk model
struct OpenAIStreamChunk: Codable {
    struct Choice: Codable {
        struct Delta: Codable {
            let role: String?
            let content: String?
        }
        let delta: Delta
        let index: Int
        let finish_reason: String?
    }
    let choices: [Choice]
}

// MARK: - Snapshot of APIServer (safe to send to async contexts)
struct ServerConfig: Sendable {
    let type: APIType
    let baseURL: String
    let selectedModel: String
    let apiKey: String?
    let allowInsecureTLS: Bool
    let customCACertificateData: Data?
}

extension ServerConfig {
    var tlsPolicy: TLSPolicy {
        TLSPolicy(
            allowInsecureTLS: allowInsecureTLS,
            customCACertificateData: customCACertificateData
        )
    }
}

// MARK: - API Service
actor APIService {

    static func sendMessage(
        messages: [ChatPayloadMessage],
        config: ServerConfig,
        onStream: ((String) -> Void)? = nil
    ) async throws -> String {
        switch config.type {
        case .openai:
            return try await sendToOpenAI(messages: messages, config: config, onStream: onStream)
        case .openrouter:
            return try await sendToOpenRouter(messages: messages, config: config, onStream: onStream)
        }
    }

    private static func sendToOpenAI(
        messages: [ChatPayloadMessage],
        config: ServerConfig,
        onStream: ((String) -> Void)? = nil
    ) async throws -> String {

        let openAIMessages = messages.compactMap { msg -> [String: String]? in
            guard !msg.role.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return ["role": msg.role, "content": msg.content]
        }

        let body: [String: Any] = [
            "model": config.selectedModel,
            "messages": openAIMessages,
            "stream": true
        ]

        let endpoint = APIType.openai.endpoint(baseURL: config.baseURL, path: "chat/completions")
        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "APIService", code: -1000,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid OpenAI URL: \(endpoint)"])
        }
        guard APIType.openai.isSecureTransportURL(url, baseURL: config.baseURL) else {
            throw NSError(domain: "APIService", code: -1001,
                          userInfo: [NSLocalizedDescriptionKey: "Official OpenAI endpoints must use HTTPS."])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("text/event-stream", forHTTPHeaderField: "Accept")

        if let bearerToken = APIAuthorization.bearerHeaderValue(apiKey: config.apiKey, for: url) {
            request.addValue(bearerToken, forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        try Task.checkCancellation()
        let session = TLSSessionFactory.makeSession(policy: config.tlsPolicy)
        let (stream, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw NSError(domain: "APIService", code: -1003,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid response code"])
        }

        var finalResultParts: [String] = []

        for try await line in stream.lines {
            try Task.checkCancellation()
            if line.starts(with: "data: ") {
                let jsonString = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                if jsonString == "[DONE]" { break }

                if let jsonData = jsonString.data(using: .utf8),
                   let chunk = try? JSONDecoder().decode(OpenAIStreamChunk.self, from: jsonData),
                   let delta = chunk.choices.first?.delta.content {
                    finalResultParts.append(delta)
                    onStream?(delta)
                }
            }
        }

        return finalResultParts.joined()
    }

    private static func sendToOpenRouter(
        messages: [ChatPayloadMessage],
        config: ServerConfig,
        onStream: ((String) -> Void)? = nil
    ) async throws -> String {

        let openRouterMessages = messages.compactMap { msg -> [String: String]? in
            guard !msg.role.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return ["role": msg.role, "content": msg.content]
        }

        let body: [String: Any] = [
            "model": config.selectedModel,
            "messages": openRouterMessages,
            "stream": true,
            "include_reasoning": true,
            "temperature": 0.9
        ]

        let endpoint = APIType.openrouter.endpoint(baseURL: config.baseURL, path: "chat/completions")
        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "APIService", code: -1000,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid OpenRouter URL: \(endpoint)"])
        }
        guard APIType.openrouter.isSecureTransportURL(url, baseURL: config.baseURL) else {
            throw NSError(domain: "APIService", code: -1001,
                          userInfo: [NSLocalizedDescriptionKey: "Official OpenRouter endpoints must use HTTPS."])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.applyOpenRouterAttributionHeaders()
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        if let bearerToken = APIAuthorization.bearerHeaderValue(apiKey: config.apiKey, for: url) {
            request.addValue(bearerToken, forHTTPHeaderField: "Authorization")
        }

        try Task.checkCancellation()
        let session = TLSSessionFactory.makeSession(policy: config.tlsPolicy)
        let (stream, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "APIService", code: -1002,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            #if DEBUG
            print("OpenRouter request failed with HTTP \(code)")
            #endif
            throw NSError(domain: "APIService", code: -1003,
                          userInfo: [NSLocalizedDescriptionKey: userFacingHTTPErrorMessage(statusCode: code)])
        }

        var finalResultParts: [String] = []
        var injectedThinkingOpened = false
        var injectedThinkingClosed = false

        for try await line in stream.lines {
            try Task.checkCancellation()
            if line.starts(with: "data: ") {
                let jsonString = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                if jsonString == "[DONE]" { break }

                if let jsonData = jsonString.data(using: .utf8) {
                    // OpenRouter can stream reasoning separately from content.
                    let parsed = parseOpenRouterStreamDelta(from: jsonData)

                    if !parsed.reasoning.isEmpty {
                        if !injectedThinkingOpened {
                            finalResultParts.append("<think>")
                            onStream?("<think>")
                            injectedThinkingOpened = true
                        }
                        for reasoningChunk in parsed.reasoning {
                            finalResultParts.append(reasoningChunk)
                            onStream?(reasoningChunk)
                        }
                    }

                    if !parsed.content.isEmpty {
                        if injectedThinkingOpened && !injectedThinkingClosed {
                            finalResultParts.append("</think>")
                            onStream?("</think>")
                            injectedThinkingClosed = true
                        }

                        for contentChunk in parsed.content {
                            finalResultParts.append(contentChunk)
                            onStream?(contentChunk)
                        }
                    }

                    if parsed.didFinish && injectedThinkingOpened && !injectedThinkingClosed {
                        finalResultParts.append("</think>")
                        onStream?("</think>")
                        injectedThinkingClosed = true
                    }
                }
            }
        }

        return finalResultParts.joined()
    }

    private static func userFacingHTTPErrorMessage(statusCode: Int) -> String {
        switch statusCode {
        case 401, 403:
            return "Authentication failed. Check your API key and permissions."
        case 404:
            return "API endpoint was not found. Verify the base URL."
        case 408, 504:
            return "The server timed out. Please try again."
        case 429:
            return "Rate limit reached. Please retry in a moment."
        case 500...599:
            return "Server unavailable right now. Please try again later."
        case 400...499:
            return "Request rejected by the API (HTTP \(statusCode))."
        default:
            return "Request failed (HTTP \(statusCode))."
        }
    }

    private static func parseOpenRouterStreamDelta(from data: Data) -> (content: [String], reasoning: [String], didFinish: Bool) {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = root["choices"] as? [[String: Any]]
        else {
            if let chunk = try? JSONDecoder().decode(OpenAIStreamChunk.self, from: data),
               let content = chunk.choices.first?.delta.content, !content.isEmpty {
                return ([content], [], false)
            }
            return ([], [], false)
        }

        var contentParts: [String] = []
        var reasoningParts: [String] = []
        var didFinish = false

        for choice in choices {
            if choice["finish_reason"] is String {
                didFinish = true
            }

            guard let delta = choice["delta"] as? [String: Any] else { continue }

            if let content = delta["content"] {
                contentParts.append(contentsOf: stringParts(from: content))
            }

            // Some providers expose both keys simultaneously with overlapping text.
            // Prefer the direct `reasoning` payload and only fallback to details.
            if let reasoning = delta["reasoning"] {
                reasoningParts.append(contentsOf: stringParts(from: reasoning))
            } else if let reasoningDetails = delta["reasoning_details"] {
                reasoningParts.append(contentsOf: stringParts(from: reasoningDetails))
            }
        }

        return (deduplicatedAdjacent(parts: contentParts), deduplicatedAdjacent(parts: reasoningParts), didFinish)
    }

    private static func stringParts(from value: Any) -> [String] {
        if let string = value as? String {
            return string.isEmpty ? [] : [string]
        }

        if let array = value as? [Any] {
            return array.flatMap { stringParts(from: $0) }
        }

        if let dict = value as? [String: Any] {
            // Preserve one canonical textual field to avoid duplicate echoes.
            if let text = dict["text"] as? String, !text.isEmpty {
                return [text]
            }
            if let content = dict["content"] {
                return stringParts(from: content)
            }
            if let reasoning = dict["reasoning"] {
                return stringParts(from: reasoning)
            }
            if let token = dict["token"] as? String, !token.isEmpty {
                return [token]
            }
        }

        return []
    }

    private static func deduplicatedAdjacent(parts: [String]) -> [String] {
        guard !parts.isEmpty else { return [] }

        var result: [String] = []
        result.reserveCapacity(parts.count)

        for part in parts where !part.isEmpty {
            if result.last == part { continue }
            result.append(part)
        }

        return result
    }
}

// MARK: - Response Models
struct OpenAIResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let role: String
            let content: String
        }
        let index: Int
        let message: Message
        let finish_reason: String
    }

    struct Usage: Codable {
        let prompt_tokens: Int
        let completion_tokens: Int
        let total_tokens: Int
    }

    let id: String
    let object: String
    let created: Int
    let choices: [Choice]
    let usage: Usage
}
