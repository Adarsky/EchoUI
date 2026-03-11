
//
//  CreatePersonaView.swift
//  FrontendAI
//
//  Created by macbook on 29.03.2025.
//

import SwiftUI
import PhotosUI
import SwiftData

struct CreatePersonaView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var prompt: String = ""
    @State private var avatarData: Data? = nil
    @State private var selectedImageItem: PhotosPickerItem? = nil
    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case prompt
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                nameCard
                promptCard
                createButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .navigationTitle("New Persona")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: selectedImageItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    avatarData = data
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(spacing: 14) {
            PhotosPicker(selection: $selectedImageItem, matching: .images, photoLibrary: .shared()) {
                HStack(spacing: 14) {
                    avatarPreview

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Persona avatar")
                            .font(.headline)
                        Text("Choose a profile image or keep the default icon")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "photo.badge.plus")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(cardBackground)
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Name", systemImage: "person.text.rectangle")
                .font(.subheadline.weight(.semibold))

            TextField("e.g. Product Strategist", text: $name)
                .focused($focusedField, equals: .name)
                .submitLabel(.next)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(inputBackground)
                .onSubmit {
                    focusedField = .prompt
                }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var promptCard: some View {
        textEditorCard(
            title: "System prompt",
            icon: "bubble.left.and.exclamationmark.bubble.right",
            placeholder: "Describe tone, behavior and response boundaries...",
            text: $prompt,
            field: .prompt
        )
    }

    private func textEditorCard(
        title: String,
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))

            ZStack(alignment: .topLeading) {
                if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(placeholder)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.top, 14)
                        .padding(.leading, 12)
                }

                TextEditor(text: text)
                    .focused($focusedField, equals: field)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 130)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.clear)
            }
            .background(inputBackground)
        }
        .padding(16)
        .background(cardBackground)
    }

    private var createButton: some View {
        Button(action: savePersona) {
            Text("Create Persona")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.glass)
        .disabled(!canSave)
        .padding(.top, 4)
    }

    private var avatarPreview: some View {
        Group {
            if let data = avatarData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.badge.plus")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.accentColor)
                    .padding(16)
            }
        }
        .frame(width: 84, height: 84)
        .background(Circle().fill(.white.opacity(0.12)))
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(.white.opacity(0.32), lineWidth: 1)
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.22), lineWidth: 0)
            )
    }

    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.white.opacity(0.03))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.15), lineWidth: 0)
            )
    }

    private func savePersona() {
        let persona = PersonaModel(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            systemPrompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines),
            avatarSystemName: "person.crop.circle.fill",
            iconColorName: "blue",
            avatarData: avatarData
        )
        modelContext.insert(persona)
        try? modelContext.save()
        dismiss()
    }
}
