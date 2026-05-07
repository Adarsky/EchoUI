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

    @Test func bearerAuthorizationIsOnlyBuiltForHTTPSEndpoints() {
        let httpsURL = URL(string: "https://api.example.com/v1/chat/completions")!
        let httpURL = URL(string: "http://localhost:1234/v1/chat/completions")!

        #expect(APIAuthorization.bearerHeaderValue(apiKey: " sk-test\n", for: httpsURL) == "Bearer sk-test")
        #expect(APIAuthorization.bearerHeaderValue(apiKey: "sk-test", for: httpURL) == nil)
        #expect(APIAuthorization.bearerHeaderValue(apiKey: "", for: httpsURL) == nil)
    }

    @Test func officialOpenRouterEndpointForcesHTTPS() {
        let normalized = APIType.openrouter.normalizedBaseURL("http://openrouter.ai/api/v1")

        #expect(normalized == "https://openrouter.ai")
        #expect(APIType.openrouter.endpoint(baseURL: normalized, path: "credits") == "https://openrouter.ai/api/v1/credits")
    }

    @Test func openRouterAttributionHeadersUseDefaultsAndPresets() {
        let suiteName = "FrontendAITests.openRouterAttribution.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        var defaultRequest = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/chat/completions")!)
        defaultRequest.applyOpenRouterAttributionHeaders(defaults: defaults)

        #expect(defaultRequest.value(forHTTPHeaderField: "HTTP-Referer") == "https://echo-ui.app")
        #expect(defaultRequest.value(forHTTPHeaderField: "X-Title") == "Echo UI")
        #expect(defaultRequest.value(forHTTPHeaderField: "User-Agent") == "EchoUI/1.0")

        let janitorPreset = OpenRouterAttributionHeaders.presets.first { $0.id == "janitor-ai" }!
        defaults.set(janitorPreset.httpReferer, forKey: OpenRouterAttributionStorageKeys.httpReferer)
        defaults.set(janitorPreset.xTitle, forKey: OpenRouterAttributionStorageKeys.xTitle)
        defaults.set(janitorPreset.userAgent, forKey: OpenRouterAttributionStorageKeys.userAgent)

        var presetRequest = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/models")!)
        presetRequest.applyOpenRouterAttributionHeaders(defaults: defaults)

        #expect(presetRequest.value(forHTTPHeaderField: "HTTP-Referer") == "https://janitorai.com")
        #expect(presetRequest.value(forHTTPHeaderField: "X-Title") == "Janitor AI")
        #expect(presetRequest.value(forHTTPHeaderField: "User-Agent") == "JanitorAI/1.0")
    }

    @Test func openRouterAttributionHeadersSupportCustomValues() {
        let suiteName = "FrontendAITests.openRouterCustomAttribution.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set(" https://example.app\n", forKey: OpenRouterAttributionStorageKeys.httpReferer)
        defaults.set(" My App\r\n", forKey: OpenRouterAttributionStorageKeys.xTitle)
        defaults.set(" MyApp/2.0\n", forKey: OpenRouterAttributionStorageKeys.userAgent)

        let headers = OpenRouterAttributionHeaders.current(defaults: defaults)

        #expect(headers.httpReferer == "https://example.app")
        #expect(headers.xTitle == "My App")
        #expect(headers.userAgent == "MyApp/2.0")
        #expect(OpenRouterAttributionHeaders.matchingPreset(
            httpReferer: headers.httpReferer,
            xTitle: headers.xTitle,
            userAgent: headers.userAgent
        ) == nil)
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

    @Test func redirectPolicyAllowsSameOriginAuthorizationRedirect() {
        var current = URLRequest(url: URL(string: "https://api.example.com/v1/chat/completions")!)
        current.addValue("Bearer sk-test", forHTTPHeaderField: "Authorization")
        let proposed = URLRequest(url: URL(string: "https://api.example.com/v1/responses")!)

        #expect(APIRedirectPolicy.redirectedRequest(from: current, to: proposed) != nil)
    }

    @Test func redirectPolicyBlocksAuthorizationAcrossHosts() {
        var current = URLRequest(url: URL(string: "https://api.example.com/v1/chat/completions")!)
        current.addValue("Bearer sk-test", forHTTPHeaderField: "Authorization")
        let proposed = URLRequest(url: URL(string: "https://evil.example/v1/chat/completions")!)

        #expect(APIRedirectPolicy.redirectedRequest(from: current, to: proposed) == nil)
    }

    @Test func redirectPolicyBlocksAuthorizationAcrossSchemes() {
        var current = URLRequest(url: URL(string: "http://localhost:1234/v1/chat/completions")!)
        current.addValue("Bearer sk-test", forHTTPHeaderField: "Authorization")
        let proposed = URLRequest(url: URL(string: "https://localhost:1234/v1/chat/completions")!)

        #expect(APIRedirectPolicy.redirectedRequest(from: current, to: proposed) == nil)
    }

    @Test func redirectPolicyBlocksHTTPSDowngrade() {
        let current = URLRequest(url: URL(string: "https://api.example.com/v1/models")!)
        let proposed = URLRequest(url: URL(string: "http://api.example.com/v1/models")!)

        #expect(APIRedirectPolicy.redirectedRequest(from: current, to: proposed) == nil)
    }

    @Test func redirectPolicyAllowsUnauthenticatedHTTPToHTTPSUpgradeOnSameHost() {
        let current = URLRequest(url: URL(string: "http://api.example.com/v1/models")!)
        let proposed = URLRequest(url: URL(string: "https://api.example.com/v1/models")!)

        #expect(APIRedirectPolicy.redirectedRequest(from: current, to: proposed) != nil)
    }

    @Test func redirectPolicyBlocksCrossHostRedirectWithoutAuthorization() {
        let current = URLRequest(url: URL(string: "https://api.example.com/v1/models")!)
        let proposed = URLRequest(url: URL(string: "https://metadata.google.internal/v1/models")!)

        #expect(APIRedirectPolicy.redirectedRequest(from: current, to: proposed) == nil)
    }

    @Test func storeProtectionAppliesCompleteProtectionToDirectoryAndFiles() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("FrontendAITests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        let storeURL = rootURL.appendingPathComponent("FrontendAI.store")
        let sourceURLs = StoreBackupManager.storeFileURLs(for: storeURL)
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        for sourceURL in sourceURLs {
            try Data("test".utf8).write(to: sourceURL)
        }

        try StoreFileProtectionManager.protectStoreFiles(for: storeURL)

        expectProtectedWhenSupported(rootURL)
        for sourceURL in sourceURLs {
            expectProtectedWhenSupported(sourceURL)
        }
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
        expectProtectedWhenSupported(StoreBackupManager.backupsRootURL(for: storeURL))
        expectProtectedWhenSupported(backupURL)
        #expect(try StoreBackupManager.backupsRootURL(for: storeURL)
            .resourceValues(forKeys: [.isExcludedFromBackupKey])
            .isExcludedFromBackup == true)
        #expect(try backupURL
            .resourceValues(forKeys: [.isExcludedFromBackupKey])
            .isExcludedFromBackup == true)
        for sourceURL in sourceURLs {
            #expect(!fileManager.fileExists(atPath: sourceURL.path))
            let movedURL = backupURL.appendingPathComponent(sourceURL.lastPathComponent)
            #expect(fileManager.fileExists(atPath: movedURL.path))
            expectProtectedWhenSupported(movedURL)
        }
    }

    private func expectProtectedWhenSupported(_ url: URL) {
        #if targetEnvironment(simulator)
        _ = url
        #else
        if StoreFileProtectionManager.volumeSupportsFileProtection(at: url) {
            #expect(StoreFileProtectionManager.isProtected(url))
        }
        #endif
    }

}
