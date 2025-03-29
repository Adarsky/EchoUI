//
//  MessagePayload.swift
//  FrontendAI
//
//  Created by macbook on 28.03.2025.
//


import Foundation

class APIService {
    
    static func sendMessage(
        messages: [ChatPayloadMessage],
        server: APIServer
    ) async throws -> String {
        switch server.type {
        case .openai:
            return try await sendToOpenAI(messages: messages, server: server)
        case .kobold:
            return try await sendToKobold(messages: messages, server: server)
        }
    }

    private static func sendToOpenAI(
        messages: [ChatPayloadMessage],
        server: APIServer
    ) async throws -> String {
        let openAIMessages = messages.compactMap { msg -> [String: String]? in
            guard !msg.role.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return ["role": msg.role, "content": msg.content]
        }


        let body: [String: Any] = [
            "model": server.selectedModel,
            "messages": openAIMessages,
            "temperature": server.temperature
        ]

        var request = URLRequest(url: URL(string: "\(server.baseURL)/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        if let bodyData = try? JSONSerialization.data(withJSONObject: body, options: .prettyPrinted),
           let bodyString = String(data: bodyData, encoding: .utf8) {
            print("📤 Full JSON Request Body:")
            print(bodyString)
        }


        let session = URLSession(
            configuration: .default,
            delegate: InsecureURLSessionDelegate(),
            delegateQueue: nil
        )
        let (data, _) = try await session.data(for: request)
        let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return result.choices.first?.message.content ?? "No response"
    }

    private static func sendToKobold(
        messages: [ChatPayloadMessage],
        server: APIServer
    ) async throws -> String {
        let url = URL(string: "\(server.baseURL)/api/v1/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let fullPrompt = messages.map {
            switch $0.role {
            case "system":
                return "[System]\n\($0.content)"
            case "user":
                return "User: \($0.content)"
            case "assistant":
                return "Bot: \($0.content)"
            default:
                return "\($0.role.capitalized): \($0.content)"
            }
        }.joined(separator: "\n")

        let body: [String: Any] = [
            "prompt": fullPrompt,
            "max_context_length": 2048,
            "max_length": 200,
            "temperature": server.temperature
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let result = try JSONDecoder().decode(KoboldResponse.self, from: data)
        return result.results.first?.text ?? "No response"
    }
}

// MARK: - Response Models

struct OpenAIResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

struct KoboldResponse: Codable {
    struct Result: Codable {
        let text: String
    }
    let results: [Result]
}
