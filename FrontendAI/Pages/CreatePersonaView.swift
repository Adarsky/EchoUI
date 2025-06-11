
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
    @State private var description: String = ""
    @State private var avatarSystemName: String = "person.crop.circle"
    @State private var iconColor: Color = .blue
    @State private var avatarData: Data? = nil
    @State private var selectedImageItem: PhotosPickerItem? = nil
    @Environment(PersonaManager.self) var personaManager

    var body: some View {
        VStack(spacing: 20) {
            Text("Create Persona")
                .font(.title2)
                .bold()

            PhotosPicker(selection: $selectedImageItem, matching: .images) {
                if let data = avatarData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } else {
                    Image(systemName: avatarSystemName)
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(iconColor)
                        .padding()
                }
            }
            .onChange(of: selectedImageItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        avatarData = data
                    }
                }
            }

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)

            TextField("System prompt / Description", text: $description, axis: .vertical)
                .textFieldStyle(.roundedBorder)

            Spacer()

            Button("Save Persona") {
                let persona = PersonaModel(
                    name: name,
                    systemPrompt: description,
                    avatarSystemName: avatarSystemName,
                    iconColorName: iconColor.description,
                    avatarData: avatarData
                )
                modelContext.insert(persona)
                try? modelContext.save()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(name.isEmpty || description.isEmpty)
        }
        .padding()
    }
}

