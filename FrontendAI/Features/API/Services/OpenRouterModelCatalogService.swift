import Foundation

struct OpenRouterModel: Codable, Equatable, Identifiable, Sendable {
    struct Architecture: Codable, Equatable, Sendable {
        let modality: String?
        let inputModalities: [String]?
        let outputModalities: [String]?

        init(
            modality: String? = nil,
            inputModalities: [String]? = nil,
            outputModalities: [String]? = nil
        ) {
            self.modality = modality
            self.inputModalities = inputModalities
            self.outputModalities = outputModalities
        }

        private enum CodingKeys: String, CodingKey {
            case modality
            case inputModalities = "input_modalities"
            case outputModalities = "output_modalities"
        }
    }

    let id: String
    let name: String?
    let description: String?
    let contextLength: Int?
    let architecture: Architecture?

    init(
        id: String,
        name: String? = nil,
        description: String? = nil,
        contextLength: Int? = nil,
        architecture: Architecture? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.contextLength = contextLength
        self.architecture = architecture
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case contextLength = "context_length"
        case architecture
    }

    var normalizedDescription: String? {
        guard let description else { return nil }
        let normalized = description
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    var modalityDisplayText: String? {
        if let modality = architecture?.modality?.trimmingCharacters(in: .whitespacesAndNewlines),
           !modality.isEmpty {
            return modality.replacingOccurrences(of: "->", with: " -> ")
        }

        guard
            let inputModalities = architecture?.inputModalities,
            let outputModalities = architecture?.outputModalities,
            !inputModalities.isEmpty,
            !outputModalities.isEmpty
        else {
            return nil
        }

        return "\(inputModalities.joined(separator: ", ")) -> \(outputModalities.joined(separator: ", "))"
    }

    var companyIconAssetName: String? {
        OpenRouterModelCompanyIcon.assetName(forModelID: id, modelName: name)
    }
}

private enum OpenRouterModelCompanyIcon {
    private static let providerAssetNames: [String: String] = [
        "anthropic": "AICompanyAnthropic",
        "apple": "AICompanyApple",
        "claude": "AICompanyClaude",
        "cohere": "AICompanyCohere",
        "deepseek": "AICompanyDeepSeek",
        "gemini": "AICompanyGemini",
        "google": "AICompanyGoogle",
        "google-ai-studio": "AICompanyGoogle",
        "grok": "AICompanyGrok",
        "huggingface": "AICompanyHuggingFace",
        "huggingfaceh4": "AICompanyHuggingFace",
        "hf": "AICompanyHuggingFace",
        "hunyuan": "AICompanyHunyuan",
        "ibm": "AICompanyIBM",
        "liquid": "AICompanyLiquid",
        "liquidai": "AICompanyLiquid",
        "meta": "AICompanyMeta",
        "meta-llama": "AICompanyMeta",
        "microsoft": "AICompanyMicrosoft",
        "minimax": "AICompanyMinimax",
        "mistral": "AICompanyMistral",
        "mistralai": "AICompanyMistral",
        "moonshot": "AICompanyMoonshot",
        "moonshotai": "AICompanyMoonshot",
        "nvidia": "AICompanyNvidia",
        "openai": "AICompanyOpenAI",
        "openrouter": "AICompanyOpenRouter",
        "perplexity": "AICompanyPerplexity",
        "qwen": "AICompanyQwen",
        "x-ai": "AICompanyXAI",
        "xai": "AICompanyXAI",
        "z-ai": "AICompanyZAI",
        "zai": "AICompanyZAI"
    ]

