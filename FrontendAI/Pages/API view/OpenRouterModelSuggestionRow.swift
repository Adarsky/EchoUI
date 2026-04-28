//
//  OpenRouterModelSuggestionRow.swift
//  FrontendAI
//
//  Created by Codex on 25.04.2026.
//

import SwiftUI

struct OpenRouterModelSuggestionRow: View {
    let model: OpenRouterModel
    let onSelect: () -> Void

    var body: some View {
        rowContent
    }

    private var rowContent: some View {
        VStack() {
            HStack(alignment: .top, spacing: 8) {
                if let assetName = model.companyIconAssetName {
                    OpenRouterCompanyIconView(assetName: assetName, size: 20)
                        .padding(.top, 1)
                }

                Text(model.id)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                Spacer()
                modalityText
            }
            HStack {
                contextLengthText
                Spacer()
            }


        }
        .accessibilityLabel("Select \(model.id)")
    }

    @ViewBuilder
    private var contextLengthText: some View {
        if let contextLength = model.contextLength {
            Text("Context: \(contextLength.formatted()) tokens")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    @ViewBuilder
    private var modalityText: some View {
        if let modality = model.modalityDisplayText {
            Text("\(modality)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.green)
                .frame(maxWidth: 80)
        }
    }
}

private struct DropdownReveal<Content: View>: View {
    let isExpanded: Bool
    @ViewBuilder let content: Content

    @State private var contentHeight: CGFloat = 0

    var body: some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: DropdownRevealHeightKey.self, value: proxy.size.height)
                }
            }
            .frame(height: isExpanded ? contentHeight : 0, alignment: .top)
            .clipped()
            .allowsHitTesting(isExpanded)
            .onPreferenceChange(DropdownRevealHeightKey.self) { contentHeight = $0 }
    }
}

private struct DropdownRevealHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview("OpenRouter model row") {
    Form {
        OpenRouterModelSuggestionRow(
            model: OpenRouterModel(
                id: "deepseek/deepseek-v4-pro",
                description: "DeepSeek V4 Pro is a large-scale Mixture-of-Experts model from DeepSeek with 1.6T total parameters and 49B activated parameters, supporting a 1M-token context window. It is designed for advanced reasoning, coding, and agentic workflows.",
                contextLength: 1048576,
                architecture: OpenRouterModel.Architecture(modality: "text+image->text")
            ),
            onSelect: {}
        )
    }
}

#Preview("OpenRouter model row - ID only") {
    Form {
        OpenRouterModelSuggestionRow(
            model: OpenRouterModel(id: "openai/gpt-4o-mini"),
            onSelect: {}
        )
    }
}
