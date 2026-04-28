//
//  FrontendAITests.swift
//  FrontendAITests
//
//  Created by macbook on 25.03.2025.
//

import Testing
import Foundation
@testable import FrontendAI

struct FrontendAITests {

    @Test func officialOpenAIEndpointForcesHTTPSAndNormalizesV1() {
        let normalized = APIType.openai.normalizedBaseURL("http://api.openai.com/v1")

        #expect(normalized == "https://api.openai.com")
        #expect(APIType.openai.endpoint(baseURL: normalized, path: "models") == "https://api.openai.com/v1/models")
        #expect(!APIType.openai.requiresHTTPAPIKeyConfirmation(baseURL: "http://api.openai.com/v1", apiKey: "sk-test"))
    }

    @Test func customOpenAIHTTPEndpointIsPreservedAndWarnsWhenKeyIsSet() {
        let normalized = APIType.openai.normalizedBaseURL("http://localhost:1234/v1")

        #expect(normalized == "http://localhost:1234")
        #expect(APIType.openai.endpoint(baseURL: normalized, path: "models") == "http://localhost:1234/v1/models")
        #expect(APIType.openai.requiresHTTPAPIKeyConfirmation(baseURL: normalized, apiKey: "sk-test"))
        #expect(!APIType.openai.requiresHTTPAPIKeyConfirmation(baseURL: normalized, apiKey: ""))
    }

    @Test func officialOpenRouterEndpointForcesHTTPS() {
        let normalized = APIType.openrouter.normalizedBaseURL("http://openrouter.ai/api/v1")

        #expect(normalized == "https://openrouter.ai")
        #expect(APIType.openrouter.endpoint(baseURL: normalized, path: "credits") == "https://openrouter.ai/api/v1/credits")
    }

