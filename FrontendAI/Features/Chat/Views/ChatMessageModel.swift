import SwiftUI
import SwiftData
import UIKit
import Combine

// MARK: - Chat Message Model
final class ChatMessageModel: ObservableObject, Identifiable {
    private struct ThinkingParserState {
        enum Mode {
            case undecided
            case normal
            case inThinking
            case afterThinking
        }

        struct ParsedChunk {
            var displayContent = ""
            var thinkingContent = ""
        }

        private static let openTag = "<think>"
        private static let closeTag = "</think>"

        var mode: Mode = .undecided
        var pending: String = ""
        var hasLeadingThink: Bool = false

        mutating func consume(_ chunk: String) -> ParsedChunk {
            guard !chunk.isEmpty else { return ParsedChunk() }

            var parsed = ParsedChunk()
            switch mode {
            case .undecided:
                pending.append(chunk)
                resolveUndecidedMode(into: &parsed)
            case .normal, .afterThinking:
                parsed.displayContent.append(chunk)
            case .inThinking:
                consumeThinkingChunk(chunk, into: &parsed)
            }
            return parsed
        }

        mutating func resolveUndecidedMode(into parsed: inout ParsedChunk) {
            guard !pending.isEmpty else { return }

            if Self.openTag.hasPrefix(pending), pending.count < Self.openTag.count {
                return
            }

            if pending.hasPrefix(Self.openTag) {
                hasLeadingThink = true
                mode = .inThinking

                let remainder = String(pending.dropFirst(Self.openTag.count))
                pending.removeAll(keepingCapacity: true)

                if !remainder.isEmpty {
                    consumeThinkingChunk(remainder, into: &parsed)
                }
                return
            }

            mode = .normal
            parsed.displayContent.append(pending)
            pending.removeAll(keepingCapacity: true)
        }

        mutating func consumeThinkingChunk(_ chunk: String, into parsed: inout ParsedChunk) {
            let incoming = pending + chunk
            pending.removeAll(keepingCapacity: true)

            if let closeRange = incoming.range(of: Self.closeTag) {
                parsed.thinkingContent.append(contentsOf: incoming[..<closeRange.lowerBound])
                mode = .afterThinking

                let remainder = incoming[closeRange.upperBound...]
                if !remainder.isEmpty {
                    parsed.displayContent.append(contentsOf: remainder)
                }
                return
            }

            let overlap = Self.longestClosingTagOverlap(incoming)
            if overlap > 0 {
                let safeEnd = incoming.index(incoming.endIndex, offsetBy: -overlap)
                parsed.thinkingContent.append(contentsOf: incoming[..<safeEnd])
                pending = String(incoming[safeEnd...])
            } else {
                parsed.thinkingContent.append(incoming)
            }
        }

        static func parsed(from raw: String) -> (state: ThinkingParserState, chunk: ParsedChunk) {
            var state = ThinkingParserState()
            let parsed = state.consume(raw)
            return (state, parsed)
        }

        private static func longestClosingTagOverlap(_ text: String) -> Int {
            let maxLength = min(closeTag.count - 1, text.count)
            guard maxLength > 0 else { return 0 }

            for length in stride(from: maxLength, through: 1, by: -1) {
                let suffix = text.suffix(length)
                if closeTag.hasPrefix(String(suffix)) {
                    return length
                }
            }
            return 0
        }
    }

    private struct VariantStorage {
        var rawContent: String
        var displayContent: String
        var thinkingContent: String
        var hasLeadingThink: Bool
        var parserState: ThinkingParserState
        var thinkingStartedAt: Date?
        var thinkingClosedAt: Date?
        var failure: ChatReplyFailure?

        init(rawContent: String, failure: ChatReplyFailure? = nil) {
            let parsed = ThinkingParserState.parsed(from: rawContent)
            self.rawContent = rawContent
            self.displayContent = parsed.chunk.displayContent
            self.thinkingContent = parsed.chunk.thinkingContent
            self.hasLeadingThink = parsed.state.hasLeadingThink
            self.parserState = parsed.state
            self.thinkingStartedAt = nil
            self.thinkingClosedAt = nil
            self.failure = failure
        }

        mutating func appendChunk(_ chunk: String) {
            let now = Date()

            failure = nil
            rawContent.append(chunk)
            let parsed = parserState.consume(chunk)

            if parserState.hasLeadingThink && thinkingStartedAt == nil {
                thinkingStartedAt = now
            }
            if parserState.mode == .afterThinking && thinkingClosedAt == nil {
                thinkingClosedAt = now
            }

            displayContent.append(parsed.displayContent)
            thinkingContent.append(parsed.thinkingContent)
            hasLeadingThink = parserState.hasLeadingThink
        }

