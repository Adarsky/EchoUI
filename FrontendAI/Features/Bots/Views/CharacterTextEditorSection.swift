import SwiftUI

struct CharacterTextEditorSection: View {
    let title: String
    let placeholder: String
    let footer: String
    @Binding var text: String
    var focusedField: FocusState<CharacterEditorField?>.Binding
    let field: CharacterEditorField

    @State private var isExpanded = false

    var body: some View {
        Section {
            VStack(alignment: .leading) {
                HStack {
                    Text("About \(TokenUsageEstimator.estimatedTokenCount(for: text).formatted()) tokens")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button(action: expand) {
                        Label("Expand \(title)", systemImage: "arrow.up.left.and.arrow.down.right")
                            .labelStyle(.iconOnly)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.borderless)
                }
                Divider()
                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(4...7)
                    .focused(focusedField, equals: field)
                    .accessibilityLabel(title)
            }
            .sheet(isPresented: $isExpanded) {
                ExpandedTextEditorSheet(text: $text, title: title, placeholder: placeholder)
            }
        } header: {
            Text(title)
        } footer: {
            Text(footer)
        }
    }

    private func expand() {
        focusedField.wrappedValue = nil
        isExpanded = true
    }
}
