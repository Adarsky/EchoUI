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

        var request = URLRequest(url: url)
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

        let endpoint = APIType.openrouter.endpoint(baseURL: config.baseURL, path: "chat/completions")
        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "APIService", code: -1000,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid OpenRouter URL: \(endpoint)"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.addValue("https://echo-ui.app", forHTTPHeaderField: "HTTP-Referer")
        request.addValue("Echo UI", forHTTPHeaderField: "X-Title")
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

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "APIService", code: -1002,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let errorBody = try await readErrorBody(from: stream)
            let details = errorBody.isEmpty ? "" : " - \(errorBody)"
            throw NSError(domain: "APIService", code: -1003,
                          userInfo: [NSLocalizedDescriptionKey: "OpenRouter request failed (\(code))\(details)"])
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

    private static func readErrorBody(from stream: URLSession.AsyncBytes) async throws -> String {
        var lines: [String] = []
        var charCount = 0

        for try await rawLine in stream.lines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed == "data: [DONE]" { break }

            let line: String
            if trimmed.hasPrefix("data: ") {
                line = String(trimmed.dropFirst("data: ".count))
            } else {
                line = trimmed
            }

            lines.append(line)
            charCount += line.count
            if lines.count >= 20 || charCount >= 1200 {
                break
            }
        }

        return lines.joined(separator: "\n")
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