        var thinkingStatusText: String {
            guard let duration = thinkingDurationText else { return "thinking" }
            return "thought for \(duration)"
        }

        var thinkingDurationText: String? {
            guard hasLeadingThink else { return nil }
            guard let started = thinkingStartedAt, let ended = thinkingClosedAt else { return nil }

            let totalSeconds = max(0, Int(ended.timeIntervalSince(started).rounded(.down)))
            if totalSeconds < 60 {
                return "\(totalSeconds) \(pluralized(totalSeconds, singular: "second"))"
            }

            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            if seconds > 0 {
                return "\(minutes) \(pluralized(minutes, singular: "minute")) and \(seconds) \(pluralized(seconds, singular: "second"))"
            }

            return "\(minutes) \(pluralized(minutes, singular: "minute"))"
        }

        private func pluralized(_ value: Int, singular: String) -> String {
            value == 1 ? singular : "\(singular)s"
        }

        mutating func finalizeThinkingIfNeeded(at date: Date) {
            guard hasLeadingThink else { return }
            guard thinkingClosedAt == nil else { return }
            if thinkingStartedAt == nil {
                thinkingStartedAt = date
            }
            thinkingClosedAt = date
        }

        var isThinkingInProgress: Bool {
            hasLeadingThink && thinkingClosedAt == nil
        }

        var isEmptyPlaceholder: Bool {
            failure == nil
                && displayContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !hasLeadingThink
        }
    }

    let id: UUID
    let isUser: Bool
    var timestamp: Date

    @Published private var variants: [VariantStorage]
    @Published var currentIndex: Int = 0
    @Published var isStreaming: Bool = false

    var content: String {
        guard variants.indices.contains(currentIndex) else { return variants.first?.displayContent ?? "" }
        return variants[currentIndex].displayContent
    }

    var thinkingContent: String {
        guard variants.indices.contains(currentIndex) else { return variants.first?.thinkingContent ?? "" }
        return variants[currentIndex].thinkingContent
    }

    var hasThinkingContent: Bool {
        guard variants.indices.contains(currentIndex) else { return variants.first?.hasLeadingThink ?? false }
        return variants[currentIndex].hasLeadingThink
    }

    var thinkingStatusText: String {
        guard variants.indices.contains(currentIndex) else { return variants.first?.thinkingStatusText ?? "thinking" }
        return variants[currentIndex].thinkingStatusText
    }

    var thinkingDurationText: String? {
        guard variants.indices.contains(currentIndex) else { return variants.first?.thinkingDurationText }
        return variants[currentIndex].thinkingDurationText
    }

    var isThinkingInProgress: Bool {
        guard variants.indices.contains(currentIndex) else { return variants.first?.isThinkingInProgress ?? false }
        return variants[currentIndex].isThinkingInProgress
    }

    var failure: ChatReplyFailure? {
        guard variants.indices.contains(currentIndex) else { return variants.first?.failure }
        return variants[currentIndex].failure
    }

    var hasPersistableVariant: Bool {
        !variants.isEmpty && !isDiscardableEmptyAssistantPlaceholder
    }

    var isDiscardableEmptyAssistantPlaceholder: Bool {
        !isUser
            && !isStreaming
            && variants.allSatisfy(\.isEmptyPlaceholder)
    }

    var contentForConversation: String? {
        if variants.indices.contains(currentIndex), variants[currentIndex].failure == nil {
            return variants[currentIndex].displayContent
        }

        return variants.last(where: { $0.failure == nil })?.displayContent
    }

    var allVariants: [String] { variants.map(\.displayContent) }
    var hasMultipleVariants: Bool { variants.count > 1 }

