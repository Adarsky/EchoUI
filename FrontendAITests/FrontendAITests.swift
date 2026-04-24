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
