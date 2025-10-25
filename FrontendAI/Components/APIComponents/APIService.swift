//
//  APIService.swift
//  FrontendAI
//
//  Created by macbook on 28.03.2025.
//

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
}

// MARK: - API Service
actor APIService {

    static func sendMessage(
        messages: [ChatPayloadMessage],
        server: APIServer,
        onStream: ((String) -> Void)? = nil
    ) async throws -> String {
        // snapshot values safely on main actor
        let cfg = await MainActor.run {
            ServerConfig(
                type: server.type,
                baseURL: server.baseURL,
                selectedModel: server.selectedModel,
                apiKey: server.apiKey
            )
        }

        switch cfg.type {
        case .openai:
            return try await sendToOpenAI(messages: messages, config: cfg, onStream: onStream)
        case .openrouter:
            return try await sendToOpenRouter(messages: messages, config: cfg, onStream: onStream)
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

        var request = URLRequest(url: URL(string: "\(config.baseURL)/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("text/event-stream", forHTTPHeaderField: "Accept")

        if let apiKey = config.apiKey, !apiKey.isEmpty {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (stream, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw NSError(domain: "APIService", code: -1003,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid response code"])
        }

        var finalResult = ""

        for try await line in stream.lines {
            if line.starts(with: "data: ") {
                let jsonString = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                if jsonString == "[DONE]" { break }

                if let jsonData = jsonString.data(using: .utf8),
                   let chunk = try? JSONDecoder().decode(OpenAIStreamChunk.self, from: jsonData),
                   let delta = chunk.choices.first?.delta.content {
                    finalResult += delta
                    onStream?(delta)
                }
            }
        }

        return finalResult
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
            "temperature": 0.9
        ]

        var request = URLRequest(url: URL(string: "\(config.baseURL)/api/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.addValue("Echo UI app", forHTTPHeaderField: "HTTP-Referer")
        request.addValue("Echo UI app", forHTTPHeaderField: "X-Title")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        if let apiKey = config.apiKey, !apiKey.isEmpty {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        // Optional: log request body
        if let bodyData = try? JSONSerialization.data(withJSONObject: body, options: .prettyPrinted),
           let bodyString = String(data: bodyData, encoding: .utf8) {
            print("📤 Full OpenRouter Request Body:\n\(bodyString)")
        }

        let (stream, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "APIService", code: -1003,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid response code (\(code))"])
        }

        var finalResult = ""

        for try await line in stream.lines {
            if line.starts(with: "data: ") {
                let jsonString = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                if jsonString == "[DONE]" { break }

                if let jsonData = jsonString.data(using: .utf8),
                   let chunk = try? JSONDecoder().decode(OpenAIStreamChunk.self, from: jsonData),
                   let delta = chunk.choices.first?.delta.content {
                    finalResult += delta
                    onStream?(delta)
                }
            }
        }

        return finalResult
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
