import Foundation
import Testing
@testable import FrontendAI

struct ChatStreamTransportTests {
    @Test(arguments: [APIType.openai, .openrouter])
    func cleanEOFWithoutCompletionIsAnInterruptedReply(type: APIType) async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        var received = ""
        do {
            _ = try await APIService.sendMessage(
                messages: [.init(role: "user", content: "Synthetic test")],
                config: config(type: type, ending: "incomplete"),
                onStream: { received += $0 }, session: session
            )
            Issue.record("An unterminated response was accepted as complete")
        } catch let error as APIStreamError {
            #expect(received == "Partial answer")
            #expect(ChatReplyStreamService.userFacingFailure(from: error).kind == .connectionInterrupted)
        }
    }

    @Test(arguments: [APIType.openai, .openrouter], ["done", "finish"])
    func recognizedCompletionSucceeds(type: APIType, ending: String) async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let reply = try await APIService.sendMessage(
            messages: [.init(role: "user", content: "Synthetic test")],
            config: config(type: type, ending: ending), session: session
        )
        #expect(reply == "Partial answer")
    }

    private func config(type: APIType, ending: String) -> ServerConfig {
        ServerConfig(type: type, baseURL: "https://stream-test.invalid/\(ending)", selectedModel: "test",
                     apiKey: nil, allowInsecureTLS: false, customCACertificateData: nil, thinkingEffort: .none)
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StreamFixtureProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class StreamFixtureProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "text/event-stream"]) else { return }
        var body = "data: {\"choices\":[{\"index\":0,\"delta\":{\"content\":\"Partial answer\"},\"finish_reason\":null}]}\n\n"
        if url.pathComponents.contains("done") {
            body += "data: [DONE]"
        } else if url.pathComponents.contains("finish") {
            body += "data: {\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"stop\"}]}"
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() { }
}
