//  ChatView+UI.swift
//  FrontendAI

import SwiftUI
import UIKit

extension ChatView {
    @ViewBuilder
    var chatBackground: some View {
        GeometryReader { geo in
            if let chatWallpaperImage {
                Image(uiImage: chatWallpaperImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .blur(radius: clampedChatWallpaperBlurRadius)
                    .clipped()
                    .overlay(
                        Color.black.opacity(0.14)
                            .frame(width: geo.size.width, height: geo.size.height)
                    )
                    .overlay {
                        smartWallpaperGradientOverlay
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
            } else {
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.systemGroupedBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .ignoresSafeArea()
    }

    var bottomInputMaterialFade: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(chatBottomChromeFadeColor)
                .frame(height: geo.safeAreaInsets.bottom + 90)
                .mask(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .black, location: 0),
                            .init(color: .clear, location: 1)
                        ]),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea(edges: .bottom)
                .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    var smartWallpaperGradientOverlay: some View {
        if let chatWallpaperSmartGradient {
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: chatWallpaperSmartGradient.topColor.opacity(0.32), location: 0),
                    .init(color: chatWallpaperSmartGradient.edgeColor.opacity(0.12), location: 0.5),
                    .init(color: chatWallpaperSmartGradient.bottomColor.opacity(0.34), location: 1)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    var chatTopChromeFadeColor: Color {
        chatWallpaperSmartGradient?.topColor ?? chatChromeFadeColor
    }

    var chatBottomChromeFadeColor: Color {
        chatWallpaperSmartGradient?.bottomColor ?? chatChromeFadeColor
    }

    var chatChromeFadeColor: Color {
        colorScheme == .light ? .white : .black
    }

    var clampedChatWallpaperBlurRadius: CGFloat {
        guard activeChatAppearance.wallpaperBlurEnabled else { return 0 }
        return CGFloat(activeChatAppearance.clampedWallpaperBlurRadius)
    }

    @MainActor
    func migrateLegacyWallpaperIfNeeded() {
        ChatAppearanceStore.migrateLegacyWallpaperIfNeeded()
    }

    var currentChatAppearanceID: String? {
        ChatAppearanceStore.chatID(botID: botID, firstMessageID: messages.first?.id)
    }

    @MainActor
    func refreshActiveAppearance() {
        activeChatAppearance = ChatAppearanceStore.resolved(
            botID: botID,
            chatID: currentChatAppearanceID
        )
        refreshWallpaperImage()
    }

    @MainActor
    func refreshWallpaperImage() {
        let image = ChatWallpaperStore.loadImage(from: activeChatAppearance.wallpaperPath)
        chatWallpaperImage = image
        chatWallpaperSmartGradient = image.flatMap(ChatWallpaperSmartGradient.make)
    }

    // MARK: – Header helpers
    func startNewChatTapped() {
        if personas.isEmpty {
            performStartNewChat()
            return
        }
        showPersonaPickerForNewChat = true
    }

    func performStartNewChat() {
        saveChatHistory()
        messages.removeAll()
        currentHistory = nil
        messages.append(ChatMessageModel(content: bot.greeting, isUser: false))
        refreshActiveAppearance()
    }

    @MainActor
    func scrollToLatestMessageIfNeeded(using proxy: ScrollViewProxy) {
        guard !didApplyInitialScrollPosition else { return }
        guard let latestMessageID = messages.last?.id else { return }

        DispatchQueue.main.async {
            proxy.scrollTo(latestMessageID, anchor: .bottom)
            didApplyInitialScrollPosition = true
        }
    }
}

struct ChatWallpaperSmartGradient {
    let topColor: Color
    let edgeColor: Color
    let bottomColor: Color

    static func make(from image: UIImage) -> ChatWallpaperSmartGradient? {
        guard let samples = ChatWallpaperEdgeSampler.samples(from: image) else { return nil }

        return ChatWallpaperSmartGradient(
            topColor: samples.top.swiftUIColor,
            edgeColor: samples.edges.swiftUIColor,
            bottomColor: samples.bottom.swiftUIColor
        )
    }
}

private enum ChatWallpaperEdgeSampler {
    struct Samples {
        let top: UIColor
        let edges: UIColor
        let bottom: UIColor
    }

    private static let sampleSize = CGSize(width: 72, height: 72)

    static func samples(from image: UIImage) -> Samples? {
        let width = Int(sampleSize.width)
        let height = Int(sampleSize.height)
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        let didRender = pixels.withUnsafeMutableBytes { rawBuffer -> Bool in
            guard let context = CGContext(
                data: rawBuffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ) else {
                return false
            }

            context.interpolationQuality = .medium
            UIGraphicsPushContext(context)
            UIColor.black.setFill()
            UIRectFill(CGRect(origin: .zero, size: sampleSize))
            image.draw(in: CGRect(origin: .zero, size: sampleSize))
            UIGraphicsPopContext()
            return true
        }

        guard didRender else { return nil }

        let verticalBandHeight = max(1, Int(CGFloat(height) * 0.18))
        let horizontalBandWidth = max(1, Int(CGFloat(width) * 0.12))

        var top = PixelAccumulator()
        var bottom = PixelAccumulator()
        var edges = PixelAccumulator()

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                let pixel = Pixel(
                    red: pixels[offset],
                    green: pixels[offset + 1],
                    blue: pixels[offset + 2],
                    alpha: pixels[offset + 3]
                )

                if y < verticalBandHeight {
                    top.add(pixel)
                }

                if y >= height - verticalBandHeight {
                    bottom.add(pixel)
                }

                if x < horizontalBandWidth || x >= width - horizontalBandWidth {
                    edges.add(pixel)
                }
            }
        }

        guard top.count > 0, bottom.count > 0, edges.count > 0 else { return nil }

        return Samples(
            top: top.uiColor,
            edges: edges.uiColor,
            bottom: bottom.uiColor
        )
    }
}

private struct Pixel {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: UInt8
}

private struct PixelAccumulator {
    private(set) var count = 0
    private var red = 0.0
    private var green = 0.0
    private var blue = 0.0

    mutating func add(_ pixel: Pixel) {
        guard pixel.alpha > 0 else { return }

        let alpha = Double(pixel.alpha) / 255.0
        red += Double(pixel.red) * alpha
        green += Double(pixel.green) * alpha
        blue += Double(pixel.blue) * alpha
        count += 1
    }

    var uiColor: UIColor {
        guard count > 0 else { return .clear }

        let divisor = Double(count) * 255.0
        return UIColor(
            red: CGFloat(red / divisor),
            green: CGFloat(green / divisor),
            blue: CGFloat(blue / divisor),
            alpha: 1
        )
    }
}

private extension UIColor {
    var swiftUIColor: Color {
        Color(self)
    }
}
