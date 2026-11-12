import SwiftUI
import AppKit

struct MoveSheet: View {
    @EnvironmentObject var m: Model
    let root: URL
    let current: URL
    let exclude: Set<String>   // klasör kendi içine taşınamaz

    @State private var stack: [Entry] = []
    @State private var folders: [Entry] = []
    @State private var creating = false
    @State private var newName = ""

    private var dir: URL { stack.last?.url ?? root }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Taşı: ", "Move to: ") + (stack.last?.name ?? L("Ana liste", "Main list"))).font(.headline).lineLimit(1)
            List {
                if !stack.isEmpty {
                    line("arrow.left", L("Üst klasör", "Parent folder")) { stack.removeLast() }
                }
                if !creating {
                    line("folder.badge.plus", L("Yeni klasör oluştur", "Create new folder")) { creating = true }
                } else {
                    HStack {
                        TextField(L("Klasör adı", "Folder name"), text: $newName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { createFolder() }
                        Button(L("Oluştur", "Create")) { createFolder() }
                            .disabled(newName.trimmed.isEmpty)
                    }
                }
                ForEach(folders) { f in
                    line("folder", f.name) { stack.append(f) }
                }
            }
            .listStyle(.inset)
            .frame(height: 300)
            HStack {
                Spacer()
                Button(L("İptal", "Cancel")) { m.sheet = nil; m.moving = [] }
                    .keyboardShortcut(.cancelAction)
                Button(L("Buraya taşı", "Move here")) { m.performMove(to: dir) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(dir.path == current.path)
            }
        }
        .padding(20)
        .frame(width: 420)
        .task(id: dir) { await loadFolders() }
    }

    @ViewBuilder
    private func line(_ icon: String, _ text: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).frame(width: 22)
            Text(text).lineLimit(1)
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }

    private func loadFolders() async {
        let d = dir
        let ex = exclude
        let r = await Task.detached { Store.list(d).filter { $0.isDir && !ex.contains($0.key) } }.value
        folders = r
    }

    private func createFolder() {
        let n = newName
        let d = dir
        if n.trimmed.isEmpty { return }
        creating = false
        newName = ""
        Task {
            let created = await Task.detached { Store.addFolder(d, n) }.value
            await loadFolders()
            if let u = created {
                stack.append(Entry(name: u.lastPathComponent, url: u, isDir: true))
            }
        }
    }
}
