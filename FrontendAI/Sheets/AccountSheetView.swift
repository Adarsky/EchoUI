//
//  AccountSheetView.swift
//  FrontendAI
//
//  Created by macbook on 27.03.2025.
//


import SwiftUI
import SwiftData

struct AccountSheetView: View {
    @Binding var isPresented: Bool
    @Query private var personas: [PersonaModel]

    @Environment(\.modelContext) private var modelContext
    @Environment(PersonaManager.self) var personaManager

    @State private var selectedPersonaForEdit: PersonaModel?
    @State private var personaToDelete: PersonaModel?
    @State private var showDeleteAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HStack {
                    Text("Account Settings")
                        .font(.title3)
                        .bold()
                    Spacer()
                    Button("Close") {
                        isPresented = false
                    }
                }

                List {
                    Section("Personas") {
                        ForEach(personas) { persona in
                            HStack {
                                persona.avatarImage
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())

                                VStack(alignment: .leading) {
                                    Text(persona.name)
                                    Text(persona.systemPrompt)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if personaManager.activePersona?.id == persona.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                personaManager.activePersona = persona
                            }
                            .swipeActions(edge: .trailing) {
                                Button {
                                    selectedPersonaForEdit = persona
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.orange)

                                Button(role: .destructive) {
                                    personaToDelete = persona
                                    showDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }

                        NavigationLink("Create New Persona") {
                            CreatePersonaView()
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .padding()
            .navigationTitle("Account")
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .navigationDestination(item: $selectedPersonaForEdit) { persona in
                EditPersonaView(persona: persona)
            }
            .alert("Delete Persona", isPresented: $showDeleteAlert, presenting: personaToDelete) { persona in
                Button("Delete", role: .destructive) {
                    modelContext.delete(persona)
                    if personaManager.activePersona?.id == persona.id {
                        personaManager.activePersona = nil
                    }
                    try? modelContext.save()
                }
                Button("Cancel", role: .cancel) { }
            } message: { persona in
                Text("Are you sure you want to delete \(persona.name)?")
            }
        }
    }
}
