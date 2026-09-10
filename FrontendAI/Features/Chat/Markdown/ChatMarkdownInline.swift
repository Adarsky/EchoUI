import Foundation

struct ChatMarkdownInline: Identifiable, Equatable {
    let id: Int
    var text: AttributedString
    var imageURL: URL?
}
