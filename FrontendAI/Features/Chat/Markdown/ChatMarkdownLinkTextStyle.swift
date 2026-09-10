import SwiftUI

@MainActor
enum ChatMarkdownLinkTextStyle {
    static func attributedText(_ text: AttributedString, environment: EnvironmentValues, textColor: Color) -> NSAttributedString {
        let result = NSMutableAttributedString(string: "")
        let context = environment.fontResolutionContext
        for run in text.runs {
            var font = run.font ?? environment.font ?? .body
            if run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true { font = font.bold() }
            if run.inlinePresentationIntent?.contains(.emphasized) == true { font = font.italic() }
            let resolved = font.resolve(in: context)
            var nativeFont = resolved.ctFont as UIFont
            if resolved.isMonospaced || run.inlinePresentationIntent?.contains(.code) == true,
               let descriptor = nativeFont.fontDescriptor.withDesign(.monospaced) {
                nativeFont = UIFont(descriptor: descriptor, size: resolved.pointSize)
            }
            var attributes: [NSAttributedString.Key: Any] = [
                .font: nativeFont,
                .foregroundColor: UIColor(cgColor: (run.foregroundColor ?? textColor).resolve(in: environment).cgColor)
            ]
            if let link = run.link { attributes[.link] = link }
            if let background = run.backgroundColor {
                attributes[.backgroundColor] = UIColor(cgColor: background.resolve(in: environment).cgColor)
            }
            if run.inlinePresentationIntent?.contains(.strikethrough) == true {
                attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            }
            result.append(NSAttributedString(string: String(text[run.range].characters), attributes: attributes))
        }
        return result
    }
}
