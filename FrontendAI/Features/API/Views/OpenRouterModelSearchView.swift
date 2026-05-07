import SwiftUI

struct OpenRouterModelSearchView: View {
    @Binding var searchText: String
    @FocusState private var isSearchFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    let models: [OpenRouterModel]
    let isLoadingModels: Bool
    let isModelLoadDisabled: Bool
    let onLoadModels: () -> Void
    let onUseTypedModel: () -> Void
    let onCancel: () -> Void
    let onSelectModel: (OpenRouterModel) -> Void

    private var searchResults: [OpenRouterModel] {
        OpenRouterModelCatalogService.search(models, matching: searchText)
    }

    private var hasSearchQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var topGradientColor: Color {
        colorScheme == .dark ? .black : .white
    }

    var body: some View {
        ZStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 18)

            topMaterialFade
            bottomMaterialFade
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomSearchControls
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(250))
            isSearchFocused = true
        }
    }

    private var topMaterialFade: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(topGradientColor)
                .frame(height: geo.safeAreaInsets.top + 20)
                .mask(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .black, location: 0),
                            .init(color: .clear, location: 1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea(edges: .top)
        }
        .allowsHitTesting(false)
    }

    private var bottomMaterialFade: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(topGradientColor)
                .frame(height: geo.safeAreaInsets.bottom + 20)
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
    private var content: some View {
        if hasSearchQuery {
            searchResultsContent
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(spacing: 22) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 50, weight: .regular))
                .foregroundStyle(.secondary)

            Text("Models from OpenRouter will appear here.")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if models.isEmpty || isLoadingModels {
                loadModelsButton
                    .padding(.top, 2)
            }

            Spacer()
            Spacer()
        }
    }

    private var bottomSearchControls: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("Search or enter model name", text: $searchText)
                    .autocapitalization(.none)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.go)
                    .focused($isSearchFocused)
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(.primary)
                    .tint(.blue)
                    .onSubmit {
                        if hasSearchQuery {
                            onUseTypedModel()
                        }
                    }

                if isLoadingModels {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.leading, 24)
            .padding(.trailing, 18)
            .frame(height: 50)
            .glassEffect(.regular.interactive())

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.primary)
                    .frame(width: 35, height: 35)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Close model search")
        }
    }

    private var searchResultsContent: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if !searchResults.isEmpty {
                    ForEach(searchResults) { model in
                        Button {
                            onSelectModel(model)
                        } label: {
                            OpenRouterModelResultRow(model: model)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    unavailableResultsState
                        .padding(.top, 170)
                }
            }
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private var unavailableResultsState: some View {
        VStack(spacing: 18) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(.secondary)

            Text(models.isEmpty ? "Load OpenRouter models to search the official catalog." : "No matching OpenRouter models.")
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if models.isEmpty || isLoadingModels {
                loadModelsButton
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var loadModelsButton: some View {
        Button(action: onLoadModels) {
            HStack(spacing: 8) {
                if isLoadingModels {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }

                Text(models.isEmpty ? "Load OpenRouter Models" : "Reload OpenRouter Models")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
        }
        .buttonStyle(.glass)
        .disabled(isModelLoadDisabled)
    }
}

private struct OpenRouterModelResultRow: View {
    let model: OpenRouterModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                if let assetName = model.companyIconAssetName {
                    OpenRouterCompanyIconView(assetName: assetName, size: 22)
                        .padding(.top, 1)
                }

                Text(model.id)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 10)

                if let modality = model.modalityDisplayText {
                    Text(modality)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.green)
                        .lineLimit(1)
                }
            }

            if let contextLength = model.contextLength {
                Text("Context: \(contextLength.formatted()) tokens")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if let description = model.normalizedDescription {
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(Color(.separator).opacity(0.45), lineWidth: 1)
                )
        )
    }
    
}


