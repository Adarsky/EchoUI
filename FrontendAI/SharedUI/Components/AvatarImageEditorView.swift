import SwiftUI
import UIKit

struct AvatarEditorDraftImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct AvatarImageEditorView: View {
    let onCancel: () -> Void
    let onApply: (UIImage) -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var workingImage: UIImage
    @State private var rotationQuarterTurns: Int = 0
    @State private var isMirrored: Bool = false
    @State private var zoomScale: CGFloat = 1
    @State private var committedZoomScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var committedOffset: CGSize = .zero
    @State private var cropSize: CGFloat = 0

    init(
        image: UIImage,
        onCancel: @escaping () -> Void,
        onApply: @escaping (UIImage) -> Void
    ) {
        let normalized = image.normalizedForEditing()
        self.onCancel = onCancel
        self.onApply = onApply
        _workingImage = State(initialValue: normalized)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let resolvedCropSize = max(220, min(proxy.size.width - 40, proxy.size.height * 0.6))

                VStack(spacing: 24) {
                    Spacer(minLength: 12)
                    editorCanvas(cropSize: resolvedCropSize)
                    controls
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 20)
            .background(editorBackground.ignoresSafeArea())
            .navigationTitle("Edit Avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Use Photo") {
                        onApply(renderCroppedAvatar())
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func editorCanvas(cropSize: CGFloat) -> some View {
        let baseSize = baseDisplaySize(for: workingImage.size, cropSize: cropSize)

        return VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(canvasBackground)

                Image(uiImage: workingImage)
                    .resizable()
                    .frame(width: baseSize.width, height: baseSize.height)
                    .scaleEffect(x: isMirrored ? -1 : 1, y: 1, anchor: .center)
                    .rotationEffect(.degrees(Double(rotationQuarterTurns) * 90))
                    .scaleEffect(zoomScale, anchor: .center)
                    .offset(offset)

                cropGuidesOverlay(cropSize: cropSize)
                    .frame(width: cropSize, height: cropSize)
                    .allowsHitTesting(false)
            }
            .frame(width: cropSize, height: cropSize)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(canvasBorder, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .gesture(dragGesture(cropSize: cropSize))
            .simultaneousGesture(magnificationGesture(cropSize: cropSize))
            .onAppear {
                self.cropSize = cropSize
            }
            .onChange(of: cropSize) { _, newValue in
                self.cropSize = newValue
                committedOffset = clampedOffset(committedOffset, cropSize: newValue)
                offset = committedOffset
            }

            Text("Drag to reposition and pinch to zoom")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func dragGesture(cropSize: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let proposed = CGSize(
                    width: committedOffset.width + value.translation.width,
                    height: committedOffset.height + value.translation.height
                )
                offset = clampedOffset(proposed, cropSize: cropSize)
            }
            .onEnded { _ in
                committedOffset = clampedOffset(offset, cropSize: cropSize)
                offset = committedOffset
            }
    }

    private func magnificationGesture(cropSize: CGFloat) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoomScale = min(max(committedZoomScale * value, 1), 6)
                offset = clampedOffset(offset, cropSize: cropSize)
            }
            .onEnded { _ in
                committedZoomScale = zoomScale
                committedOffset = clampedOffset(offset, cropSize: cropSize)
                offset = committedOffset
            }
    }

    private func cropGuidesOverlay(cropSize: CGFloat) -> some View {
        ZStack {
            Path { path in
                let rect = CGRect(origin: .zero, size: CGSize(width: cropSize, height: cropSize))
                path.addRect(rect)
                path.addEllipse(in: rect.insetBy(dx: 2, dy: 2))
            }
            .fill(
                Color.black.opacity(0.3),
                style: FillStyle(eoFill: true)
            )

            Path { path in
                let oneThird = cropSize / 3
                let twoThirds = oneThird * 2

                path.move(to: CGPoint(x: oneThird, y: 0))
                path.addLine(to: CGPoint(x: oneThird, y: cropSize))
                path.move(to: CGPoint(x: twoThirds, y: 0))
                path.addLine(to: CGPoint(x: twoThirds, y: cropSize))

                path.move(to: CGPoint(x: 0, y: oneThird))
                path.addLine(to: CGPoint(x: cropSize, y: oneThird))
                path.move(to: CGPoint(x: 0, y: twoThirds))
                path.addLine(to: CGPoint(x: cropSize, y: twoThirds))
            }
            .stroke(Color.white.opacity(0.24), lineWidth: 0.9)

            Circle()
                .inset(by: 2)
                .stroke(Color.white.opacity(0.5), lineWidth: 1.4)
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            controlButton(title: "Rotate Left", icon: "rotate.left") {
                rotate(clockwise: false)
            }
            controlButton(title: "Mirror", icon: "arrow.left.and.right.righttriangle.left.righttriangle.right") {
                mirror()
            }
            controlButton(title: "Reset", icon: "arrow.counterclockwise") {
                resetTransform()
            }
        }
    }

