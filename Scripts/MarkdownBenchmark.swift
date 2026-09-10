import Foundation

/// Compile with the four parser/model files listed in Documentation/Markdown.md.
@main
struct MarkdownBenchmark {
    static func main() {
        let history = (1...200).map {
            "Paragraph \($0) with **bold**, *emphasis*, and `code`.\n\n"
        }.joined()
        let clock = ContinuousClock()
        var renderer = ChatMarkdownRenderer()
        _ = renderer.render(history)
        let initialBytes = renderer.parsedByteCount
        var source = history
        let incrementalTime = clock.measure {
            for number in 1...100 {
                source += "Update \(number) with **formatting**.\n\n"
                _ = renderer.render(source)
            }
        }
        let incrementalBytes = renderer.parsedByteCount - initialBytes
        source = history
        var fullBytes = 0
        let fullTime = clock.measure {
            for number in 1...100 {
                source += "Update \(number) with **formatting**.\n\n"
                _ = ChatMarkdownParser.parse(source)
                fullBytes += source.utf8.count
            }
        }
        print("Incremental: \(incrementalTime), \(incrementalBytes) bytes parsed")
        print("Full parse:  \(fullTime), \(fullBytes) bytes parsed")

        let parseCount = renderer.parseCount
        let idleTime = clock.measure {
            for _ in 0..<1_000 { _ = renderer.render(source) }
        }
        print("1,000 unchanged reads: \(idleTime), \(renderer.parseCount - parseCount) parses")
    }
}
