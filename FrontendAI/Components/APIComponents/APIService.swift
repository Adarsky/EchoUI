//
//  MessagePayload.swift
//  FrontendAI
//
//  Created by macbook on 28.03.2025.
//


import Foundation


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

class APIService {
    
    static func sendMessage(
        messages: [ChatPayloadMessage],
        server: APIServer,
        onStream: ((String) -> Void)? = nil
    ) async throws -> String {
        switch server.type {
        case .openai:
            return try await sendToOpenAI(messages: messages, server: server, onStream: onStream)
        case .kobold:
            return try await sendToKobold(messages: messages, server: server)
        }
    }

    private static func sendToOpenAI(
        messages: [ChatPayloadMessage],
        server: APIServer,
        onStream: ((String) -> Void)? = nil
    ) async throws -> String {
        let openAIMessages = messages.compactMap { msg -> [String: String]? in
            guard !msg.role.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return ["role": msg.role, "content": msg.content]
        }

        let body: [String: Any] = [
            "model": server.selectedModel,
            "messages": openAIMessages,
            "temperature": UserDefaults.standard.double(forKey: "temperature"),
            "top_p": UserDefaults.standard.double(forKey: "top_p"),
            "max_tokens": UserDefaults.standard.integer(forKey: "max_generated_tokens"),
            "stream": true
        ]

        var request = URLRequest(url: URL(string: "\(server.baseURL)/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (stream, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw NSError(domain: "APIService", code: -1003, userInfo: [NSLocalizedDescriptionKey: "Invalid response code"])
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

        let body: [String: Any] = [
            "prompt": fullPrompt,
            "max_length": UserDefaults.standard.integer(forKey: "max_generated_tokens"),
            "temperature": UserDefaults.standard.double(forKey: "temperature"),
            "rep_pen": UserDefaults.standard.double(forKey: "repeat_penalty"),
            "top_k": UserDefaults.standard.double(forKey: "top_k"),
            "top_p": UserDefaults.standard.double(forKey: "top_p"),
            "typical": 1,
            "tfs": 1,
            "top_a": 0,
            "rep_pen_range": 256,
            "rep_pen_slope": 1,
            "quiet": false
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


struct KoboldResponse: Codable {
    struct Result: Codable {
        let text: String
    }
    let results: [Result]
}
