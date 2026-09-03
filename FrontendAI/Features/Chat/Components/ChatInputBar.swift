import SwiftUI
import UIKit

struct ChatInputBar: View {
    @Binding var inputText: String
    let isGenerating: Bool
    let isThinking: Bool
    let sendButtonStyle: ChatInputBarSendButtonStyle
    let placeholder: String

    let onSend: () -> Void
    let onStop: () -> Void
    let onMeasuredHeightChange: (CGFloat) -> Void

    @FocusState private var isInputFocused: Bool
    @State private var inputFieldWidth: CGFloat = 0
    @State private var isExpandedEditorPresented = false
    @State private var showsExpandButton = false

    private let inputLineLimit = 5
    private let minimumInputHeight: CGFloat = 44
    private let inputVerticalPadding: CGFloat = 10
    private let inputLeadingPadding: CGFloat = 14
    private let focusedHorizontalPadding: CGFloat = 16
    private let idleHorizontalPadding: CGFloat = 42
    private let idleInputMaxWidth: CGFloat = 560
    private let sendButtonHeight: CGFloat = 32
    private let focusAnimation: Animation = .easeInOut(duration: 0.18)

    init(
        inputText: Binding<String>,
        isGenerating: Bool,
        isThinking: Bool,
        sendButtonStyle: ChatInputBarSendButtonStyle,
        placeholder: String,
        onSend: @escaping () -> Void,
        onStop: @escaping () -> Void,
        onMeasuredHeightChange: @escaping (CGFloat) -> Void = { _ in }
    ) {
        self._inputText = inputText
        self.isGenerating = isGenerating
        self.isThinking = isThinking
        self.sendButtonStyle = sendButtonStyle
        self.placeholder = placeholder
        self.onSend = onSend
        self.onStop = onStop
        self.onMeasuredHeightChange = onMeasuredHeightChange
    }

    private enum ButtonVisualState: Equatable {
        case idle
        case thinking
        case generating

        var symbolName: String {
            switch self {
            case .idle:
                return "arrow.up"
            case .thinking:
                return "ellipsis"
            case .generating:
                return "stop.fill"
            }
        }

        var isStopAction: Bool {
            self != .idle
        }
    }

    private var buttonVisualState: ButtonVisualState {
        guard isGenerating else { return .idle }
        return isThinking ? .thinking : .generating
    }

