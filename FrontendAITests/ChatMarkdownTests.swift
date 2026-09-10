import Foundation
import Testing
@testable import FrontendAI

struct ChatMarkdownTests {
    @Test
    func rendersBlockAndInlineMarkdown() {
        let blocks = ChatMarkdownParser.parse("""
        # Heading

        **bold** *italic* ~~deleted~~ `inline` [link](https://example.com)
        next line

        > Quote
        > - Nested

        3. Third
        4. Fourth

        ---

        ```swift
        let path = "/new/notes"
        let newline = "\\n"
        ```

        | Name | Count |
        | :--- | ---: |
        | One | 2 |
        """)
        #expect(blocks.contains { $0.kind == .header(level: 1) })
        #expect(blocks.contains { $0.kind == .blockQuote })
        #expect(blocks.contains { $0.kind == .thematicBreak })
        let paragraph = blocks[1]
        let text = paragraph.parts[0].text
        #expect(text.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
        #expect(text.runs.contains { $0.inlinePresentationIntent?.contains(.emphasized) == true })
        #expect(text.runs.contains { $0.inlinePresentationIntent?.contains(.strikethrough) == true })
        #expect(text.runs.contains { $0.link?.absoluteString == "https://example.com" })
        #expect(String(text.characters).contains("\nnext line"))
        let list = blocks.first { $0.kind == .orderedList }
        #expect(list?.children.first?.kind == .listItem(ordinal: 3))
        let code = blocks.first { $0.kind == .codeBlock(languageHint: "swift") }
        let codeText = code.map { String($0.text.characters) } ?? ""
        #expect(codeText.contains("\"\\n\""))
        #expect(codeText.contains("/new/notes"))
        guard let table = blocks.last, case .table(let columns) = table.kind else {
            Issue.record("Missing table")
            return
        }
        #expect(columns.map(\.alignment) == [.left, .right])
        #expect(table.children.count == 2)
    }

    @Test
    func supportsTasksImagesEscapesAndSafeLinks() {
        let blocks = ChatMarkdownParser.parse("""
        - [x] Done
        - [ ] Pending
        - \\[x] Literal brackets
        - `[x] code`

        ![Description](https://example.com/image.png)

        [unsafe](javascript:alert) [email](mailto:hello@example.com)
        """)
        #expect(blocks[0].children.map(\.taskChecked) == [true, false, nil, nil])
        #expect(String(blocks[0].children[0].children[0].parts[0].text.characters) == "Done")
        #expect(blocks[1].parts[0].imageURL?.absoluteString == "https://example.com/image.png")
        #expect(!blocks[2].parts[0].text.runs.contains { $0.link?.scheme == "javascript" })
        #expect(blocks[2].parts[0].text.runs.contains { $0.link?.scheme == "mailto" })
    }

    @Test
    func streamingMatchesFreshParsingAtEveryChunk() {
        let documents = [
            "# Heading\n\nFirst **bold**.\n\nSecond.\n\nTitle\n---\n\nEnd.",
            "Intro\n\nParagraph.\n\n~~~swift\nlet text = \"\\n\"\n\n---\n~~~\n\nAfter.",
            "Start\n\nNext\n\n> Quote\n>\n> - item\n>   - nested\n\nEnd\n\nLast.",
            "One\n\nTwo\n\n- first\n\n  second paragraph\n- next\n\nEnd\n\nLast.",
            "One\n\nTwo\n\n| a | b |\n|---|---:|\n| x | y |\n\nAfter\n\nLast.",
            "[link][ref]\n\nMiddle\n\nMore\n\n[ref]: https://example.com\n\nLast.",
            "😀 Привет\r\n\r\n次の段落\r\n\r\nThird\r\n\r\nFourth\r\n\r\nLast",
            "One\n\n---\n\nTwo\n\n***\n\nThree\n\n___\n\nFour",
            "a\n\nb\n\nc\n\n- \n- text\n\nd\n\ne\n\nf",
            "a\n\nb\n\nc\n\n>\n> quote\n\nd\n\ne\n\nf",
            "a\n\nb\n\nc\n\n```\n```\n\nd\n\ne\n\nf",
            "a\n\nb\n\nc\n\n<div>\nhello\n\nworld\n</div>\n\nd\n\ne\n\nf",
            "a\n\nb\n\nc\n\n    indented\n\n    code\n\nd\n\ne\n\nf",
            "a\n\nb\n\nc\n\n| a | b |\n|---|---|\n| | |\n| x | |\n| | |\n\nd\n\ne\n\nf",
            "a\n\nb\n\nc\n\n![](https://example.com/a)\n\nd\n\ne\n\nf"
        ]
        for document in documents {
            var renderer = ChatMarkdownRenderer()
            var source = ""
            for character in document {
                source.append(character)
                #expect(renderer.render(source) == ChatMarkdownParser.parse(source), "Mismatch for \(source.debugDescription)")
            }
        }
    }

