import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var m: Model

    var body: some View {
        Group {
            if m.root == nil { WelcomeView() } else if m.txt != nil { TxtView() } else { MainView() }
        }
        .frame(minWidth: 420, minHeight: 520)
        .onAppear { m.reload() }
        // Uygulamaya her dönüşte liste kendiliğinden yenilenir.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in m.reload() }
        .onExitCommand { m.goBack() }
    }
}

struct WelcomeView: View {
    @EnvironmentObject var m: Model
    var body: some View {
        VStack(spacing: 14) {
            Text("Link Cepte").font(.largeTitle)
            Text(L("Linklerin kaydedileceği klasörü seçin.", "Choose the folder where your links will be saved."))
            Button(L("Klasör seç", "Choose folder")) { m.chooseFolder() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MainView: View {
    @EnvironmentObject var m: Model

    var body: some View {
        VStack(spacing: 0) {
            if m.searchQuery != nil { SearchResultsView() } else { listView }
            Divider()
            if m.renaming != nil { RenameBar() } else { AddBar() }
        }
        .navigationTitle(m.title)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                if m.searchQuery != nil {
                    Button { m.exitSearch(true) } label: { Image(systemName: "chevron.left") }
                        .help(L("Aramadan çık", "Exit search"))
                } else if !m.stack.isEmpty {
                    Button { m.goBack() } label: { Image(systemName: "chevron.left") }
                        .help(L("Geri", "Back"))
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                if m.searchQuery == nil {
                    if m.editMode && !m.selected.isEmpty {
                        Button { m.beginMove() } label: { Image(systemName: "arrowshape.turn.up.right") }
                            .help(L("Taşı", "Move"))
                        Button { m.deleteSelected() } label: { Image(systemName: "trash") }
                            .help(L("Sil (Çöp Kutusu’na)", "Delete (move to Trash)"))
                    }
                    Button { m.sheet = .folder } label: { Image(systemName: "folder.badge.plus") }
                        .help(L("Yeni klasör", "New folder"))
                    Menu {
                        Button(L("Klasörü değiştir…", "Change folder…")) { m.chooseFolder() }
                    } label: { Image(systemName: "ellipsis.circle") }
                        .menuIndicator(.hidden)
                        .help(L("Menü", "Menu"))
                    Button { m.toggleEdit() } label: { Image(systemName: m.editMode ? "checkmark" : "pencil") }
                        .help(m.editMode ? L("Düzenlemeyi bitir", "Done editing") : L("Düzenle", "Edit"))
                }
                // En sağda: kayıtlı klasörü yeniden tarar
                Button { m.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .help(L("Yenile (⌘R)", "Refresh (⌘R)"))
            }
        }
        .sheet(item: $m.sheet) { s in
            switch s {
            case .folder:
                FolderSheet()
            case .note:
                NoteSheet()
            case .move:
                if let r = m.root, let c = m.current {
                    MoveSheet(root: r, current: c, exclude: Set(m.moving.filter { $0.isDir }.map { $0.key }))
                }
            }
        }
        .onDrop(of: [UTType.url, UTType.plainText], isTargeted: nil) { providers in
            m.handleDrop(providers)
        }
    }

    @ViewBuilder
    private var listView: some View {
        let reorder: ((IndexSet, Int) -> Void)? = m.editMode ? { a, b in m.moveRows(from: a, to: b) } : nil
        List {
            ForEach(m.list) { e in row(e) }
                .onMove(perform: reorder)
        }
        .listStyle(.inset)
        .overlay {
            if m.loaded != nil && m.list.isEmpty {
                Text(L("Burada henüz bir şey yok. Alttaki alana link veya metin yapıştırın, ya da bir linki pencereye sürükleyip bırakın.", "Nothing here yet. Paste a link or text into the box below, or drag a link into the window."))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(32)
            }
        }
    }

    @ViewBuilder
    private func row(_ e: Entry) -> some View {
        let sel = m.selected.contains(e.key)
        HStack(spacing: 10) {
            if m.editMode {
                Image(systemName: sel ? "checkmark.square.fill" : "square")
                    .foregroundStyle(sel ? Color.accentColor : Color.secondary)
                    .frame(width: 22)
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.secondary)
                    .help(L("Sürükleyerek sırala", "Drag to reorder"))
            } else {
                Image(systemName: e.isDir ? "folder" : (e.isTxt ? "doc.text" : "link"))
                    .frame(width: 24)
            }
            Text(e.title).font(.system(size: m.fontSize)).lineLimit(4).truncationMode(.tail)
            Spacer(minLength: 8)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .background(sel ? Color.accentColor.opacity(0.22) : Color.clear)
        .onTapGesture { m.tap(e) }
    }
}

// MARK: - Alt çubuklar

/// Alt çubuktaki yazı boyutu düğmeleri: A küçük / A büyük (⌘− / ⌘+).
struct FontSizeButtons: View {
    @EnvironmentObject var m: Model

    var body: some View {
        HStack(spacing: 6) {
            Button { m.bumpFont(-1) } label: { Image(systemName: "textformat.size.smaller") }
                .disabled(m.fontSize <= Model.minFont)
                .help(L("Yazıyı küçült (⌘−)", "Smaller text (⌘−)"))
            Button { m.bumpFont(1) } label: { Image(systemName: "textformat.size.larger") }
                .disabled(m.fontSize >= Model.maxFont)
                .help(L("Yazıyı büyüt (⌘+)", "Larger text (⌘+)"))
        }
    }
}

struct AddBar: View {
    @EnvironmentObject var m: Model

    var body: some View {
        let canAdd = !m.linkText.trimmed.isEmpty
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $m.linkText)
                    .font(.system(size: m.fontSize))
                    .scrollContentBackground(.hidden)
                    .padding(4)
                if m.linkText.isEmpty {
                    Text(L("Link veya metin yapıştır (+ uzun bas: .txt)", "Paste a link or text (long-press +: .txt)"))
                        .font(.system(size: m.fontSize))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 56, maxHeight: 140)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.35)))

            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.accentColor.opacity(canAdd ? 0.95 : 0.3)))
                    .contentShape(Circle())
                    .help(L("Ekle (uzun basın veya ⌥ ile tıklayın: .txt)", "Add (long-press or ⌥-click: .txt)"))
                    .onTapGesture {
                        guard canAdd else { return }
                        if NSEvent.modifierFlags.contains(.option) { m.addTxt() } else { m.addFromText() }
                    }
                    .onLongPressGesture(minimumDuration: 0.5) {
                        if canAdd { m.addTxt() }
                    }
                Button { m.startSearch() } label: { Image(systemName: "magnifyingglass") }
                    .disabled(!canAdd)
                    .help(L("Ara", "Search"))
                Button { m.paste() } label: { Image(systemName: "doc.on.clipboard") }
                    .help(L("Yapıştır", "Paste"))
                FontSizeButtons()
                Spacer()
                Text("\(m.linkText.count)/\(m.addMax)")
                    .font(.caption)
                    .foregroundStyle(m.linkText.count > m.addMax ? Color.red : Color.secondary)
            }
        }
        .padding(8)
        .background(.bar)
    }
}