    private func controlButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(controlBackground)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var editorBackground: Color {
        Color(.systemBackground)
    }

    private var canvasBackground: Color {
        colorScheme == .light ? Color(.secondarySystemGroupedBackground) : Color.white.opacity(0.06)
    }

    private var canvasBorder: Color {
        colorScheme == .light ? Color.primary.opacity(0.16) : Color.white.opacity(0.32)
    }

    private var controlBackground: Color {
        colorScheme == .light ? Color(.secondarySystemFill) : Color.white.opacity(0.1)
    }

    private func baseDisplaySize(for imageSize: CGSize, cropSize: CGFloat) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGSize(width: cropSize, height: cropSize)
        }
        let scale = max(cropSize / imageSize.width, cropSize / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    private func clampedOffset(_ proposed: CGSize, cropSize: CGFloat) -> CGSize {
        let baseSize = baseDisplaySize(for: workingImage.size, cropSize: cropSize)
        let orientedBase = orientedBaseSize(from: baseSize)
        let displayedSize = CGSize(
            width: orientedBase.width * zoomScale,
            height: orientedBase.height * zoomScale
        )
        let maxX = max(0, (displayedSize.width - cropSize) / 2)
        let maxY = max(0, (displayedSize.height - cropSize) / 2)
        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }

    private func renderCroppedAvatar() -> UIImage {
        guard cropSize > 0 else { return workingImage }

        let outputSide: CGFloat = 1024
        let baseSize = baseDisplaySize(for: workingImage.size, cropSize: cropSize)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(
            size: CGSize(width: outputSide, height: outputSide),
            format: format
        ).image { context in
            let cg = context.cgContext
            let scale = outputSide / cropSize

            cg.translateBy(x: outputSide / 2, y: outputSide / 2)
            cg.scaleBy(x: scale, y: scale)
            cg.translateBy(x: offset.width, y: offset.height)
            cg.scaleBy(x: zoomScale, y: zoomScale)
            cg.rotate(by: CGFloat(rotationQuarterTurns) * (.pi / 2))
            cg.scaleBy(x: isMirrored ? -1 : 1, y: 1)

            let drawRect = CGRect(
                x: -baseSize.width / 2,
                y: -baseSize.height / 2,
                width: baseSize.width,
                height: baseSize.height
            )
            workingImage.draw(in: drawRect)
        }
    }

    private func rotate(clockwise: Bool) {
        let sourceOffset = committedOffset
        rotationQuarterTurns = (rotationQuarterTurns + (clockwise ? 1 : 3)) % 4
        let rotatedOffset = CGSize(
            width: clockwise ? -sourceOffset.height : sourceOffset.height,
            height: clockwise ? sourceOffset.width : -sourceOffset.width
        )
        committedOffset = clampedOffset(rotatedOffset, cropSize: cropSize)
        offset = committedOffset
    }

    private func mirror() {
        isMirrored.toggle()
        let mirroredOffset = CGSize(width: -committedOffset.width, height: committedOffset.height)
        committedOffset = clampedOffset(mirroredOffset, cropSize: cropSize)
        offset = committedOffset
    }

    private func resetTransform() {
        rotationQuarterTurns = 0
        isMirrored = false
        zoomScale = 1
        committedZoomScale = 1
        offset = .zero
        committedOffset = .zero
    }

    private func orientedBaseSize(from baseSize: CGSize) -> CGSize {
        if rotationQuarterTurns.isMultiple(of: 2) {
            return baseSize
        }
        return CGSize(width: baseSize.height, height: baseSize.width)
    }
}

private extension UIImage {
    func normalizedForEditing() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
