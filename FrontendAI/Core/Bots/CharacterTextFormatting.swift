import Foundation

enum CharacterTextFormatting {
    static func normalized(_ text: String) -> String {
        text
            .replacingOccurrences(of: "/n/n", with: "\n\n")
            .replacingOccurrences(of: "/n", with: "\n")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    static func markdownPreservingLineBreaks(_ text: String) -> String {
        let normalizedText = normalized(text)
        var result = ""
        var newlineRun = 0

        for character in normalizedText {
            if character == "\n" {
                newlineRun += 1
                continue
            }

            appendNewlines(newlineRun, to: &result)
            newlineRun = 0
            result.append(character)
        }

        appendNewlines(newlineRun, to: &result)
        return result
    }

    private static func appendNewlines(_ count: Int, to result: inout String) {
        if count == 1 {
            result += "  \n"
        } else if count > 1 {
            result += String(repeating: "\n", count: count)
        }
    }
}
