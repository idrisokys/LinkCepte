import SwiftUI
import AppKit

struct FolderSheet: View {
    @EnvironmentObject var m: Model
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("Yeni klasör", "New folder")).font(.headline)
            TextField(L("Klasör adı", "Folder name"), text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { create() }
            HStack {
                Spacer()
                Button(L("İptal", "Cancel")) { m.sheet = nil }
                    .keyboardShortcut(.cancelAction)
                Button(L("Oluştur", "Create")) { create() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmed.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 340)
        .onAppear { focused = true }
    }

    private func create() {
        let n = name
        if n.trimmed.isEmpty { return }
        m.sheet = nil
        m.createFolder(n)
    }
}
