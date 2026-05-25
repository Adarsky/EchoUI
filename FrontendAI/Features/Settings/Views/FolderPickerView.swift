//
//  FolderPickerView.swift
//  FrontendAI
//
//  Created by macbook on 21.05.2026.
//

import SwiftUI

struct FolderPickerView: View {
    var body: some View {
        Picker("Folder", selection: .constant("")) {
            Text("All")
            Text("Productivity")
            Text("Coding")
        }
        .pickerStyle(.segmented)
        .padding()
    }
}

#Preview {
    FolderPickerView()
}
