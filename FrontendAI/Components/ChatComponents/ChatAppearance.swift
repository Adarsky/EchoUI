//
//  ChatAppearance.swift
//  FrontendAI
//

import SwiftUI
import UIKit
import Foundation

enum ChatAppearanceStorageKeys {
    static let userBubbleRed = "chatUserBubbleRed"
    static let userBubbleGreen = "chatUserBubbleGreen"
    static let userBubbleBlue = "chatUserBubbleBlue"
    static let userBubbleOpacity = "chatUserBubbleOpacity"
    static let userBubbleTransparent = "chatUserBubbleTransparent"

    static let botBubbleRed = "chatBotBubbleRed"
    static let botBubbleGreen = "chatBotBubbleGreen"
    static let botBubbleBlue = "chatBotBubbleBlue"
    static let botBubbleOpacity = "chatBotBubbleOpacity"
    static let botBubbleTransparent = "chatBotBubbleTransparent"

    static let wallpaperPath = "chatWallpaperPath"
    static let wallpaperBase64 = "chatWallpaperBase64" // legacy key for migration
}

enum ChatAppearanceDefaults {
    static let userBubbleRed: Double = 0.0
    static let userBubbleGreen: Double = 0.478
    static let userBubbleBlue: Double = 1.0
    static let userBubbleOpacity: Double = 0.8
    static let userBubbleTransparent: Bool = false

    static let botBubbleRed: Double = 0.557
    static let botBubbleGreen: Double = 0.557
    static let botBubbleBlue: Double = 0.576
    static let botBubbleOpacity: Double = 0.2
    static let botBubbleTransparent: Bool = false
}

enum ChatStreamingStorageKeys {
    static let chunkFlushIntervalMs = "llmStreamChunkFlushIntervalMs"
}

enum ChatStreamingDefaults {
    static let chunkMaxChars: Int = 1200
    static let chunkFlushIntervalMs: Double = 33

    static let minChunkFlushIntervalMs: Double = 10
    static let maxChunkFlushIntervalMs: Double = 1000

    static func clampedChunkFlushIntervalMs(_ value: Double) -> Double {
        min(max(value, minChunkFlushIntervalMs), maxChunkFlushIntervalMs)
    }
}

enum ChatAppearanceColor {
    static func makeColor(red: Double, green: Double, blue: Double, opacity: Double) -> Color {
        Color(red: clamp(red), green: clamp(green), blue: clamp(blue), opacity: clamp(opacity))
    }

    static func rgbaComponents(for color: Color) -> (red: Double, green: Double, blue: Double, alpha: Double) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return (
                ChatAppearanceDefaults.userBubbleRed,
                ChatAppearanceDefaults.userBubbleGreen,
                ChatAppearanceDefaults.userBubbleBlue,
                ChatAppearanceDefaults.userBubbleOpacity
            )
        }

        return (Double(red), Double(green), Double(blue), Double(alpha))
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

enum ChatWallpaperStore {
    private static let directoryName = "ChatAppearance"
    private static let fileName = "chat_wallpaper.jpg"
    private static let persistedPathToken = "local://chat_wallpaper"

    static func saveFromRawImageData(_ data: Data) -> String? {
        guard let image = UIImage(data: data) else { return nil }
        return saveImage(image)
    }

    static func saveImage(_ image: UIImage) -> String? {
        guard let normalized = resizedIfNeeded(image: image),
              let jpegData = normalized.jpegData(compressionQuality: 0.78)
        else {
            return nil
        }

        do {
            let fileURL = try wallpaperFileURL()
            try jpegData.write(to: fileURL, options: [.atomic])
            return persistedPathToken
        } catch {
            return nil
        }
    }

    static func loadImage(from path: String) -> UIImage? {
        guard let resolvedPath = resolveExistingPath(from: path) else { return nil }
        return UIImage(contentsOfFile: resolvedPath)
    }

    static func removeWallpaper(at path: String) {
        let fm = FileManager.default

        if let resolvedPath = resolvePathReference(path),
           fm.fileExists(atPath: resolvedPath) {
            try? fm.removeItem(atPath: resolvedPath)
        }

        if let canonicalPath = try? wallpaperFileURL().path,
           canonicalPath != resolvePathReference(path),
           fm.fileExists(atPath: canonicalPath) {
            try? fm.removeItem(atPath: canonicalPath)
        }
    }

    static func normalizeStoredPath(_ path: inout String) {
        if path.isEmpty {
            if let canonicalPath = try? wallpaperFileURL().path,
               FileManager.default.fileExists(atPath: canonicalPath) {
                path = persistedPathToken
            }
            return
        }

        if path == persistedPathToken {
            return
        }

        guard let canonicalPath = try? wallpaperFileURL().path else { return }
        let fm = FileManager.default
        let normalizedInput = URL(fileURLWithPath: path).standardized.path
        let normalizedCanonical = URL(fileURLWithPath: canonicalPath).standardized.path

        if normalizedInput == normalizedCanonical {
            path = persistedPathToken
            return
        }

        if path.hasSuffix("/\(fileName)") && !fm.fileExists(atPath: path) && fm.fileExists(atPath: canonicalPath) {
            path = persistedPathToken
        }
    }

    static func referencesSameWallpaper(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == rhs { return true }
        guard !lhs.isEmpty, !rhs.isEmpty else { return false }

        let lhsResolved = resolvePathReference(lhs)
        let rhsResolved = resolvePathReference(rhs)
        return lhsResolved == rhsResolved
    }

    static func migrateLegacyBase64IfNeeded(path: inout String, legacyBase64: inout String) {
        guard path.isEmpty, !legacyBase64.isEmpty else { return }
        guard let data = Data(base64Encoded: legacyBase64),
              let savedPath = saveFromRawImageData(data)
        else {
            legacyBase64 = ""
            return
        }

        path = savedPath
        legacyBase64 = ""
    }

    private static func resolveExistingPath(from path: String) -> String? {
        let fm = FileManager.default

        if let directPath = resolvePathReference(path),
           fm.fileExists(atPath: directPath) {
            return directPath
        }

        if let canonicalPath = try? wallpaperFileURL().path,
           fm.fileExists(atPath: canonicalPath) {
            return canonicalPath
        }

        return nil
    }

    private static func resolvePathReference(_ path: String) -> String? {
        guard !path.isEmpty else { return nil }

        if path == persistedPathToken {
            return try? wallpaperFileURL().path
        }

        return path
    }

    private static func wallpaperFileURL() throws -> URL {
        let fm = FileManager.default
        let appSupport = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent(directoryName, isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent(fileName)
    }

    private static func resizedIfNeeded(image: UIImage) -> UIImage? {
        let maxDimension: CGFloat = 1800
        let size = image.size
        let largestSide = max(size.width, size.height)

        guard largestSide > maxDimension else { return image }

        let scale = maxDimension / largestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
