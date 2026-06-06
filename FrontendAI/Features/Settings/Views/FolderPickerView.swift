import SwiftUI
#if os(iOS)
import UIKit
#endif

struct FolderPickerView: View {
    let folders: [ChatFolder]
    @Binding var selectedFolderID: String
    var showsCounts = false
    var countForFolder: (ChatFolder?) -> Int = { _ in 0 }
    var canSelectFolder: (String) async -> Bool = { _ in true }
    var onSelectionDirectionChange: (Int) -> Void = { _ in }

    private var sortedFolders: [ChatFolder] {
        folders.sorted {
            if $0.sortIndex == $1.sortIndex {
                return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            return $0.sortIndex < $1.sortIndex
        }
    }

    private var orderedFolderIDs: [String] {
        [ChatFolder.allFolderID] + sortedFolders.map { $0.id.uuidString }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                folderButton(
                    title: "All",
                    symbolName: "tray.full",
                    count: showsCounts ? countForFolder(nil) : nil,
                    isSelected: selectedFolderID == ChatFolder.allFolderID
                ) {
                    selectFolder(ChatFolder.allFolderID)
                }

                ForEach(sortedFolders) { folder in
                    folderButton(
                        title: folder.displayName,
                        symbolName: folder.symbolName,
                        count: showsCounts ? countForFolder(folder) : nil,
                        isSelected: selectedFolderID == folder.id.uuidString
                    ) {
                        selectFolder(folder.id.uuidString)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func folderButton(
        title: String,
        symbolName: String,
        count: Int?,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbolName)
                    .imageScale(.small)

                if isSelected {
                    Text(title)
                        .lineLimit(1)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))

                    if let count {
                        Text(count.formatted())
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.white.opacity(0.18), in: Capsule())
                            .transition(.scale(scale: 0.72, anchor: .leading).combined(with: .opacity))
                    }
                }
            }
            .font(.subheadline.weight(isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, isSelected ? 12 : 10)
            .frame(height: 34)
            .background {
                Capsule()
                    .fill(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
            }
            .clipShape(Capsule())
            .animation(.snappy(duration: 0.24), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func selectFolder(_ folderID: String) {
        guard selectedFolderID != folderID else { return }
        let direction = selectionDirection(from: selectedFolderID, to: folderID)

        Task {
            guard await canSelectFolder(folderID) else { return }

            await MainActor.run {
                onSelectionDirectionChange(direction)
                withAnimation(.snappy(duration: 0.22)) {
                    selectedFolderID = folderID
                }
                #if os(iOS)
                UISelectionFeedbackGenerator().selectionChanged()
                #endif
            }
        }
    }

    private func selectionDirection(from currentFolderID: String, to nextFolderID: String) -> Int {
        let currentIndex = orderedFolderIDs.firstIndex(of: currentFolderID) ?? 0
        let nextIndex = orderedFolderIDs.firstIndex(of: nextFolderID) ?? currentIndex
        return nextIndex >= currentIndex ? 1 : -1
    }
}

#Preview {
    FolderPickerPreviewHost()
}

private struct FolderPickerPreviewHost: View {
    private static let previewFolders = [
        ChatFolder(name: "Work", symbolName: "briefcase", sortIndex: 0),
        ChatFolder(name: "Creative", symbolName: "paintpalette", sortIndex: 1),
        ChatFolder(name: "Research", symbolName: "magnifyingglass", sortIndex: 2),
        ChatFolder(name: "Long-Term Planning", symbolName: "calendar", sortIndex: 3)
    ]

    @State private var selectedFolderID = previewFolders[1].id.uuidString

    var body: some View {
        FolderPickerView(
            folders: Self.previewFolders,
            selectedFolderID: $selectedFolderID,
            showsCounts: true,
            countForFolder: { folder in
                guard let folder else { return 12 }
                return folder.sortIndex + 2
            }
        )
    }
}
