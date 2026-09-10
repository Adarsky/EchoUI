import Foundation

/// Owned by one message, with no global cache of conversation text or streamed snapshots.
struct ChatMarkdownRenderer {
    private var source = ""
    private(set) var blocks: [ChatMarkdownBlock] = []
    private(set) var parseCount = 0
    private(set) var parsedByteCount = 0

    mutating func render(_ newSource: String) -> [ChatMarkdownBlock] {
        guard !source.utf8.elementsEqual(newSource.utf8) else { return blocks }
        var retained: [ChatMarkdownBlock] = []
        var offset = 0

        // Keep two trailing containers mutable: a new line can turn a paragraph into
        // a Setext heading/table, continue a list/quote, or close an open code fence.
        // Reference definitions can change earlier links, so those documents use a full parse.
        if !source.isEmpty, blocks.count > 2, newSource.utf8.starts(with: source.utf8),
           !newSource.contains("]:") {
            retained = Array(blocks.dropLast(2))
            while let last = retained.last, last.sourceEnd == 0 { retained.removeLast() }
            offset = retained.last?.sourceEnd ?? 0
        }

        let tail = String(decoding: newSource.utf8.dropFirst(offset), as: UTF8.self)
        let identityOffset = retained.last?.maximumID ?? 0
        let parsed = ChatMarkdownParser.parse(tail, offset: offset, identityOffset: identityOffset)
        blocks = retained + parsed
        source = newSource
        parseCount += 1
        parsedByteCount += tail.utf8.count
        return blocks
    }
}
