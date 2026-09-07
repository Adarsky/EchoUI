import Foundation

enum DataUsageEstimator {
    static func estimatedTrafficByteCount(for message: ChatMessageEntity) -> Int {
        var byteCount = 512
        byteCount += message.text.utf8.count

        if let variants = message.variants {
            byteCount += variants.reduce(0) { $0 + $1.utf8.count }
        }

        return byteCount
    }
}
