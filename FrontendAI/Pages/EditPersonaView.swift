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

    @State private var selectedImage: PhotosPickerItem? = nil

    var body: some View {
        Form {
            Section("Name") {
                TextField("Name", text: $persona.name)
            }

            Section("System Prompt") {
                TextField("Prompt", text: $persona.systemPrompt, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("Icon & Color") {
                ColorPicker("Color", selection: Binding(
                    get: { Color(persona.iconColorName) },
                    set: { persona.iconColorName = $0.description }
                ))

                TextField("System Icon", text: $persona.avatarSystemName)
            }

            Section("Avatar") {
                PhotosPicker(selection: $selectedImage, matching: .images) {
                    Text("Choose Photo")
                }
                .onChange(of: selectedImage) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            persona.avatarData = data
                        }
                    }
                }

                if let data = persona.avatarData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .padding(.top, 10)
                } else {
                    Image(systemName: persona.avatarSystemName)
                        .resizable()
                        .frame(width: 100, height: 100)
                        .foregroundColor(Color(persona.iconColorName))
                        .clipShape(Circle())
                        .padding(.top, 10)
                }
            }
        }
        .navigationTitle("Edit Persona")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    try? modelContext.save()
                    dismiss()
                }
            }
        }
    }
}
