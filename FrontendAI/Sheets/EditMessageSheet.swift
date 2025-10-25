//
//  EditMessageSheet.swift
//  FrontendAI
//
//  Created by macbook on 12.09.2025.
//

import SwiftUI

struct EditMessageSheet: View {
    @Binding var text: String
    var isUser: Bool
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $text)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding()
                Spacer()
            }
            .navigationTitle("Edit message")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}