private let previewOpenRouterSuggestionModels: [OpenRouterModel] = [
    OpenRouterModel(
        id: "anthropic/claude-3.7-sonnet",
        name: "Claude 3.7 Sonnet",
        description: "Balanced assistant model for writing, analysis, coding, and long-context tasks.",
        contextLength: 200000,
        architecture: OpenRouterModel.Architecture(modality: "text+image->text")
    ),
    OpenRouterModel(
        id: "openai/gpt-4o-mini",
        name: "GPT-4o Mini",
        description: "Fast multimodal model for lightweight chat, extraction, and app workflows.",
        contextLength: 128000,
        architecture: OpenRouterModel.Architecture(modality: "text+image->text")
    ),
    OpenRouterModel(
        id: "google/gemini-2.0-flash-001",
        name: "Gemini 2.0 Flash",
        description: "Low-latency model tuned for responsive multimodal generation.",
        contextLength: 1048576,
        architecture: OpenRouterModel.Architecture(modality: "text+image->text")
    ),
    OpenRouterModel(
        id: "meta-llama/llama-3.3-70b-instruct",
        name: "Llama 3.3 70B Instruct",
        description: "Open instruct model for general reasoning, drafting, and tool-assisted tasks.",
        contextLength: 131072,
        architecture: OpenRouterModel.Architecture(modality: "text->text")
    ),
    OpenRouterModel(
        id: "deepseek/deepseek-chat-v3-0324",
        name: "DeepSeek Chat V3",
        description: "Mixture-of-experts chat model suited for coding, math, and complex instructions.",
        contextLength: 64000,
        architecture: OpenRouterModel.Architecture(modality: "text->text")
    ),
    OpenRouterModel(
        id: "mistralai/mistral-large-2411",
        name: "Mistral Large",
        description: "General purpose frontier model with strong multilingual and reasoning ability.",
        contextLength: 128000,
        architecture: OpenRouterModel.Architecture(modality: "text->text")
    ),
    OpenRouterModel(
        id: "qwen/qwen-2.5-coder-32b-instruct",
        name: "Qwen 2.5 Coder 32B",
        description: "Code-focused model for implementation, debugging, and technical explanation.",
        contextLength: 32768,
        architecture: OpenRouterModel.Architecture(modality: "text->text")
    ),
    OpenRouterModel(
        id: "x-ai/grok-2-vision-1212",
        name: "Grok 2 Vision",
        description: "Vision-capable model for image understanding and conversational reasoning.",
        contextLength: 32768,
        architecture: OpenRouterModel.Architecture(modality: "text+image->text")
    ),
    OpenRouterModel(
        id: "cohere/command-r-plus-08-2024",
        name: "Command R Plus",
        description: "Retrieval-augmented generation model designed for enterprise knowledge tasks.",
        contextLength: 128000,
        architecture: OpenRouterModel.Architecture(modality: "text->text")
    ),
    OpenRouterModel(
        id: "perplexity/llama-3.1-sonar-large-128k-online",
        name: "Sonar Large Online",
        description: "Online search-grounded assistant model for current-event and research answers.",
        contextLength: 127072,
        architecture: OpenRouterModel.Architecture(modality: "text->text")
    ),
    OpenRouterModel(
        id: "nousresearch/hermes-3-llama-3.1-405b",
        name: "Hermes 3 Llama 405B",
        description: "Instruction-tuned model with broad reasoning and creative writing coverage.",
        contextLength: 131072,
        architecture: OpenRouterModel.Architecture(modality: "text->text")
    ),
    OpenRouterModel(
        id: "01-ai/yi-large",
        name: "Yi Large",
        description: "Large language model for general chat, summarization, and multilingual work.",
        contextLength: 32768,
        architecture: OpenRouterModel.Architecture(modality: "text->text")
    ),
    OpenRouterModel(
        id: "amazon/nova-pro-v1",
        name: "Nova Pro",
        description: "Multimodal assistant model for analysis, content generation, and automation.",
        contextLength: 300000,
        architecture: OpenRouterModel.Architecture(modality: "text+image->text")
    ),
    OpenRouterModel(
        id: "nvidia/llama-3.1-nemotron-70b-instruct",
        name: "Nemotron 70B Instruct",
        description: "Reasoning-oriented instruct model optimized for helpful assistant behavior.",
        contextLength: 131072,
        architecture: OpenRouterModel.Architecture(modality: "text->text")
    ),
    OpenRouterModel(
        id: "microsoft/phi-4",
        name: "Phi 4",
        description: "Compact model with strong math, reasoning, and coding performance.",
        contextLength: 16384,
        architecture: OpenRouterModel.Architecture(modality: "text->text")
    ),
    OpenRouterModel(
        id: "rekaai/reka-flash-3",
        name: "Reka Flash 3",
        description: "Fast model for everyday chat, summarization, and structured output.",
        contextLength: 128000,
        architecture: OpenRouterModel.Architecture(modality: "text->text")
    ),
    OpenRouterModel(
        id: "openrouter/auto",
        name: "OpenRouter Auto",
        description: "Automatically routes prompts to a suitable available model.",
        contextLength: nil,
        architecture: OpenRouterModel.Architecture(modality: "text->text")
    ),
    OpenRouterModel(
        id: "liquid/lfm-40b",
        name: "LFM 40B",
        description: "Efficient foundation model for chat and reasoning with a practical context window.",
        contextLength: 32768,
        architecture: OpenRouterModel.Architecture(modality: "text->text")
    ),
    OpenRouterModel(
        id: "sao10k/l3.1-euryale-70b",
        name: "Euryale 70B",
        description: "Creative writing model tuned for expressive dialogue and roleplay-style prompts.",
        contextLength: 131072,
        architecture: OpenRouterModel.Architecture(modality: "text->text")
    ),
    OpenRouterModel(
        id: "z-ai/glm-4.5-air",
        name: "GLM 4.5 Air",
        description: "Lightweight assistant model for fast text generation and coding support.",
        contextLength: 128000,
        architecture: OpenRouterModel.Architecture(modality: "text->text")
    )
]

#Preview("OpenRouter model search") {
    OpenRouterModelSearchView(
        searchText: .constant("/"),
        models: previewOpenRouterSuggestionModels,
        isLoadingModels: false,
        isModelLoadDisabled: false,
        onLoadModels: {},
        onUseTypedModel: {},
        onCancel: {},
        onSelectModel: { _ in }
    )
}

#Preview("OpenRouter model search2") {
    OpenRouterModelSearchView(
        searchText: .constant(""),
        models: [],
        isLoadingModels: false,
        isModelLoadDisabled: false,
        onLoadModels: {},
        onUseTypedModel: {},
        onCancel: {},
        onSelectModel: { _ in }
    )
}