struct RenameBar: View {
    @EnvironmentObject var m: Model

    var body: some View {
        VStack(spacing: 6) {
            TextField(m.renaming?.isDir == true ? L("Klasör adı", "Folder name") : L("Ad", "Name"), text: $m.renameText, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: m.fontSize))
                .onSubmit { m.saveRename() }
                .onChange(of: m.renameText) { v in
                    if v.count > m.maxChars { m.renameText = String(v.prefix(m.maxChars)) }
                }
            HStack(spacing: 10) {
                Button { m.pasteIntoRename() } label: { Image(systemName: "doc.on.clipboard") }
                    .help(L("Yapıştır", "Paste"))
                Button { m.saveRename() } label: { Image(systemName: "square.and.arrow.down") }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(m.renameText.trimmed.isEmpty)
                    .help(L("Kaydet (⌘S)", "Save (⌘S)"))
                FontSizeButtons()
                Spacer()
                Text("\(m.renameText.count)/\(m.maxChars)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(.bar)
    }
}

// MARK: - Arama sonuçları

struct SearchResultsView: View {
    @EnvironmentObject var m: Model

    var body: some View {
        if let hits = m.hits {
            if hits.isEmpty {
                Text(L("Sonuç bulunamadı.", "No results found."))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(hits) { h in hitRow(h) }
                    .listStyle(.inset)
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func hitRow(_ h: Hit) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: (h.isNote || h.entry.isTxt) ? "doc.text" : "link")
                .frame(width: 24)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(h.path.isEmpty ? L("Ana liste", "Main list") : h.path.map { $0.name }.joined(separator: " › "))
                    .font(.system(size: max(m.fontSize - 2, 9)))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(h.entry.title).font(.system(size: m.fontSize)).lineLimit(4)
                if !h.detail.isEmpty {
                    Text(h.detail)
                        .font(.system(size: max(m.fontSize - 1, 9)))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            Button {
                m.exitSearch(true)
                m.setStack(h.path)
            } label: { Image(systemName: "folder") }
                .buttonStyle(.borderless)
                .help(L("Klasöre git", "Show in folder"))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { m.open(h.entry) }
    }
}
