//
//  ChatMessageModel.swift
//  FrontendAI
//
//  Created by macbook on 30.03.2025.
//

import Foundation
import SwiftUI

/// Observable-модель одного сообщения чата.
/// При изменении `@Published`-свойств
/// перерисовывается только соответствующий `MessageRow`.
final class ChatMessageModel: ObservableObject, Identifiable {
    // MARK: Identifiable
    let id: UUID

    // MARK: Данные
    @Published private(set) var allVariants: [String]
    @Published var currentIndex: Int
    let isUser: Bool

    // MARK: Вычисляемые
    var content: String {
        allVariants[safe: currentIndex] ?? ""
    }

    // MARK: Инициализация
    init(id: UUID = UUID(), content: String, isUser: Bool) {
        self.id = id
        self.allVariants = [content]
        self.currentIndex = 0
        self.isUser = isUser
    }

    // MARK: Мутирующие helpers
    /// Добавить текст к текущему варианту (используется при стриминге).
    func appendChunk(_ chunk: String, to variant: Int) {
        guard allVariants.indices.contains(variant) else { return }
        objectWillChange.send()               // ручной push: меняем элемент массива
        allVariants[variant] += chunk
    }

    /// Создать новый пустой вариант для регенерации.
    func addNewVariant() {
        objectWillChange.send()
        allVariants.append("")
        currentIndex = allVariants.count - 1
    }

    /// Сдвиг между вариантами (−1 или +1).
    func switchVariant(offset: Int) {
        let new = max(0, min(allVariants.count - 1, currentIndex + offset))
        guard new != currentIndex else { return }
        objectWillChange.send()
        currentIndex = new
    }
}

// MARK: – Safe-subscript, доступен всему модулю
extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
