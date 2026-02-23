//
//  EditMessageSheet.swift
//  FrontendAI
//
//  Created by macbook on 12.09.2025.
//

import SwiftUI

struct EditMessageSheet: View {
    var text: String
    var isUser: Bool
    var onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draftText = ""
    @State private var didSeedDraft = false

    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $draftText)
                    .scrollContentBackground(.hidden)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding()
                Spacer()
            }
            .navigationBarTitle(isUser ? "Edit (you)" : "Edit (bot)", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") {
                    let textToSave = draftText
                    dismiss()
                    Task { @MainActor in
                        onSave(textToSave)
                    }
                }
            )
        }
        .onAppear {
            guard !didSeedDraft else { return }
            draftText = text
            didSeedDraft = true
        }
    }
}
