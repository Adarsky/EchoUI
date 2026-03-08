
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
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 100)
        }
        .background(backgroundGradient.ignoresSafeArea())
        .navigationTitle("New Persona")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            actionBar
        }
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
            PhotosPicker(selection: $selectedImageItem, matching: .images) {
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
        VStack(alignment: .leading, spacing: 10) {
            Label("System prompt", systemImage: "bubble.left.and.exclamationmark.bubble.right")
                .font(.subheadline.weight(.semibold))

            ZStack(alignment: .topLeading) {
                if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Describe tone, behavior and response boundaries...")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.top, 14)
                        .padding(.leading, 12)
                }

                TextEditor(text: $prompt)
                    .focused($focusedField, equals: .prompt)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 170)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.clear)
            }
            .background(inputBackground)
        }
        .padding(16)
        .background(cardBackground)
    }

    private var actionBar: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(.white.opacity(0.12))

            Button(action: savePersona) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Create Persona")
                        .fontWeight(.semibold)
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(canSave ? 0.95 : 0.45),
                                    Color.blue.opacity(canSave ? 0.85 : 0.35)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 10)
        }
        .background(.ultraThinMaterial)
    }

    private var avatarPreview: some View {
        Group {
            if let data = avatarData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.accentColor)
                    .padding(18)
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
                    .stroke(.white.opacity(0.22), lineWidth: 1)
            )
    }

    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            )
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.16),
                Color.blue.opacity(0.12),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
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
