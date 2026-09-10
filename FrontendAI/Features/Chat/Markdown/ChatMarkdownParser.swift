import SwiftUI

/// Foundation supplies CommonMark parsing, including nested containers and GFM tables.
/// Only the presentation tree is built here; Markdown is never interpreted as HTML.
enum ChatMarkdownParser {
    static func parse(_ source: String, offset: Int = 0, identityOffset: Int = 0) -> [ChatMarkdownBlock] {
        guard !source.isEmpty else { return [] }
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible,
            appliesSourcePositionAttributes: true
        )
        guard let attributed = try? AttributedString(markdown: source, options: options) else {
            return [ChatMarkdownBlock(id: identityOffset + 1, kind: .paragraph,
                                      text: AttributedString(source),
                                      parts: [.init(id: 0, text: AttributedString(source))])]
        }

        // Byte offsets avoid repeatedly walking a growing Unicode string by Character.
        let bytes = Array(source.utf8)
        var lineEnds: [Int] = []
        for index in bytes.indices where bytes[index] == 10 || (bytes[index] == 13 && (index + 1 == bytes.count || bytes[index + 1] != 10)) {
            lineEnds.append(index + 1)
        }
        lineEnds.append(bytes.count)

        var nodes: [Int: ChatMarkdownBlock] = [:]
        var childIDs: [Int: [Int]] = [:]
        var roots: [Int] = []
        var nextIdentity = identityOffset
        for run in attributed.runs {
            let path = run.presentationIntent?.components.reversed().map { $0 } ?? []
            guard !path.isEmpty else { continue }
            var parent: Int?
            for component in path {
                let id = component.identity
                if nodes[id] == nil {
                    nextIdentity += 1
                    nodes[id] = ChatMarkdownBlock(id: nextIdentity, kind: component.kind)
                    if let parent { childIDs[parent, default: []].append(id) }
                    else { roots.append(id) }
                }
                if let position = run.markdownSourcePosition, position.endLine > 0,
                   position.endLine <= lineEnds.count {
                    let end = max(nodes[id]?.sourceEnd ?? 0, offset + lineEnds[position.endLine - 1])
                    nodes[id]?.sourceEnd = end
                }
                parent = id
            }
            if let parent {
                nodes[parent]?.text.append(AttributedString(attributed[run.range]))
            }
        }

        func build(_ id: Int) -> ChatMarkdownBlock {
            var node = nodes[id] ?? ChatMarkdownBlock(id: id, kind: .paragraph)
            node.children = (childIDs[id] ?? []).map(build)
            node.sourceEnd = node.children.reduce(node.sourceEnd) { max($0, $1.sourceEnd) }
            if case .table = node.kind {
                restoreEmptyTableRows(in: &node, bytes: bytes, offset: offset)
            }
            if case .listItem = node.kind, !node.children.isEmpty,
               case .paragraph = node.children[0].kind {
                let prefix = String(node.children[0].text.characters.prefix(4))
                if prefix == "[ ] " || prefix == "[x] " || prefix == "[X] " {
                    // Escaped brackets and inline code are ordinary text, not task markers.
                    let firstRun = childIDs[id]?.first.flatMap { nodes[$0]?.text.runs.first }
                    let position = firstRun?.markdownSourcePosition
                    let lineStart = position.map { $0.startLine > 1 ? lineEnds[$0.startLine - 2] : 0 } ?? 0
                    let start = lineStart + (position?.startColumn ?? 1) - 1
                    if bytes.indices.contains(start), bytes[start] == 91,
                       firstRun?.inlinePresentationIntent?.contains(.code) != true {
                        node.taskChecked = prefix != "[ ] "
                        let end = node.children[0].text.characters.index(node.children[0].text.startIndex, offsetBy: 4)
                        node.children[0].text.removeSubrange(node.children[0].text.startIndex..<end)
                        node.children[0].parts = inlineParts(node.children[0].text)
                    }
                }
            }
            node.parts = inlineParts(node.text)
            // Source metadata is needed for incremental boundaries, not for Text layout.
            node.text.presentationIntent = nil
            node.text.markdownSourcePosition = nil
            return node
        }
        return roots.map(build)
    }

    private static func restoreEmptyTableRows(in table: inout ChatMarkdownBlock, bytes: [UInt8], offset: Int) {
        // Foundation omits runs for empty cells and completely empty rows.
        var rows: [Int: ChatMarkdownBlock] = [:]
        var lastRow = 0
        for row in table.children {
            if case .tableRow(let index) = row.kind {
                rows[index] = row
                lastRow = max(lastRow, index)
            }
        }
        var cursor = table.sourceEnd - offset
        if lastRow == 0, cursor >= 0, cursor < bytes.count {
            // A header-only table's last attributed run precedes its delimiter row.
            var end = cursor
            while end < bytes.count, bytes[end] != 10 { end += 1 }
            let line = bytes[cursor..<end]
            if line.contains(45), line.allSatisfy({ [9, 13, 32, 45, 58, 124].contains($0) }) {
                cursor = min(end + 1, bytes.count)
                table.sourceEnd = offset + cursor
            }
        }
        while cursor >= 0, cursor < bytes.count {
            let start = cursor
            while cursor < bytes.count, bytes[cursor] != 10 { cursor += 1 }
            let line = bytes[start..<cursor]
            guard line.contains(124), line.allSatisfy({ [9, 13, 32, 124].contains($0) }) else { break }
            if cursor < bytes.count { cursor += 1 }
            lastRow += 1
            table.sourceEnd = offset + cursor
        }
        let header = table.children.first { $0.kind == .tableHeaderRow }
            ?? ChatMarkdownBlock(id: 0, kind: .tableHeaderRow)
        table.children = [header]
        if lastRow > 0 {
            table.children += (1...lastRow).map { index in
                rows[index] ?? ChatMarkdownBlock(id: -index, kind: .tableRow(rowIndex: index))
            }
        }
    }

    private static func inlineParts(_ text: AttributedString) -> [ChatMarkdownInline] {
        var parts: [ChatMarkdownInline] = []
        var pending = AttributedString()
        for run in text.runs {
            var fragment = AttributedString(text[run.range])
            fragment.presentationIntent = nil
            fragment.markdownSourcePosition = nil
            if let url = run.imageURL {
                if !pending.characters.isEmpty {
                    parts.append(.init(id: parts.count, text: pending))
                    pending = AttributedString()
                }
                if String(fragment.characters) == "\u{FFFC}" { fragment = AttributedString() }
                fragment.imageURL = nil
                parts.append(.init(id: parts.count, text: fragment, imageURL: safeURL(url, image: true)))
            } else {
                if run.inlinePresentationIntent?.contains(.softBreak) == true {
                    fragment = AttributedString("\n")
                }
                if run.inlinePresentationIntent?.contains(.code) == true {
                    fragment.font = .system(.body, design: .monospaced)
                    fragment.backgroundColor = .primary.opacity(0.08)
                }
                if let url = run.link { fragment.link = safeURL(url, image: false) }
                pending.append(fragment)
            }
        }
        if !pending.characters.isEmpty { parts.append(.init(id: parts.count, text: pending)) }
        return parts
    }

    static func safeURL(_ url: URL, image: Bool) -> URL? {
        let allowed = image ? ["https", "http"] : ["https", "http", "mailto"]
        guard let scheme = url.scheme?.lowercased(), allowed.contains(scheme) else { return nil }
        return url
    }
}
