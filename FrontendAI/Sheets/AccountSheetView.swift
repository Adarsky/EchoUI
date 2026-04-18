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
                List {
                    Section("Your personas") {
                        ForEach(personas) { persona in
                            let isSelected = personaManager.activePersona?.id == persona.id

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

                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .glassEffect()
                                        .padding(.horizontal, 12)
                                }
                            }
                            .background {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.clear.opacity(1),
                                                    Color.blue.opacity(0.1)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                            }
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

private struct AccountSheetPreviewHost: View {
    @State private var isPresented = true

    var body: some View {
        AccountSheetView(isPresented: $isPresented)
    }
}

#Preview {
    AccountSheetPreviewHost()
        .modelContainer(accountSheetPreviewModelContainer)
        .environment(accountSheetPreviewPersonaManager)
}

@MainActor
private let accountSheetPreviewModelContainer: ModelContainer = {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: PersonaModel.self, configurations: config)
    let context = container.mainContext

    context.insert(
        PersonaModel(
            name: "Default Assistant",
            systemPrompt: "Helpful and concise assistant persona.",
            avatarSystemName: "person.crop.circle.fill",
            iconColorName: "blue"
        )
    )
    context.insert(
        PersonaModel(
            name: "Creative Writer",
            systemPrompt: "Generates creative ideas and rewrites text.",
            avatarSystemName: "sparkles",
            iconColorName: "orange"
        )
    )
    context.insert(
        PersonaModel(
            name: "Code Reviewer",
            systemPrompt: "Reviews code for correctness and style.",
            avatarSystemName: "checkmark.seal.fill",
            iconColorName: "green"
        )
    )
    try? context.save()

    return container
}()

@MainActor
private let accountSheetPreviewPersonaManager: PersonaManager = {
    let manager = PersonaManager()
    let descriptor = FetchDescriptor<PersonaModel>(
        sortBy: [SortDescriptor(\.name, order: .forward)]
    )
    let personas = (try? accountSheetPreviewModelContainer.mainContext.fetch(descriptor)) ?? []
    manager.activePersona = personas.first
    return manager
}()
