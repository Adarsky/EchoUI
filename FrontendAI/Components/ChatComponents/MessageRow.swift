//
//  MessageRow.swift
//  FrontendAI
//
//  Created by macbook on 30.03.2025.
//  Последнее изменение: 04.07.2025 – добавлен .id(msg.currentIndex)
//

import SwiftUI
import UIKit

struct MessageRow: View {
    @ObservedObject var msg: ChatMessageModel

    let regenerate: (ChatMessageModel) -> Void
    let switchVariant: (UUID, Int) -> Void
    let onDelete: (UUID) -> Void

    @State private var isEditing = false
    @State private var editedText = ""
    @State private var showDeleteConfirm = false
    @State private var lastCount: Int = 0

    var body: some View {
        HStack(alignment: .top) {
            if msg.isUser { Spacer(minLength: 40) }

            VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 6) {

                if msg.content.isEmpty && !msg.isUser {
                    TypingIndicator()
                        .padding(12)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    Text(AttributedString(markdownSafe: msg.content))
                        .id(msg.currentIndex)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(msg.isUser ? Color.blue.opacity(0.8)
                                                 : Color.gray.opacity(0.2))
                        )
                        .foregroundColor(msg.isUser ? .white : .primary)
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = msg.content
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }

                            Button {
                                editedText = msg.content
                                isEditing = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .confirmationDialog(
                            "Are you surе?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible
                        ) {
                            Button("Delete", role: .destructive) { onDelete(msg.id) }
                            Button("Cancel", role: .cancel) { }
                        }
                        .onChange(of: msg.content) { _ in
                            if msg.content.count > lastCount {
                                lastCount = msg.content.count
                            }
                        }
                }

                if !msg.isUser {
                    HStack(spacing: 16) {
                        // PREV
                        Button {
                            switchVariant(msg.id, -1)
                        } label: {
                            Image(systemName: "chevron.left.circle")
                                .imageScale(.large)
                        }
                        .disabled(!msg.hasMultipleVariants)

                        // REGENERATE
                        Button {
                            regenerate(msg)
                        } label: {
                            Image(systemName: "arrow.clockwise.circle")
                                .imageScale(.large)
                        }

                        // NEXT
                        Button {
                            switchVariant(msg.id, +1)
                        } label: {
                            Image(systemName: "chevron.right.circle")
                                .imageScale(.large)
                        }
                        .disabled(!msg.hasMultipleVariants)

                        Text("\(msg.currentIndex + 1)/\(max(msg.allVariants.count, 1))")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .frame(minWidth: 44, alignment: .center)
                    }
                    .buttonStyle(.borderless)
                    .labelStyle(.iconOnly)
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity,
                   alignment: msg.isUser ? .trailing : .leading)

            if !msg.isUser { Spacer(minLength: 40) }
        }

        .animation(.easeOut(duration: 0.15), value: msg.currentIndex)
        .sheet(isPresented: $isEditing) {

            if #available(iOS 16.0, *) {
                EditMessageSheet(
                    text: $editedText,
                    isUser: msg.isUser,
                    onSave: {
                        Task { @MainActor in
                            msg.replaceCurrentVariant(with: editedText)
                        }
                    }
                )
                .presentationDetents(Set([.medium, .large]))
            } else {
                // iOS < 16
                LegacyEditMessageSheet(
                    text: $editedText,
                    isUser: msg.isUser,
                    onSave: {
                        Task { @MainActor in
                            msg.replaceCurrentVariant(with: editedText)
                        }
                    }
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityHint(msg.isUser ? "User's message" : "Bot's message")
    }
}

// MARK: - iOS < 16
struct LegacyEditMessageSheet: View {
    @Binding var text: String
    var isUser: Bool
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $text)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding()
                Spacer()
            }
            .navigationBarTitle(isUser ? "Edit (you)" : "Edit (bot)", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") { onSave(); dismiss() }
            )
        }
    }
}

extension AttributedString {
    init(markdownSafe text: String) {
        if let attributed = try? AttributedString(markdown: text) {
            self = attributed
        } else {
            self = AttributedString(text)
        }
    }
}
