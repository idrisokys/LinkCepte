import SwiftUI
import AppKit

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
                    Button { m.toggleEdit() } label: { Image(systemName: m.editMode ? "checkmark" : "pencil") }
                        .help(m.editMode ? L("Düzenlemeyi bitir", "Done editing") : L("Düzenle", "Edit"))
                }
                // Yenile: Link klasörünü tekrar kontrol eder ve listeyi yeniden yükler
                Button { m.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .help(L("Yenile", "Refresh"))
                // En sağda: bilgi (i) ikonu; küçük menü açar
                InfoButton()
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
        ScrollViewReader { proxy in
            List {
                ForEach(m.list) { e in row(e) }
            }
            .listStyle(.inset)
            .onChange(of: m.revealTick) { _ in
                if let k = m.revealKey { proxy.scrollTo(k) }   // taşınan satır görünür kalsın
            }
            .overlay {
                if m.loaded != nil && m.list.isEmpty {
                    Text(L("Burada henüz bir şey yok. Alttaki alana link veya metin yapıştırın, ya da bir linki pencereye sürükleyip bırakın.", "Nothing here yet. Paste a link or text into the box below, or drag a link into the window."))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(32)
                }
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
        .onLongPressGesture(minimumDuration: 0.5) { m.copyEntry(e) }
    }
}
