import SwiftUI

struct ExpandedTextEditorSheet: View {
    @Binding var text: String
    let title: String
    let placeholder: String

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(placeholder)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                }

                TextEditor(text: $text)
                    .focused($isEditorFocused)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }
            .background(Color(.systemBackground))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isEditorFocused = true
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