    private static let tokenAssetNames: [(token: String, assetName: String)] = [
        ("anthropic", "AICompanyAnthropic"),
        ("claude", "AICompanyClaude"),
        ("cohere", "AICompanyCohere"),
        ("deepseek", "AICompanyDeepSeek"),
        ("gemini", "AICompanyGemini"),
        ("google", "AICompanyGoogle"),
        ("grok", "AICompanyGrok"),
        ("huggingface", "AICompanyHuggingFace"),
        ("hunyuan", "AICompanyHunyuan"),
        ("liquid", "AICompanyLiquid"),
        ("llama", "AICompanyMeta"),
        ("meta", "AICompanyMeta"),
        ("microsoft", "AICompanyMicrosoft"),
        ("minimax", "AICompanyMinimax"),
        ("mistral", "AICompanyMistral"),
        ("moonshot", "AICompanyMoonshot"),
        ("kimi", "AICompanyMoonshot"),
        ("nvidia", "AICompanyNvidia"),
        ("openai", "AICompanyOpenAI"),
        ("openrouter", "AICompanyOpenRouter"),
        ("perplexity", "AICompanyPerplexity"),
        ("qwen", "AICompanyQwen"),
        ("x-ai", "AICompanyXAI"),
        ("xai", "AICompanyXAI"),
        ("z-ai", "AICompanyZAI"),
        ("zai", "AICompanyZAI")
    ]

    static func assetName(forModelID modelID: String, modelName: String?) -> String? {
        let normalizedID = normalizedSearchText(modelID)
        if let provider = normalizedID.split(separator: "/", maxSplits: 1).first.map(String.init),
           let assetName = providerAssetNames[provider] {
            return assetName
        }

        var searchableText = normalizedID
        if let modelName {
            searchableText += " \(normalizedSearchText(modelName))"
        }

        return tokenAssetNames.first { searchableText.contains($0.token) }?.assetName
    }

    private static func normalizedSearchText(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
    }
}

struct OpenRouterModelList: Codable, Equatable, Sendable {
    let data: [OpenRouterModel]
}

enum APIModelCatalogCache {
    private struct OpenAIModelsEntry: Codable, Equatable {
        let models: [String]
        let cachedAt: Date
    }

    private struct OpenRouterModelsEntry: Codable, Equatable {
        let models: [OpenRouterModel]
        let cachedAt: Date
    }

    private static let openAIModelsKeyPrefix = "apiModelCatalog.openAIModels.v1."
    private static let openRouterModelsKeyPrefix = "apiModelCatalog.openRouterModels.v1."

    static func cachedOpenAIModels(
        for type: APIType,
        baseURL: String,
        defaults: UserDefaults = .standard
    ) -> [String]? {
        guard let key = cacheKey(prefix: openAIModelsKeyPrefix, type: type, baseURL: baseURL),
              let data = defaults.data(forKey: key),
              let entry = try? JSONDecoder().decode(OpenAIModelsEntry.self, from: data),
              !entry.models.isEmpty else {
            return nil
        }

        return entry.models
    }

    static func storeOpenAIModels(
        _ models: [String],
        for type: APIType,
        baseURL: String,
        defaults: UserDefaults = .standard
    ) {
        guard let key = cacheKey(prefix: openAIModelsKeyPrefix, type: type, baseURL: baseURL) else {
            return
        }

        guard !models.isEmpty else {
            defaults.removeObject(forKey: key)
            return
        }

        let entry = OpenAIModelsEntry(models: models, cachedAt: Date())
        if let data = try? JSONEncoder().encode(entry) {
            defaults.set(data, forKey: key)
        }
    }

    static func cachedOpenRouterModels(
        for baseURL: String,
        defaults: UserDefaults = .standard
    ) -> [OpenRouterModel]? {
        guard let key = cacheKey(prefix: openRouterModelsKeyPrefix, type: .openrouter, baseURL: baseURL),
              let data = defaults.data(forKey: key),
              let entry = try? JSONDecoder().decode(OpenRouterModelsEntry.self, from: data),
              !entry.models.isEmpty else {
            return nil
        }

        return entry.models
    }

    static func storeOpenRouterModels(
        _ models: [OpenRouterModel],
        for baseURL: String,
        defaults: UserDefaults = .standard
    ) {
        guard let key = cacheKey(prefix: openRouterModelsKeyPrefix, type: .openrouter, baseURL: baseURL) else {
            return
        }

        guard !models.isEmpty else {
            defaults.removeObject(forKey: key)
            return
        }

        let entry = OpenRouterModelsEntry(models: models, cachedAt: Date())
        if let data = try? JSONEncoder().encode(entry) {
            defaults.set(data, forKey: key)
        }
    }

