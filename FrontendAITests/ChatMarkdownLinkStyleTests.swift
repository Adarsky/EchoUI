import SwiftUI
import Testing
@testable import FrontendAI

@MainActor
struct ChatMarkdownLinkStyleTests {
    @Test
    func nativeLinkTextPreservesMarkdownAndExactDestination() {
        let source = "**bold** *italic* ~~deleted~~ `code` [site](https://example.com/path?one=1&two=2)"
        let text = ChatMarkdownParser.parse(source)[0].parts[0].text
        let result = ChatMarkdownLinkTextStyle.attributedText(text, environment: EnvironmentValues(), textColor: .white)
        #expect(result.string == "bold italic deleted code site")
        let string = result.string as NSString
        let boldFont = result.attribute(.font, at: string.range(of: "bold").location, effectiveRange: nil) as? UIFont
        let italicFont = result.attribute(.font, at: string.range(of: "italic").location, effectiveRange: nil) as? UIFont
        let codeFont = result.attribute(.font, at: string.range(of: "code").location, effectiveRange: nil) as? UIFont
        #expect(boldFont?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
        #expect(italicFont?.fontDescriptor.symbolicTraits.contains(.traitItalic) == true)
        let resolvedCodeFont = codeFont ?? .preferredFont(forTextStyle: .body)
        let narrowWidth = ("iiii" as NSString).size(withAttributes: [.font: resolvedCodeFont]).width
        let wideWidth = ("WWWW" as NSString).size(withAttributes: [.font: resolvedCodeFont]).width
        // System monospace fonts do not consistently expose the trait bit; verify glyph advances.
        #expect(abs(narrowWidth - wideWidth) < 0.01, "Code font: \(resolvedCodeFont)")
        let strike = result.attribute(.strikethroughStyle, at: string.range(of: "deleted").location, effectiveRange: nil) as? Int
        #expect(strike == NSUnderlineStyle.single.rawValue)
        let link = result.attribute(.link, at: string.range(of: "site").location, effectiveRange: nil) as? URL
        #expect(link?.absoluteString == "https://example.com/path?one=1&two=2")
        let color = result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        #expect(color?.cgColor == UIColor(Color.white).cgColor)
    }

    @Test
    func nativeLinkTextRespectsHeadingFontAndDynamicType() {
        let text = ChatMarkdownParser.parse("[Heading](https://example.com)")[0].parts[0].text
        var environment = EnvironmentValues()
        environment.font = .title.weight(.semibold)
        let standard = ChatMarkdownLinkTextStyle.attributedText(text, environment: environment, textColor: .primary)
        environment.dynamicTypeSize = .accessibility3
        let large = ChatMarkdownLinkTextStyle.attributedText(text, environment: environment, textColor: .primary)
        let standardFont = standard.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        let largeFont = large.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        #expect((largeFont?.pointSize ?? 0) > (standardFont?.pointSize ?? 0))
    }
}