    init(
        id: UUID = UUID(),
        content: String,
        isUser: Bool,
        timestamp: Date = Date(),
        variants: [String]? = nil,
        currentIndex: Int = 0,
        restorePersistedFailures: Bool = false
    ) {
        let initialVariantTexts = (variants?.isEmpty == false ? variants : [content]) ?? [content]
        let clampedIndex = max(0, min(currentIndex, initialVariantTexts.count - 1))
        var restoredVariants = initialVariantTexts.map { storedValue in
            let restored = ChatStoredVariant.restored(
                from: storedValue,
                migrateLegacyError: restorePersistedFailures && !isUser
            )
            return VariantStorage(rawContent: restored.content, failure: restored.failure)
        }
        var restoredIndex = clampedIndex

        if restorePersistedFailures && !isUser {
            let retainedIndices = restoredVariants.indices.filter {
                !restoredVariants[$0].isEmptyPlaceholder
            }
            if !retainedIndices.isEmpty, retainedIndices.count != restoredVariants.count {
                let selectedOriginalIndex = retainedIndices.contains(clampedIndex)
                    ? clampedIndex
                    : retainedIndices[retainedIndices.count - 1]
                restoredIndex = retainedIndices.firstIndex(of: selectedOriginalIndex) ?? 0
                restoredVariants = retainedIndices.map { restoredVariants[$0] }
            }
        }

        self.id = id
        self.isUser = isUser
        self.timestamp = timestamp
        self.variants = restoredVariants
        self.currentIndex = restoredIndex
    }

    @MainActor
    func appendChunk(_ chunk: String, to variant: Int) {
        guard variants.indices.contains(variant) else { return }
        variants[variant].appendChunk(chunk)
    }

    @MainActor
    func addNewVariant() {
        variants.append(VariantStorage(rawContent: ""))
        currentIndex = variants.count - 1
    }

    @MainActor
    func discardEmptyCurrentVariant() -> Bool {
        guard variants.count > 1,
              variants.indices.contains(currentIndex),
              variants[currentIndex].displayContent.isEmpty,
              !variants[currentIndex].hasLeadingThink else {
            return false
        }

        variants.remove(at: currentIndex)
        currentIndex = min(currentIndex, variants.count - 1)
        return true
    }

    @MainActor
    func switchVariant(offset: Int) {
        guard !variants.isEmpty else { return }
        currentIndex = (currentIndex + offset + variants.count) % variants.count
    }
    
    @MainActor
    func replaceCurrentVariant(with text: String) {
        guard variants.indices.contains(currentIndex) else { return }
        variants[currentIndex] = VariantStorage(rawContent: text)
    }

    @MainActor
    func finalizeThinkingNow() {
        guard variants.indices.contains(currentIndex) else { return }
        variants[currentIndex].finalizeThinkingIfNeeded(at: .now)
    }

    @MainActor
    func setStreaming(_ value: Bool) {
        guard isStreaming != value else { return }
        isStreaming = value
    }

    @MainActor
    func setFailure(_ failure: ChatReplyFailure) {
        guard variants.indices.contains(currentIndex) else { return }
        variants[currentIndex].finalizeThinkingIfNeeded(at: .now)
        variants[currentIndex].failure = failure
        setStreaming(false)
    }

    @MainActor
    func touchTimestamp(_ value: Date = Date()) {
        timestamp = value
    }

    @MainActor
    func persistenceValues(includeVariants: Bool) -> (
        text: String,
        variants: [String]?,
        currentVariantIndex: Int?
    )? {
        guard !variants.isEmpty, !isDiscardableEmptyAssistantPlaceholder else { return nil }

        let persistedIndex = max(0, min(currentIndex, variants.count - 1))
        let texts = variants.map { variant in
            ChatStoredVariant(
                content: variant.displayContent,
                failure: variant.failure
            )
            .encodedValue
        }

        return (
            text: texts[persistedIndex],
            variants: includeVariants && texts.count > 1 ? texts : nil,
            currentVariantIndex: includeVariants && texts.count > 1 ? persistedIndex : nil
        )
    }

}

enum TokenUsageEstimator {
    static func estimatedTokenCount(for message: ChatMessageEntity) -> Int {
        let text = ChatStoredVariant.restored(
            from: message.text,
            migrateLegacyError: !message.isUser
        )
        .content
        let textCount = estimatedTokenCount(for: text)
        let variantCount = message.variants?.reduce(0) { result, storedValue in
            let content = ChatStoredVariant.restored(
                from: storedValue,
                migrateLegacyError: !message.isUser
            )
            .content
            return result + estimatedTokenCount(for: content)
        } ?? 0
        return textCount + variantCount
    }

    static func estimatedTokenCount(for message: ChatMessageModel) -> Int {
        estimatedTokenCount(for: message.content)
    }

    static func estimatedTokenCount(for text: String) -> Int {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return 0 }

        return max(1, Int((Double(normalized.utf8.count) / 4.0).rounded(.up)))
    }
}
