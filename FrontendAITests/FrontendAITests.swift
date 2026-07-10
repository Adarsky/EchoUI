import Testing
import Foundation
import SQLite3
import SwiftData
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
        #expect(presetRequest.value(forHTTPHeaderField: "User-Agent") == janitorPreset.userAgent)
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
                ),
                supportedParameters: ["max_tokens", "temperature"]
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

    @Test func privateChatsStayHiddenOutsideAnUnlockedPrivateFolder() {
        let privateBot = BotModel(
            name: "Private",
            subtitle: "Secret",
            date: "Today",
            avatarSystemName: "lock",
            iconColorName: "blue",
            isPinned: false,
            greeting: "Private"
        )
        let publicBot = BotModel(
            name: "Public",
            subtitle: "Visible",
            date: "Today",
            avatarSystemName: "person",
            iconColorName: "blue",
            isPinned: false,
            greeting: "Public"
        )
        let privateFolder = ChatFolder(
            name: "Private",
            botIDStrings: [ChatFolder.storageID(for: privateBot.id)]
        )
        let workFolder = ChatFolder(
            name: "Work",
            botIDStrings: [
                ChatFolder.storageID(for: privateBot.id),
                ChatFolder.storageID(for: publicBot.id)
            ]
        )
        let bots = [privateBot, publicBot]
        let folders = [privateFolder, workFolder]

        #expect(PrivateChatVisibility.visibleBots(
            from: bots,
            folders: folders,
            foldersEnabled: true,
            selectedFolderID: ChatFolder.allFolderID,
            unlockedPrivateFolderID: nil
        ).map(\.id) == [publicBot.id])
        #expect(PrivateChatVisibility.visibleBots(
            from: bots,
            folders: folders,
            foldersEnabled: true,
            selectedFolderID: ChatFolder.allFolderID,
            unlockedPrivateFolderID: privateFolder.id.uuidString
        ).map(\.id) == [publicBot.id])
        #expect(PrivateChatVisibility.visibleBots(
            from: bots,
            folders: folders,
            foldersEnabled: false,
            selectedFolderID: ChatFolder.allFolderID,
            unlockedPrivateFolderID: nil
        ).map(\.id) == [publicBot.id])
        #expect(PrivateChatVisibility.visibleBots(
            from: bots,
            folders: folders,
            foldersEnabled: true,
            selectedFolderID: workFolder.id.uuidString,
            unlockedPrivateFolderID: nil
        ).map(\.id) == [publicBot.id])
        #expect(PrivateChatVisibility.visibleBots(
            from: bots,
            folders: folders,
            foldersEnabled: true,
            selectedFolderID: privateFolder.id.uuidString,
            unlockedPrivateFolderID: privateFolder.id.uuidString
        ).map(\.id) == [privateBot.id])
    }

    @Test func serverSentEventParserAcceptsOptionalSpaceAndMultilineData() {
        var parser = ServerSentEventParser()

        #expect(parser.consume(line: ": keep-alive") == nil)
        #expect(parser.consume(line: "data:{\"first\":1}") == "{\"first\":1}")
        #expect(parser.consume(line: "") == nil)
        #expect(parser.consume(line: "data: first") == nil)
        #expect(parser.consume(line: "data:second") == nil)
        #expect(parser.consume(line: "event: message") == nil)
        #expect(parser.consume(line: "") == "first\nsecond")
        #expect(parser.finish() == nil)
    }

    @Test func serverSentEventParserStreamsJSONWithoutBlankSeparators() {
        var parser = ServerSentEventParser()

        #expect(parser.consume(line: "data:{\"chunk\":1}") == "{\"chunk\":1}")
        #expect(parser.consume(line: "data: {\"chunk\":2}\r") == "{\"chunk\":2}")
        #expect(parser.consume(line: "data: [DONE]") == "[DONE]")
        #expect(parser.finish() == nil)
    }

    @Test @MainActor func cancellingAnEmptyRegenerationKeepsThePreviousVariant() {
        let message = ChatMessageModel(content: "Original reply", isUser: false)
        message.addNewVariant()

        #expect(message.content.isEmpty)
        #expect(message.discardEmptyCurrentVariant())
        #expect(message.content == "Original reply")
        #expect(message.allVariants == ["Original reply"])
    }

    @Test @MainActor func replacingAndDeletingHistoryMessagesDoesNotLeaveChildrenBehind() throws {
        let schema = Schema([BotModel.self, ChatHistory.self, ChatMessageEntity.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let bot = BotModel(
            name: "History",
            subtitle: "Persistence",
            date: "Today",
            avatarSystemName: "bubble.left",
            iconColorName: "blue",
            isPinned: false,
            greeting: "Hello"
        )
        let original = ChatMessageEntity(text: "Original", isUser: true, index: 0)
        let history = ChatHistory(messages: [original], bot: bot)
        context.insert(bot)
        context.insert(history)
        try context.save()

        let replacement = ChatMessageEntity(text: "Replacement", isUser: true, index: 0)
        ChatHistoryPersistence.replaceMessages(
            in: history,
            with: [replacement],
            context: context
        )
        try context.save()

        let messagesAfterReplacement = try context.fetch(FetchDescriptor<ChatMessageEntity>())
        #expect(messagesAfterReplacement.count == 1)
        #expect(messagesAfterReplacement.first?.text == "Replacement")

        ChatHistoryPersistence.delete(history, context: context)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<ChatHistory>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<ChatMessageEntity>()) == 0)
    }

    @Test func liveSQLiteBackupCreatesAReadableConsistentSnapshot() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("FrontendAITests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: rootURL) }

        let storeURL = rootURL.appendingPathComponent("FrontendAI.store")
        var database: OpaquePointer?
        #expect(sqlite3_open(storeURL.path, &database) == SQLITE_OK)
        guard let database else { return }
        defer { sqlite3_close(database) }
        #expect(sqlite3_exec(database, "PRAGMA journal_mode=WAL", nil, nil, nil) == SQLITE_OK)
        #expect(sqlite3_exec(database, "CREATE TABLE sample(value TEXT)", nil, nil, nil) == SQLITE_OK)
        #expect(sqlite3_exec(database, "INSERT INTO sample VALUES ('saved')", nil, nil, nil) == SQLITE_OK)

        let backupData = try PortableStoreBackup.makeBackupData(
            from: StoreBackupManager.storeFileURLs(for: storeURL).map(StoreRecoveryFileSnapshot.init),
            snapshotLiveStore: true
        )
        let importedBackup = try PortableStoreBackup.importBackupData(backupData)
        defer { try? fileManager.removeItem(at: importedBackup.url) }

        let importedStoreURL = importedBackup.url.appendingPathComponent("FrontendAI.store")
        var importedDatabase: OpaquePointer?
        #expect(sqlite3_open_v2(importedStoreURL.path, &importedDatabase, SQLITE_OPEN_READONLY, nil) == SQLITE_OK)
        guard let importedDatabase else { return }
        defer { sqlite3_close(importedDatabase) }

        var statement: OpaquePointer?
        #expect(sqlite3_prepare_v2(importedDatabase, "SELECT value FROM sample", -1, &statement, nil) == SQLITE_OK)
        guard let statement else { return }
        defer { sqlite3_finalize(statement) }
        #expect(sqlite3_step(statement) == SQLITE_ROW)
        #expect(String(cString: sqlite3_column_text(statement, 0)) == "saved")
    }

    @Test func oversizedPortableBackupIsRejectedBeforeReading() throws {
        let fileManager = FileManager.default
        let url = fileManager.temporaryDirectory
            .appendingPathComponent("FrontendAITests-\(UUID().uuidString).frontendai-backup")
        defer { try? fileManager.removeItem(at: url) }

        #expect(fileManager.createFile(atPath: url.path, contents: Data()))
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: UInt64(PortableStoreBackup.maximumArchiveByteCount + 1))
        try handle.close()

        #expect(throws: PortableStoreBackupError.self) {
            try PortableStoreBackup.readImportData(from: url)
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