    @Test func openRouterModelListDecodesPayloadWithMetadata() throws {
        let data = Data("""
        {
          "data": [
            {
              "id": "z-ai/glm-4.5-air:free",
              "name": "Z.ai: GLM 4.5 Air (free)",
              "context_length": 131072,
              "architecture": {
                "input_modalities": ["text"],
                "output_modalities": ["text"]
              },
              "pricing": {
                "prompt": "0",
                "completion": "0"
              },
              "supported_parameters": ["max_tokens", "temperature"]
            }
          ]
        }
        """.utf8)

        let list = try JSONDecoder().decode(OpenRouterModelList.self, from: data)

        #expect(list.data == [
            OpenRouterModel(
                id: "z-ai/glm-4.5-air:free",
                name: "Z.ai: GLM 4.5 Air (free)",
                contextLength: 131072,
                architecture: OpenRouterModel.Architecture(
                    inputModalities: ["text"],
                    outputModalities: ["text"]
                )
            )
        ])
    }

    @Test func openRouterModelSearchPrioritizesPrefixMatches() {
        let models = [
            OpenRouterModel(id: "openai/gpt-4o-mini", name: "Z.ai mention only"),
            OpenRouterModel(id: "z-ai/glm-4.5"),
            OpenRouterModel(id: "qwen/qwen3-coder:free"),
            OpenRouterModel(id: "z-ai/glm-4.5-air:free")
        ]

        let results = OpenRouterModelCatalogService
            .search(models, matching: "z-ai/")
            .map(\.id)

        #expect(results == [
            "z-ai/glm-4.5",
            "z-ai/glm-4.5-air:free"
        ])
    }

    @Test func openRouterModelCompanyIconsMatchKnownProvidersOnly() {
        #expect(OpenRouterModel(id: "openai/gpt-4o-mini").companyIconAssetName == "AICompanyOpenAI")
        #expect(OpenRouterModel(id: "z-ai/glm-4.5").companyIconAssetName == "AICompanyZAI")
        #expect(OpenRouterModel(id: "meta-llama/llama-3.3-70b-instruct").companyIconAssetName == "AICompanyMeta")
        #expect(OpenRouterModel(id: "x-ai/grok-4").companyIconAssetName == "AICompanyXAI")
        #expect(OpenRouterModel(id: "cohere/command-a").companyIconAssetName == "AICompanyCohere")
        #expect(OpenRouterModel(id: "openrouter/auto").companyIconAssetName == "AICompanyOpenRouter")
        #expect(OpenRouterModel(id: "unknown-provider/custom-model").companyIconAssetName == nil)
    }

    @Test func openRouterModelVerificationUsesExactOfficialCatalogMatches() {
        let models = [
            OpenRouterModel(id: "z-ai/glm-4.5"),
            OpenRouterModel(id: "z-ai/glm-4.5-air:free")
        ]

        #expect(OpenRouterModelCatalogService.containsModel(id: "z-ai/glm-4.5-air:free", in: models))
        #expect(!OpenRouterModelCatalogService.containsModel(id: "z-ai/glm-typo", in: models))
        #expect(OpenRouterModelCatalogService.requiresOfficialCatalogValidation(baseURL: "http://openrouter.ai/api/v1"))
        #expect(!OpenRouterModelCatalogService.requiresOfficialCatalogValidation(baseURL: "http://localhost:1234"))
    }

    @Test func modelCatalogCacheStoresOpenRouterMetadataByNormalizedBaseURL() {
        let suiteName = "FrontendAITests.openRouterModelCache.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let models = [
            OpenRouterModel(
                id: "z-ai/glm-4.5-air:free",
                description: "Cached metadata",
                contextLength: 131072,
                architecture: OpenRouterModel.Architecture(modality: "text->text")
            )
        ]

        APIModelCatalogCache.storeOpenRouterModels(
            models,
            for: "http://openrouter.ai/api/v1",
            defaults: defaults
        )

        #expect(APIModelCatalogCache.cachedOpenRouterModels(
            for: "https://openrouter.ai",
            defaults: defaults
        ) == models)
    }

    @Test func modelCatalogCacheStoresOpenAIModelsByNormalizedBaseURL() {
        let suiteName = "FrontendAITests.openAIModelCache.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        APIModelCatalogCache.storeOpenAIModels(
            ["gpt-4.1-mini", "gpt-4.1"],
            for: .openai,
            baseURL: "https://api.openai.com/v1",
            defaults: defaults
        )

        #expect(APIModelCatalogCache.cachedOpenAIModels(
            for: .openai,
            baseURL: "https://api.openai.com",
            defaults: defaults
        ) == ["gpt-4.1-mini", "gpt-4.1"])
    }

    @Test func pingStatusMappingUsesWarningForReachableHTTPFailures() {
        #expect(APIConnectionStatusMapper.status(forHTTPStatusCode: 200) == .online)
        #expect(APIConnectionStatusMapper.status(forHTTPStatusCode: 204) == .online)
        #expect(APIConnectionStatusMapper.status(forHTTPStatusCode: 401) == .warning)
        #expect(APIConnectionStatusMapper.status(forHTTPStatusCode: 404) == .warning)
        #expect(APIConnectionStatusMapper.status(forHTTPStatusCode: 500) == .warning)
    }

    @Test func apiServerConnectionStatusKeepsLegacyIsOnlineCompatibility() {
        let server = APIServer(
            name: "Legacy",
            baseURL: "https://api.openai.com",
            selectedModel: "gpt-test",
            type: .openai,
            isOnline: true
        )

        #expect(server.connectionStatus == .online)

        server.updateConnectionStatus(.warning)

        #expect(server.connectionStatus == .warning)
        #expect(!server.isOnline)
    }

    @Test func storeBackupMovesStoreFilesWithoutDeletingThem() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("FrontendAITests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        let storeURL = rootURL.appendingPathComponent("FrontendAI.store")
        let sourceURLs = StoreBackupManager.storeFileURLs(for: storeURL)
        for sourceURL in sourceURLs {
            try Data("test".utf8).write(to: sourceURL)
        }

        let backupURL = try StoreBackupManager.backupStoreFiles(
            at: storeURL,
            date: Date(timeIntervalSince1970: 0)
        )

        #expect(fileManager.fileExists(atPath: backupURL.path))
        for sourceURL in sourceURLs {
            #expect(!fileManager.fileExists(atPath: sourceURL.path))
            let movedURL = backupURL.appendingPathComponent(sourceURL.lastPathComponent)
            #expect(fileManager.fileExists(atPath: movedURL.path))
        }
    }

}
