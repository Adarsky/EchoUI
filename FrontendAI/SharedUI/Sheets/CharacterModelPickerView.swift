import SwiftUI

struct CharacterModelPickerView: View {
    @Binding var selectedModelOverride: String?

    let defaultModel: String
    let availableModels: [String]

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        List {
            Section("Default") {
                Button(action: useDefaultModel) {
                    modelRow(
                        title: normalizedDefaultModel.isEmpty ? "No server model selected" : normalizedDefaultModel,
                        subtitle: "Follow the selected API server",
                        isSelected: normalizedOverride == nil
                    )
                }
                .buttonStyle(.plain)
            }

            if shouldOfferTypedModel {
                Section("Custom Model ID") {
                    Button(action: useTypedModel) {
                        modelRow(
                            title: normalizedSearchText,
                            subtitle: "Use this exact model ID",
                            isSelected: normalizedOverride == normalizedSearchText
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Available Models") {
                if filteredModels.isEmpty {
                    Text(emptyMessage)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredModels, id: \.self) { model in
                        Button {
                            selectModel(model)
                        } label: {
                            modelRow(
                                title: model,
                                subtitle: model == normalizedDefaultModel ? "API server default" : nil,
                                isSelected: normalizedOverride == model
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Character Model")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search or enter a model ID")
    }

    private var normalizedDefaultModel: String {
        defaultModel.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedOverride: String? {
        guard let selectedModelOverride else { return nil }
        let normalized = selectedModelOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredModels: [String] {
        guard !normalizedSearchText.isEmpty else { return availableModels }
        return availableModels.filter { $0.localizedStandardContains(normalizedSearchText) }
    }

    private var shouldOfferTypedModel: Bool {
        !normalizedSearchText.isEmpty &&
            !availableModels.contains {
                $0.caseInsensitiveCompare(normalizedSearchText) == .orderedSame
            }
    }

    private var emptyMessage: String {
        if availableModels.isEmpty {
            return "No cached model list is available. Enter an exact model ID above."
        }
        return "No matching models. You can use the exact model ID above."
    }

    private func modelRow(
        title: String,
        subtitle: String?,
        isSelected: Bool
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
    }

    private func useDefaultModel() {
        selectedModelOverride = nil
        dismiss()
    }

    private func useTypedModel() {
        selectModel(normalizedSearchText)
    }

    private func selectModel(_ model: String) {
        let normalized = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        selectedModelOverride = normalized
        dismiss()
    }
}

#Preview {
    NavigationStack {
        CharacterModelPickerView(
            selectedModelOverride: .constant(nil),
            defaultModel: "openai/gpt-4o-mini",
            availableModels: [
                "anthropic/claude-sonnet-4",
                "google/gemini-2.5-pro",
                "openai/gpt-4o-mini"
            ]
        )
    }
}
