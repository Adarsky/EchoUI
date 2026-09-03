import Testing
@testable import FrontendAI

struct ChatStreamCompletionTests {
    @Test
    func openAICompletionReasonEndsStreamWithoutDoneSentinel() {
        let event = """
        {
          "choices": [
            {
              "delta": { "role": "assistant", "content": "Finished reply" },
              "index": 0,
              "finish_reason": "stop"
            }
          ]
        }
        """
        var resultParts: [String] = []
        var streamedParts: [String] = []

        let didFinish = APIService.appendOpenAIEvent(
            event,
            to: &resultParts,
            onStream: { streamedParts.append($0) }
        )

        #expect(didFinish)
        #expect(resultParts == ["Finished reply"])
        #expect(streamedParts == ["Finished reply"])
    }

    @Test
    func openRouterCompletionReasonEndsStreamAndClosesThinking() {
        let event = """
        {
          "choices": [
            {
              "delta": {},
              "index": 0,
              "finish_reason": "stop"
            }
          ]
        }
        """
        var resultParts = ["<think>", "Reasoning"]
        var streamedParts: [String] = []
        var thinkingOpened = true
        var thinkingClosed = false

        let didFinish = APIService.appendOpenRouterEvent(
            event,
            to: &resultParts,
            thinkingOpened: &thinkingOpened,
            thinkingClosed: &thinkingClosed,
            onStream: { streamedParts.append($0) }
        )

        #expect(didFinish)
        #expect(thinkingClosed)
        #expect(resultParts == ["<think>", "Reasoning", "</think>"])
        #expect(streamedParts == ["</think>"])
    }
}
