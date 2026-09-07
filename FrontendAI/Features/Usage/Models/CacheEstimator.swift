import Foundation

enum CacheEstimator {
    static func estimatedByteCount(for history: ChatHistory) -> Int {
        var byteCount = 64
        byteCount += MemoryLayout<UUID>.size
        byteCount += history.messages.reduce(0) { $0 + estimatedByteCount(for: $1) }
        return byteCount
    }

    private static func estimatedByteCount(for message: ChatMessageEntity) -> Int {
        var byteCount = 64
        byteCount += message.text.utf8.count
        byteCount += MemoryLayout<UUID>.size
        byteCount += MemoryLayout<Int>.size
        byteCount += MemoryLayout<Bool>.size

        if let variants = message.variants {
            byteCount += variants.reduce(0) { $0 + $1.utf8.count }
        }

        return byteCount
    }
}
