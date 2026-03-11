//
//  PersonaDetailView.swift
//  FrontendAI
//
//  Created by macbook on 29.03.2025.
//

import SwiftUI
struct PersonaDetailView: View {
    var persona: PersonaModel

    var body: some View {
        VStack(spacing: 20) {
            persona.avatarImage
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(Circle())

            Text(persona.name)
                .font(.title)

            Text(persona.systemPrompt)
                .font(.body)
                .padding()

            Spacer()
        }
        .padding()
        .navigationTitle("Persona")
    }
}

#Preview {
    NavigationStack {
        PersonaDetailView(
            persona: PersonaModel(
                name: "Product Strategist",
                systemPrompt: "You are a concise product strategist. Ask one clarifying question before offering a structured plan.",
                avatarSystemName: "person.crop.circle.fill",
                iconColorName: "blue"
            )
        )
    }
}
