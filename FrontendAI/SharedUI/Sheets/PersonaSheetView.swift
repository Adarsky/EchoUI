import SwiftUI
import SwiftData

struct PersonaSheetView: View {
    @Binding var isPresented: Bool
    var onCreatePersona: () -> Void = { }

    var body: some View {
        NavigationStack {
            PersonasPageView(onCreatePersona: onCreatePersona)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

struct PersonasPageView: View {
    var onCreatePersona: () -> Void = { }

    @Query private var personas: [PersonaModel]

    @Environment(\.modelContext) private var modelContext
    @Environment(PersonaManager.self) var personaManager

    @State private var selectedPersonaForEdit: PersonaModel?
    @State private var personaToDelete: PersonaModel?
    @State private var showDeleteAlert = false

    var body: some View {
        VStack {
            personaList
        }
        .navigationTitle("Your personas")
        .navigationDestination(item: $selectedPersonaForEdit) { persona in
            EditPersonaView(persona: persona)
        }
        .overlay(alignment: .bottomTrailing) {
            createPersonaButton
                .padding(.trailing, 20)
                .padding(.bottom, 24)
        }
        .alert("Delete Persona", isPresented: $showDeleteAlert, presenting: personaToDelete) { persona in
            Button("Delete", role: .destructive) {
                modelContext.delete(persona)
                if personaManager.activePersonaID == persona.id {
                    personaManager.selectPersona(nil)
                }
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) { }
        } message: { persona in
            Text("Are you sure you want to delete \(persona.name)?")
        }
    }

    @ViewBuilder
    private var personaList: some View {
        if personas.isEmpty {
            Text("Tap the plus button to create a new character")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            List {
                Section() {
                    ForEach(personas) { persona in
                        personaRow(for: persona)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func personaRow(for persona: PersonaModel) -> some View {
        let isSelected = personaManager.activePersonaID == persona.id

        return HStack {
            persona.avatarImage
                .resizable()
                .frame(width: 40, height: 40)
                .clipShape(Circle())

            VStack(alignment: .leading) {
                Text(persona.name)
                    .fontWeight(.semibold)
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
        .onTapGesture {
            personaManager.selectPersona(persona)
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

    private var createPersonaButton: some View {
        Button {
            onCreatePersona()
        } label: {
            Image(systemName: "plus")
                .foregroundStyle(Color(.black))
                .font(.title2)
                .fontWeight(.semibold)
                .frame(width: 56, height: 56)
        }
        .glassEffect(.regular.tint(.white.opacity(1.0)).interactive())
        .buttonBorderShape(.circle)
    }
}

private struct PersonaSheetPreviewHost: View {
    @State private var isPresented = true

    var body: some View {
        PersonaSheetView(isPresented: $isPresented)
    }
}

#Preview {
    PersonaSheetPreviewHost()
        .modelContainer(personaSheetPreviewModelContainer)
        .environment(personaSheetPreviewPersonaManager)
}

@MainActor
private let personaSheetPreviewModelContainer: ModelContainer = {
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
    context.insert(
        PersonaModel(
            name: "Code Reviewer",
            systemPrompt: "Reviews code for correctness and style.",
            avatarSystemName: "checkmark.seal.fill",
            iconColorName: "green"
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
    context.insert(
        PersonaModel(
            name: "Code Reviewer",
            systemPrompt: "Reviews code for correctness and style.",
            avatarSystemName: "checkmark.seal.fill",
            iconColorName: "green"
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
    context.insert(
        PersonaModel(
            name: "Code Reviewer",
            systemPrompt: "Reviews code for correctness and style.",
            avatarSystemName: "checkmark.seal.fill",
            iconColorName: "green"
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
    context.insert(
        PersonaModel(
            name: "Code Reviewer",
            systemPrompt: "Reviews code for correctness and style.",
            avatarSystemName: "checkmark.seal.fill",
            iconColorName: "green"
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
private let personaSheetPreviewPersonaManager: PersonaManager = {
    let manager = PersonaManager()
    let descriptor = FetchDescriptor<PersonaModel>(
        sortBy: [SortDescriptor(\.name, order: .forward)]
    )
    let personas = (try? personaSheetPreviewModelContainer.mainContext.fetch(descriptor)) ?? []
    manager.selectPersona(personas.first)
    return manager
}()
