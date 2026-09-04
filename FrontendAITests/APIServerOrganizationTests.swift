import Foundation
import SwiftData
import Testing
@testable import FrontendAI

struct APIServerOrganizationTests {
    @Test func groupsServersByNormalizedEndpointAndOrdersWithinGroups() throws {
        let first = APIServer(
            name: "Server 1",
            baseURL: "http://openrouter.ai/api/v1",
            selectedModel: "model/one",
            type: .openrouter,
            sortOrder: 1
        )
        let second = APIServer(
            name: "Server 2",
            baseURL: "https://openrouter.ai",
            selectedModel: "model/two",
            type: .openrouter,
            sortOrder: 0
        )
        let custom = APIServer(
            name: "Local",
            baseURL: "https://gateway.example.com/v1",
            selectedModel: "local/model",
            type: .openrouter
        )

        let groups = APIServerOrganization.groups(from: [first, custom, second])

        #expect(groups.map(\.title) == ["Official OpenRouter", "OpenRouter · https://gateway.example.com"])
        let officialGroup = try #require(groups.first)
        #expect(officialGroup.servers.map(\.name) == ["Server 2", "Server 1"])
    }

    @Test func customEndpointGroupTitlesDistinguishPortsAndPaths() {
        let portServer = APIServer(
            name: "Port",
            baseURL: "https://gateway.example.com:8443",
            selectedModel: "model/port",
            type: .openrouter
        )
        let pathServer = APIServer(
            name: "Path",
            baseURL: "https://gateway.example.com/team-a",
            selectedModel: "model/path",
            type: .openrouter
        )

        let titles = APIServerOrganization.groups(from: [portServer, pathServer]).map(\.title)

        #expect(titles.contains("OpenRouter · https://gateway.example.com:8443"))
        #expect(titles.contains("OpenRouter · https://gateway.example.com/team-a"))
    }

    @Test func groupingPreservesCaseSensitiveEndpointPaths() {
        let uppercasePath = APIServer(
            name: "Uppercase",
            baseURL: "https://gateway.example.com/TenantA",
            selectedModel: "model/uppercase",
            type: .openrouter
        )
        let lowercasePath = APIServer(
            name: "Lowercase",
            baseURL: "https://gateway.example.com/tenanta",
            selectedModel: "model/lowercase",
            type: .openrouter
        )

        let groups = APIServerOrganization.groups(from: [uppercasePath, lowercasePath])

        #expect(groups.count == 2)
        #expect(Set(groups.map(\.title)).count == 2)
    }

    @Test func pinnedServersAreSeparatedAndManuallyOrdered() {
        let later = APIServer(
            name: "Later",
            baseURL: "https://openrouter.ai",
            selectedModel: "model/later",
            type: .openrouter,
            isPinned: true,
            sortOrder: 1
        )
        let earlier = APIServer(
            name: "Earlier",
            baseURL: "https://api.openai.com",
            selectedModel: "model/earlier",
            type: .openai,
            isPinned: true,
            sortOrder: 0
        )
        let regular = APIServer(
            name: "Regular",
            baseURL: "https://openrouter.ai",
            selectedModel: "model/regular",
            type: .openrouter
        )

        #expect(APIServerOrganization.pinnedServers(from: [later, regular, earlier]).map(\.name) == ["Earlier", "Later"])
        #expect(APIServerOrganization.groups(from: [later, regular, earlier]).flatMap(\.servers).map(\.name) == ["Regular"])
    }

    @Test func sortingAndCloneNamesAreStable() {
        let beta = APIServer(
            name: "Beta",
            baseURL: "https://openrouter.ai",
            selectedModel: "z/model",
            type: .openrouter
        )
        let alpha = APIServer(
            name: "Alpha",
            baseURL: "https://openrouter.ai",
            selectedModel: "a/model",
            type: .openrouter
        )
        let existingCopy = APIServer(
            name: "Beta Copy",
            baseURL: "https://openrouter.ai",
            selectedModel: "x/model",
            type: .openrouter
        )

        #expect(APIServerOrganization.sorted([beta, alpha], by: .name).map(\.name) == ["Alpha", "Beta"])
        #expect(APIServerOrganization.sorted([beta, alpha], by: .model).map(\.name) == ["Alpha", "Beta"])
        #expect(APIServerOrganization.suggestedCloneName(for: beta, among: [beta, existingCopy]) == "Beta Copy 2")
    }

    @Test func configurationCloneUsesANewIdentityAndResetsConnectivity() {
        let source = APIServer(
            name: "Source",
            baseURL: "https://openrouter.ai",
            selectedModel: "model/source",
            availableModels: ["model/source", "model/alternate"],
            type: .openrouter,
            connectionStatus: .online,
            allowInsecureTLS: true,
            customCACertificateData: Data([1, 2, 3]),
            customCACertificateName: "test.pem",
            thinkingEffort: .high,
            isPinned: true,
            sortOrder: 4
        )

        let clone = source.makeConfigurationClone(name: "Source Copy", sortOrder: 5)

        #expect(clone.uuid != source.uuid)
        #expect(clone.name == "Source Copy")
        #expect(clone.baseURL == source.baseURL)
        #expect(clone.selectedModel == source.selectedModel)
        #expect(clone.availableModels == source.availableModels)
        #expect(clone.type == source.type)
        #expect(clone.connectionStatus == .offline)
        #expect(clone.allowInsecureTLS == source.allowInsecureTLS)
        #expect(clone.customCACertificateData == source.customCACertificateData)
        #expect(clone.customCACertificateName == source.customCACertificateName)
        #expect(clone.thinkingEffort == source.thinkingEffort)
        #expect(clone.isPinned)
        #expect(clone.sortOrder == 5)
    }

    @Test @MainActor func clonerPersistsTheNewConfiguration() throws {
        let schema = Schema([APIServer.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let source = APIServer(
            name: "Original",
            baseURL: "https://openrouter.ai",
            selectedModel: "model/original",
            type: .openrouter
        )
        context.insert(source)
        try context.save()

        let clone = try APIServerCloner.clone(
            source,
            name: "Original Copy",
            sortOrder: 1,
            in: context,
            readAPIKey: { _ in nil }
        )

        let persistedServers = try context.fetch(FetchDescriptor<APIServer>())
        #expect(persistedServers.count == 2)
        #expect(persistedServers.contains { $0.uuid == clone.uuid })
        #expect(clone.selectedModel == source.selectedModel)
    }
}