    @Test
    func preservesEmptyTableCellsAndRows() {
        let table = ChatMarkdownParser.parse("| a | b |\n|---|---|\n| | |\n| x | |\n| | |\n").first
        #expect(table?.children.count == 4)
        #expect(table?.children[1].children.isEmpty == true)
        #expect(table?.children[2].children.count == 1)
        #expect(table?.children[3].children.isEmpty == true)
        let empty = ChatMarkdownParser.parse("| a | b |\n|---|---|\n| | |\n").first
        #expect(empty?.children.count == 2)
    }

    @Test
    func imageWithoutDescriptionStillRenders() {
        let image = ChatMarkdownParser.parse("![](https://example.com/image.png)").first?.parts.first
        #expect(image?.imageURL?.absoluteString == "https://example.com/image.png")
        #expect(image?.text.characters.isEmpty == true)
    }

    @Test
    func editsAndLateReferencesInvalidateCachedBlocks() {
        var renderer = ChatMarkdownRenderer()
        let original = "[link][ref]\n\nTwo\n\nThree\n\nFour"
        _ = renderer.render(original)
        let resolved = renderer.render(original + "\n\n[ref]: https://example.com")
        #expect(resolved[0].parts[0].text.runs.contains { $0.link != nil })
        let edited = "## Replacement\n\nDifferent message"
        #expect(renderer.render(edited) == ChatMarkdownParser.parse(edited))
        #expect(renderer.render("").isEmpty)
    }

    @Test
    func unicodeNormalizationEditsDoNotReuseInvalidByteOffsets() {
        var renderer = ChatMarkdownRenderer()
        let composed = "Café\n\nTwo\n\nThree\n\nFour"
        let decomposed = "Cafe\u{301}\n\nTwo\n\nThree\n\nFour"
        _ = renderer.render(composed)
        #expect(renderer.render(decomposed) == ChatMarkdownParser.parse(decomposed))
        let appended = decomposed + "\n\n**More**"
        #expect(renderer.render(appended) == ChatMarkdownParser.parse(appended))
    }

    @Test
    func unchangedTextDoesNotParseAndStreamingReusesCompletedBlocks() {
        var renderer = ChatMarkdownRenderer()
        let history = (1...100).map { "Paragraph \($0) with **formatting**.\n\n" }.joined()
        let initial = renderer.render(history)
        let initialBytes = renderer.parsedByteCount
        for _ in 0..<100 { #expect(renderer.render(history) == initial) }
        #expect(renderer.parseCount == 1)
        let updated = renderer.render(history + "New **formatted** text")
        #expect(Array(updated.prefix(98)) == Array(initial.prefix(98)))
        #expect(renderer.parsedByteCount - initialBytes < 200)
    }

    @Test @MainActor
    func modelFormatsDuringStreamingAndInvalidatesOnVariantAndEdit() {
        let message = ChatMessageModel(content: "", isUser: false)
        message.setStreaming(true)
        message.appendChunk("# Live\n\n**Already bold**", to: 0)
        #expect(message.isStreaming)
        #expect(message.markdownBlocks[0].kind == .header(level: 1))
        #expect(message.markdownBlocks[1].parts[0].text.runs.contains {
            $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true
        })
        message.addNewVariant()
        #expect(message.markdownBlocks.isEmpty)
        message.appendChunk("## Variant", to: 1)
        #expect(message.markdownBlocks[0].kind == .header(level: 2))
        message.replaceCurrentVariant(with: "### Edited")
        #expect(message.markdownBlocks[0].kind == .header(level: 3))
        message.switchVariant(offset: -1)
        #expect(message.markdownBlocks[0].kind == .header(level: 1))
        let reasoning = ChatMessageModel(content: "<think># Reasoning\n\n**Thinking**", isUser: false)
        #expect(reasoning.thinkingMarkdownBlocks[0].kind == .header(level: 1))
    }
}
