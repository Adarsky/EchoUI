import SwiftUI

struct ChatHistoryDetailView: View {
    let history: ChatHistory

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(history.messages) { msg in
                    if msg.isUser {
                        HStack {
                            Spacer()
                            Text(msg.displayText)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                                .foregroundColor(.white)
                        }
                    } else {
                        HStack {
                            Text(msg.displayText)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(12)
                            Spacer()
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("History")
    }
}
