import Foundation

/// A value tree keeps completed blocks stable while the streaming tail changes.
struct ChatMarkdownBlock: Identifiable, Equatable {
    let id: Int
    let kind: PresentationIntent.Kind
    var text = AttributedString()
    var children: [ChatMarkdownBlock] = []
    var parts: [ChatMarkdownInline] = []
    var taskChecked: Bool?
    var sourceEnd = 0

    var maximumID: Int {
        children.reduce(id) { max($0, $1.maximumID) }
    }
}
