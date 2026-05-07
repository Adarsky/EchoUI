import SwiftUI


struct ExportPage: View {
    @State private var selectedOption: String = "Choose"
    private let options = ["none", "AES-256-GCM", "xchacha20poly1305", "Serpent"]
    

    var body: some View {
        VStack(spacing: 16) {
            List {
                Section(header: Text("Configuration")) {
                    Toggle("Enable Encryption", isOn: .constant(true))
                }
                Section(header: Text("Security")) {
                    Menu {
                        ForEach(options, id: \.self) { option in
                            Button(option) {
                                selectedOption = option
                            }
                        }
                    } label: {
                        Label("Export Options: \(selectedOption)", systemImage: "lock")
                    }
                    TextField("Enter your password", text: .constant(""))
                }
                Section(header: Text("Export")) {
                    Button() {
                    } label: {
                        Label("Export .tar., \(selectedOption) encryption", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

#Preview {
    ExportPage()
}
