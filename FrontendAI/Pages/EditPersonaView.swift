//
//  EditPersonaView.swift
//  FrontendAI
//
//  Created by macbook on 29.03.2025.
//


import SwiftUI
import SwiftData
import PhotosUI

struct EditPersonaView: View {
    @Bindable var persona: PersonaModel

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext

    @State private var selectedImageItem: PhotosPickerItem? = nil
    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case prompt
    }

    private var canSave: Bool {
        !persona.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !persona.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                nameCard
                promptCard
                saveButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .navigationTitle("Edit Persona")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: selectedImageItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    persona.avatarData = data
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
                        Text("Choose a profile image or keep the current icon")
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

            TextField("e.g. Product Strategist", text: $persona.name)
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
            text: $persona.systemPrompt,
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

    private var saveButton: some View {
        Button(action: savePersona) {
            Text("Save Persona")
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
            if let data = persona.avatarData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: persona.avatarSystemName)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color(persona.iconColorName))
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
        persona.name = persona.name.trimmingCharacters(in: .whitespacesAndNewlines)
        persona.systemPrompt = persona.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        try? modelContext.save()
        dismiss()
    }
}
