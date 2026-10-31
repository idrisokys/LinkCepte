import SwiftUI
import AppKit

struct NoteSheet: View {
    @EnvironmentObject var m: Model

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView {
                Text(m.noteText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 80, idealHeight: 240, maxHeight: 360)
            HStack {
                Button("Kopyala") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(m.noteText, forType: .string)
                    HUD.show("Kopyalandı")
                }
                Spacer()
                Button("Kapat") { m.sheet = nil }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}

struct FolderSheet: View {
    @EnvironmentObject var m: Model
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Yeni klasör").font(.headline)
            TextField("Klasör adı", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { create() }
            HStack {
                Spacer()
                Button("İptal") { m.sheet = nil }
                    .keyboardShortcut(.cancelAction)
                Button("Oluştur") { create() }
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
            Text("Taşı: " + (stack.last?.name ?? "Ana liste")).font(.headline).lineLimit(1)
            List {
                if !stack.isEmpty {
                    line("arrow.left", "Üst klasör") { stack.removeLast() }
                }
                if !creating {
                    line("folder.badge.plus", "Yeni klasör oluştur") { creating = true }
                } else {
                    HStack {
                        TextField("Klasör adı", text: $newName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { createFolder() }
                        Button("Oluştur") { createFolder() }
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
                Button("İptal") { m.sheet = nil; m.moving = [] }
                    .keyboardShortcut(.cancelAction)
                Button("Buraya taşı") { m.performMove(to: dir) }
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
