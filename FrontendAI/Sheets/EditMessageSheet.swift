//
//  EditMessageSheet.swift
//  FrontendAI
//
//  Created by macbook on 12.09.2025.
//

import SwiftUI

struct EditMessageSheet: View {
    var isUser: Bool
    var onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draftText: String

    init(text: String, isUser: Bool, onSave: @escaping (String) -> Void) {
        self.isUser = isUser
        self.onSave = onSave
        _draftText = State(initialValue: text)
    }

    var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $draftText)
                    .scrollContentBackground(.hidden)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding()
                Spacer()
            }
            .navigationTitle(isUser ? "Edit (you)" : "Edit (bot)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let textToSave = draftText
                        dismiss()
                        Task { @MainActor in
                            onSave(textToSave)
                        }
                    }
                }
            }
        }
    }
}
