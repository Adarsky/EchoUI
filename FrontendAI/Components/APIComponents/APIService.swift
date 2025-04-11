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

        // Собираем системный промпт, если есть
        let systemPrompt = messages.first(where: { $0.role == "system" })?.content ?? ""
        let systemBlock = systemPrompt.isEmpty ? "" : "### System:\n\(systemPrompt)\n\n"

        // Формируем историю диалога
        let fullPrompt = systemBlock + messages
            .filter { $0.role != "system" }
            .map {
                switch $0.role {
                case "user": return "### User:\n\($0.content)"
                case "assistant": return "### Assistant:\n\($0.content)"
                default: return "### \($0.role.capitalized):\n\($0.content)"
                }
            }.joined(separator: "\n") + "\n### Assistant:\n"

        // Тело запроса
        let body: [String: Any] = [
            "prompt": fullPrompt,
            "max_length": 200,
            "temperature": server.temperature,
            "rep_pen": 1.1,
            "rep_pen_range": 256,
            "rep_pen_slope": 1,
            "top_k": 100,
            "top_p": 0.9,
            "typical": 1,
            "tfs": 1,
            "top_a": 0,
            "quiet": false
            // Можно добавить "stop_sequence": ["### User:", "### System:", "### Assistant:"]
            // если сервер поддерживает это (проверь)
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Лог запроса
        if let bodyData = try? JSONSerialization.data(withJSONObject: body, options: .prettyPrinted),
           let bodyString = String(data: bodyData, encoding: .utf8) {
            print("📤 Full Kobold Request Body:")
            print(bodyString)
        }

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
