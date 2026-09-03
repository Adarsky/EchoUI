import CoreGraphics

struct ChatAutoScrollState {
    private(set) var isFollowing = true

    mutating func update(
        from previous: ChatScrollMetrics,
        to current: ChatScrollMetrics,
        isUserScrolling: Bool,
        bottomThreshold: CGFloat
    ) {
        let userMovedUp = isUserScrolling && current.visibleTop < previous.visibleTop
        let userReturnedToBottom = isUserScrolling &&
            current.visibleTop > previous.visibleTop &&
            current.isNearBottom(within: bottomThreshold)

        if userMovedUp {
            isFollowing = false
        } else if userReturnedToBottom {
            isFollowing = true
        }
    }
}
