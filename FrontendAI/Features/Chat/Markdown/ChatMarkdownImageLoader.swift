import Foundation
import ImageIO
import UIKit

/// Decode a thumbnail off the main actor; never upload a full-resolution source to the GPU.
actor ChatMarkdownImageLoader {
    static let shared = ChatMarkdownImageLoader()
    private let cache = NSCache<NSURL, UIImage>()

    init() {
        cache.totalCostLimit = 24 * 1_024 * 1_024
        cache.countLimit = 24
    }

    func image(at url: URL) async throws -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        let (data, response) = try await URLSession.shared.data(from: url)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode), data.count <= 16 * 1_024 * 1_024,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1_200,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        let image = UIImage(cgImage: thumbnail)
        cache.setObject(image, forKey: url as NSURL, cost: thumbnail.bytesPerRow * thumbnail.height)
        return image
    }
}