    private static func cacheKey(prefix: String, type: APIType, baseURL: String) -> String? {
        let normalizedBaseURL = type.normalizedBaseURL(baseURL)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalizedBaseURL.isEmpty else { return nil }

        let encodedBaseURL = Data(normalizedBaseURL.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")

        return "\(prefix)\(type.rawValue).\(encodedBaseURL)"
    }
}

enum OpenRouterModelCatalogServiceError: LocalizedError {
    case invalidURL(String)
    case insecureTransportRequired
    case invalidResponse
    case invalidPayload
    case server(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid OpenRouter model URL."
        case .insecureTransportRequired:
            return "Official OpenRouter endpoints must use HTTPS."
        case .invalidResponse:
            return "Invalid response from OpenRouter."
        case .invalidPayload:
            return "OpenRouter returned an unexpected model list."
        case let .server(statusCode, message):
            if let message, !message.isEmpty {
                return "OpenRouter error \(statusCode): \(message)"
            }
            return "OpenRouter error \(statusCode)."
        }
    }
}

enum OpenRouterModelCatalogService {
    static func fetchModels(
        baseURL: String,
        apiKey: String?,
        tlsPolicy: TLSPolicy = .strict
    ) async throws -> [OpenRouterModel] {
        let endpoint = APIType.openrouter.endpoint(baseURL: baseURL, path: "models")
        guard let url = URL(string: endpoint) else {
            throw OpenRouterModelCatalogServiceError.invalidURL(endpoint)
        }
        guard APIType.openrouter.isSecureTransportURL(url, baseURL: baseURL) else {
            throw OpenRouterModelCatalogServiceError.insecureTransportRequired
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.applyOpenRouterAttributionHeaders()

        if let bearerToken = APIAuthorization.bearerHeaderValue(apiKey: apiKey, for: url) {
            request.addValue(bearerToken, forHTTPHeaderField: "Authorization")
        }

        let session = TLSSessionFactory.makeSession(policy: tlsPolicy)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterModelCatalogServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw OpenRouterModelCatalogServiceError.server(
                statusCode: httpResponse.statusCode,
                message: userFacingServerMessage(statusCode: httpResponse.statusCode, data: data)
            )
        }

        do {
            let models = try JSONDecoder().decode(OpenRouterModelList.self, from: data).data
            APIModelCatalogCache.storeOpenRouterModels(models, for: baseURL)
            return models
        } catch {
            throw OpenRouterModelCatalogServiceError.invalidPayload
        }
    }

    static func search(_ models: [OpenRouterModel], matching query: String) -> [OpenRouterModel] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { return [] }

        let prefixMatches = models.filter { model in
            model.id.lowercased().hasPrefix(normalizedQuery)
        }
        let prefixMatchIDs = Set(prefixMatches.map(\.id))
        let containsMatches = models.filter { model in
            guard !prefixMatchIDs.contains(model.id) else { return false }
            if model.id.lowercased().contains(normalizedQuery) {
                return true
            }
            return model.name?.lowercased().contains(normalizedQuery) == true
        }

        return prefixMatches + containsMatches
    }

    static func containsModel(id: String, in models: [OpenRouterModel]) -> Bool {
        models.contains { $0.id == id }
    }

    static func requiresOfficialCatalogValidation(baseURL: String) -> Bool {
        APIType.openrouter.requiresHTTPSForOfficialOpenRouter(baseURL: baseURL)
    }

    private static func userFacingServerMessage(statusCode: Int, data: Data) -> String? {
        switch statusCode {
        case 401, 403:
            return "Authentication failed. Check your OpenRouter API key."
        case 404:
            return "OpenRouter model endpoint was not found."
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
            let error = root["error"] as? [String: Any],
            let message = error["message"] as? String
        {
            return sanitizedMessageForDisplay(message)
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
            return String(normalized.prefix(maxCount)) + "..."
        }
        return normalized
    }
}