    private var inputFieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: minimumInputHeight / 2, style: .continuous)
    }

    private var inputFont: Font {
        .body
    }

    private var inputSizingText: String {
        guard !inputText.isEmpty else { return " " }
        return inputText.hasSuffix("\n") ? inputText + " " : inputText
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 4) {
                inputField
                    .frame(maxWidth: inputBarMaxWidth)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, inputBarHorizontalPadding)
            .animation(focusAnimation, value: isInputFocused)
        }
        .fullScreenCover(
            isPresented: $isExpandedEditorPresented,
            onDismiss: restoreInputFocus
        ) {
            ExpandedTextEditorSheet(
                text: $inputText,
                title: "Edit Message",
                placeholder: placeholder
            )
        }
    }

    private var inputBarMaxWidth: CGFloat {
        isInputFocused ? .infinity : idleInputMaxWidth
    }

    private var inputBarHorizontalPadding: CGFloat {
        isInputFocused ? focusedHorizontalPadding : idleHorizontalPadding
    }

    private var sendButtonEdgeInset: CGFloat {
        max(0, (minimumInputHeight - sendButtonHeight) / 2)
    }

    private var inputTrailingPadding: CGFloat {
        sendButtonStyle.buttonWidth + sendButtonEdgeInset * 2
    }

    private var inputField: some View {
        ZStack(alignment: .topLeading) {
            Text(verbatim: inputSizingText)
                .font(inputFont)
                .lineLimit(inputLineLimit)
                .padding(.vertical, inputVerticalPadding)
                .padding(.leading, inputLeadingPadding)
                .padding(.trailing, inputTrailingPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .hidden()
                .accessibilityHidden(true)

            TextField(placeholder, text: $inputText, axis: .vertical)
                .font(inputFont)
                .textFieldStyle(.plain)
                .lineLimit(1...inputLineLimit)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, inputVerticalPadding)
                .padding(.leading, inputLeadingPadding)
                .padding(.trailing, inputTrailingPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .focused($isInputFocused)
        }
        .frame(maxWidth: .infinity, minHeight: minimumInputHeight, alignment: .topLeading)
        .glassEffect(.regular.interactive(), in: inputFieldShape)
        .overlay(alignment: .bottomTrailing) {
            sendButton
                .padding(.trailing, sendButtonEdgeInset)
                .padding(.bottom, sendButtonEdgeInset)
        }
        .overlay(alignment: .topTrailing) {
            expandButton
                .padding(.top, sendButtonEdgeInset)
                .padding(.trailing, sendButtonEdgeInset)
                .opacity(showsExpandButton ? 1 : 0)
                .allowsHitTesting(showsExpandButton)
                .accessibilityHidden(!showsExpandButton)
        }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .preference(key: ChatInputBarWidthPreferenceKey.self, value: proxy.size.width)
            }
        }
        .contentShape(inputFieldShape)
        .onTapGesture {
            isInputFocused = true
        }
        .onAppear {
            publishMeasuredHeight()
        }
        .onChange(of: inputText) { _, _ in
            publishMeasuredHeight()
        }
        .onPreferenceChange(ChatInputBarWidthPreferenceKey.self) { width in
            guard width > 0 else { return }
            inputFieldWidth = width
            publishMeasuredHeight(for: width)
        }
        .animation(focusAnimation, value: showsExpandButton)
    }

    private var sendButton: some View {
        let visualState = buttonVisualState

        return Button(action: performPrimaryAction) {
            Image(systemName: visualState.symbolName)
                .font(.system(size: 18, weight: .semibold))
                .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
                .foregroundColor(Color(.black))
                .frame(width: sendButtonStyle.buttonWidth, height: sendButtonHeight)
                .symbolEffect(
                    .breathe.pulse.byLayer,
                    options: .repeat(.continuous),
                    isActive: visualState == .thinking
                )
        }
        .buttonBorderShape(.capsule)
        .glassEffect(.regular.tint(.white.opacity(1.0)).interactive())
        .frame(width: sendButtonStyle.buttonWidth, height: sendButtonHeight)
        .animation(.easeInOut(duration: 0.28), value: visualState)
    }

    private var expandButton: some View {
        Button(
            "Expand editor",
            systemImage: "arrow.up.left.and.arrow.down.right",
            action: presentExpandedEditor
        )
        .labelStyle(.iconOnly)
        .font(.body.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(width: 44, height: 44)
        .contentShape(.rect)
        .buttonStyle(.plain)
    }

    private var addButton: some View {
        return Button{} label: {
            Image(systemName: "plus")
                .font(.system(size: 27, weight: .semibold))
        }
        .buttonStyle(.borderless)
    }

    private func performPrimaryAction() {
        if buttonVisualState.isStopAction {
            onStop()
            return
        }

        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        onSend()
    }

    private func presentExpandedEditor() {
        isInputFocused = false
        isExpandedEditorPresented = true
    }

    private func restoreInputFocus() {
        isInputFocused = true
    }

    private func publishMeasuredHeight(for width: CGFloat? = nil) {
        let metrics = measuredInputMetrics(for: width ?? inputFieldWidth)
        Task { @MainActor in
            showsExpandButton = metrics.lineCount >= inputLineLimit
            onMeasuredHeightChange(metrics.height)
        }
    }

    private func measuredInputMetrics(for inputWidth: CGFloat) -> (height: CGFloat, lineCount: Int) {
        guard inputWidth > 0 else { return (minimumInputHeight, 1) }

        let textWidth = max(1, inputWidth - inputLeadingPadding - inputTrailingPadding)
        let font = UIFont.preferredFont(forTextStyle: .body)
        let textHeight = (inputSizingText as NSString).boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        ).height
        let lineCount = max(1, Int(ceil((textHeight / font.lineHeight) - 0.01)))
        let maxTextHeight = font.lineHeight * CGFloat(inputLineLimit)
        let height = max(
            minimumInputHeight,
            ceil(min(textHeight, maxTextHeight) + inputVerticalPadding * 2)
        )

        return (height, lineCount)
    }

}

private struct ChatInputBarWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ChatInputBarPreviewHost: View {
    @State private var inputText: String
    @State private var isGenerating: Bool
    @State private var isThinking: Bool

    init(inputText: String = "", isGenerating: Bool = false, isThinking: Bool = false) {
        _inputText = State(initialValue: inputText)
        _isGenerating = State(initialValue: isGenerating)
        _isThinking = State(initialValue: isThinking)
    }

    var body: some View {
        ChatInputBar(
            inputText: $inputText,
            isGenerating: isGenerating,
            isThinking: isThinking,
            sendButtonStyle: ChatInputBarSendButtonStyle.defaultValue,
            placeholder: "Message Assistant",
            onSend: { },
            onStop: {
                isGenerating = false
                isThinking = false
            }
        )
        .padding(.vertical, 8)
    }
}

#Preview("Idle") {
    ChatInputBarPreviewHost()
}

#Preview("Generating") {
    ChatInputBarPreviewHost(inputText: "Draft prompt...", isGenerating: true)
}

#Preview("Thinking") {
    ChatInputBarPreviewHost(inputText: "Draft prompt...", isGenerating: true, isThinking: true)
}
