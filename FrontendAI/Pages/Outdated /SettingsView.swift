import SwiftUI

struct SettingsView: View {
    @State private var valueTemp: Double = 0.7  // Температура
    @State private var userInput: String = "" // System prompt
    @State private var Endpoint: String = ""
    
    @State private var isLengthEnabled: Bool = false
    @State private var responseLength: Int = 256
    @State private var sliderValue: Double = 256
    
    // Форматтер для TextField
    let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimum = 1
        formatter.maximum = 2048
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            VStack(alignment: .leading, spacing: 20) {
                Text("Model settings")
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .font(.headline)
                    .fontWeight(.bold)
                
            }
            Spacer()
            // Температура
            VStack(alignment: .leading) {
                Text("Temperature: \(valueTemp, specifier: "%.2f")")
                    .font(.headline)
                
                Slider(
                    value: $valueTemp,
                    in: 0...1,
                    step: 0.01
                )
            }
            
            // System prompt
            VStack(alignment: .leading) {
                Text("System prompt:")
                    .font(.headline)
                
                ZStack(alignment: .topLeading) {
                    if userInput.isEmpty {
                        Text("Example: You're a helpful assistant")
                            .foregroundColor(.gray)
                            .padding(8)
                    }
                    
                    TextEditor(text: $userInput)
                        .frame(height: 120)
                        .padding(4)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                }
            }
            
            // Toggle + синхронизированные Slider + TextField
            VStack(alignment: .leading) {
                Toggle("Response length limit", isOn: $isLengthEnabled)
                    .font(.headline)
                
                if isLengthEnabled {
                    Text("Length: \(responseLength)")
                    
                    Slider(
                        value: $sliderValue,
                        in: 1...2048,
                        step: 1
                    )
                    .onChange(of: sliderValue) {_, newValue in
                        responseLength = Int(newValue)
                    }
                    
                    TextField("1 is minimal", value: $responseLength, formatter: numberFormatter)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.trailing)
                        .onChange(of: responseLength) {_, newValue in
                            sliderValue = Double(newValue)
                        }
                }
                
            }
            VStack(alignment: .leading) {
                VStack(alignment: .leading) {
                    Text("Write your endpoint URI here:")
                        .font(.headline)
                }
                TextField("Something like 192.168.0.1:5000 or else", text: $Endpoint)
            }
            Spacer()

            VStack {
                Button(action: {
                    UserDefaults.standard.set(self.userInput, forKey: "userInput")
                    UserDefaults.standard.set(self.responseLength, forKey: "responseLength")
                }) {
                    Text("Save settings")
                        .font(.headline)
                }
            }
            .padding()
            .navigationTitle("Настройки")
        }
    }
}
struct SettingsView_pre: PreviewProvider{
    static var previews: some View {
        SettingsView()
    }
}
