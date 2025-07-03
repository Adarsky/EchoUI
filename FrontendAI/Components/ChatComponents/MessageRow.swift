//
//  MessageRow.swift
//  FrontendAI
//
//  Created by macbook on 30.05.2025.
//

import SwiftUI

struct MessageRow: View {
    // Теперь наблюдаем за класс-моделью
    @ObservedObject var msg: ChatMessageModel

    // Действия, переданные из ChatView
    let regenerate: (ChatMessageModel) -> Void
    let switchVariant: (UUID, Int) -> Void

    // Анимация fade-in по мере прихода чанков
    @State private var lastCount: Int = 0

    var body: some View {
        HStack(alignment: .top) {
            if msg.isUser { Spacer(minLength: 40) }

            VStack(alignment: msg.isUser ? .trailing : .leading) {
                if msg.content.isEmpty && !msg.isUser {
                    TypingIndicator()
                        .padding(12)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    Text(msg.content)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(msg.isUser ? Color.blue.opacity(0.8) : Color.gray.opacity(0.2))
                        )
                        .foregroundColor(msg.isUser ? .white : .primary)
                        .transition(.opacity)
                        .animation(.easeOut(duration: 0.15), value: msg.content)
                        .onChange(of: msg.content) { _ in
                            // Отдельный fade-in, если длиннее предыдущего
                            if msg.content.count > lastCount {
                                lastCount = msg.content.count
                            }
                        }
                }

                // Навигация по вариантам (если их > 1)
                if msg.allVariants.count > 1 {
                    HStack(spacing: 20) {
                        Button { switchVariant(msg.id, -1) } label: {
                            Image(systemName: "chevron.left")
                        }
                        Text("\(msg.currentIndex + 1)/\(msg.allVariants.count)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Button { switchVariant(msg.id, +1) } label: {
                            Image(systemName: "chevron.right")
                        }
                    }
                }

                // Кнопка «Regenerate» только для ассистента
                if !msg.isUser {
                    Button("Regenerate") { regenerate(msg) }
                        .font(.caption)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: msg.isUser ? .trailing : .leading)

            if !msg.isUser { Spacer(minLength: 40) }
        }
        .animation(.linear(duration: 0.1), value: msg.content.count)
    }
}
