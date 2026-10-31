import SwiftUI
import AppKit

enum Sheet: Identifiable {
    case folder, move, note
    var id: Int {
        switch self {
        case .folder: return 0
        case .move: return 1
        case .note: return 2
        }
    }
}

@MainActor
final class Model: ObservableObject {
    static let shared = Model()

    @Published var root: URL? = Store.root
    @Published var stack: [Entry] = []
    @Published var loaded: [Entry]? = nil
    @Published var editMode = false
    @Published var selected: Set<String> = []
    @Published var linkText = ""
    @Published var searchQuery: String? = nil
    @Published var hits: [Hit]? = nil
    @Published var sheet: Sheet? = nil
    @Published var noteText = ""
    @Published var moving: [Entry] = []
    @Published var renaming: Entry? = nil
    @Published var renameText = ""

    let maxChars = 220   // ad değiştirme sınırı
    let addMax = 220     // alttaki ekleme alanı sınırı

    /// Tüm dosya işlemleri sıralı yapılır.
    private let queue = DispatchQueue(label: "linkcepte.io")
    private var searchFlag: CancelFlag?

    var current: URL? { stack.last?.url ?? root }
    var list: [Entry] { loaded ?? [] }

    var title: String {
        if let q = searchQuery { return "“\(q)”" + (hits.map { " · \($0.count) \(L("sonuç", "results"))" } ?? "") }
        if editMode && !selected.isEmpty { return "\(selected.count) \(L("seçili", "selected"))" }
        return stack.last?.name ?? "Link Cepte"
    }

    func io<T>(_ block: @escaping () -> T) async -> T {
        await withCheckedContinuation { c in
            queue.async { c.resume(returning: block()) }
        }
    }

    func toast(_ s: String) { HUD.show(s) }

    // MARK: - Gezinme

    func reload(then: (() -> Void)? = nil) {
        guard let dir = current else { loaded = nil; return }
        Task {
            let r = await self.io { Store.list(dir) }
            if self.current == dir { self.loaded = r }
            then?()
        }
    }

    /// Yenile düğmesi: kayıtlı klasörü yeniden tarar (arama açıksa aramayı yeniden çalıştırır).
    func refresh() {
        root = Store.root
        guard root != nil else { return }
        // Klasör dışarıdan silinmiş veya taşınmışsa gezinme yolunu geçerli son klasöre indir
        let fm = FileManager.default
        var valid = [Entry]()
        for e in stack {
            var d: ObjCBool = false
            if fm.fileExists(atPath: e.url.path, isDirectory: &d), d.boolValue { valid.append(e) } else { break }
        }
        if valid.count != stack.count { stack = valid; selected = [] }
        if let q = searchQuery { runSearch(q); return }
        reload { HUD.show(L("Yenilendi", "Refreshed")) }
    }

    func setStack(_ s: [Entry]) {
        stack = s
        selected = []
        loaded = nil
        reload()
    }

    func goBack() {
        if renaming != nil { renaming = nil }
        else if searchQuery != nil { exitSearch(false) }
        else if editMode { editMode = false; selected = [] }
        else if !stack.isEmpty { setStack(Array(stack.dropLast())) }
    }

    func chooseFolder() {
        let p = NSOpenPanel()
        p.canChooseDirectories = true
        p.canChooseFiles = false
        p.canCreateDirectories = true
        p.allowsMultipleSelection = false
        p.prompt = L("Seç", "Choose")
        p.message = L("Linklerin kaydedileceği klasörü seçin.", "Choose the folder where your links will be saved.")
        if p.runModal() == .OK, let u = p.url {
            if Store.setRoot(u) {
                root = Store.root
                setStack([])
            } else {
                toast(L("Bu klasöre yazılamıyor, başka bir klasör seçin", "Can't write to this folder, choose another one"))
            }
        }
    }

    // MARK: - Satır işlemleri

    func tap(_ e: Entry) {
        if editMode { toggle(e.key) }
        else if e.isDir { setStack(stack + [e]) }
        else { open(e) }
    }

    func toggle(_ key: String) {
        if selected.contains(key) { selected.remove(key) } else { selected.insert(key) }
    }

    func toggleEdit() {
        editMode.toggle()
        selected = []
    }

    func open(_ e: Entry) {
        Task {
            if e.isTxt {
                let t = await self.io { Store.readPlain(e.url) }
                if let t = t { self.noteText = t; self.sheet = .note } else { self.toast(L("Dosya okunamadı", "Couldn't read the file")) }
                return
            }
            let (u, t) = await self.io { Store.readLink(e.url) }
            if let u = u {
                if let link = Store.makeURL(u), NSWorkspace.shared.open(link) { return }
                self.toast(L("Link açılamadı", "Couldn't open the link"))
            } else if let t = t {
                self.noteText = t
                self.sheet = .note
            } else {
                self.toast(L("Link okunamadı", "Couldn't read the link"))
            }
        }
    }

    // MARK: - Ekleme

    func addTxt() {
        let text = linkText.trimmed
        guard !text.isEmpty, let dir = current else { return }
        linkText = ""
        Task {
            let ok = await self.io { Store.addTextFile(dir, text: text) }
            self.reload()
            self.toast(ok ? L("Metin dosyası eklendi", "Text file added") : L("Eklenemedi", "Couldn't add"))
        }
    }

    func addFromText() {
        let text = linkText.trimmed
        guard !text.isEmpty, let dir = current else { return }
        if text.count > addMax {
            toast(L("\(addMax) karakteri aşıyor. + simgesine uzun basarak (veya ⌥ ile tıklayarak) .txt olarak kaydedin",
                  "Exceeds \(addMax) characters. Long-press + (or ⌥-click) to save it as a .txt file"))
            return
        }
        linkText = ""
        addExternal(text, into: dir, okMessage: L("Eklendi", "Added"))
    }

    /// Sürükle-bırak ve Servisler menüsünden gelen metin/link.
    func addExternal(_ text: String, into dir: URL, okMessage: String) {
        Task {
            let ok = await Store.addFromText(dir, text, nil)
            self.reload()
            self.toast(ok ? okMessage : L("Kaydedilemedi", "Couldn't save"))
        }
    }

    /// Servisler menüsü: ana listeye ekler (Android'deki Paylaş → Link Cepte karşılığı).
    func shareAdd(_ text: String) {
        if text.trimmed.isEmpty { toast(L("Paylaşılacak bir şey bulunamadı", "Nothing to share")); return }
        guard let r = root else { toast(L("Önce Link Cepte’yi açıp klasör seçin", "Open Link Cepte and choose a folder first")); return }
        addExternal(text, into: r, okMessage: L("Kaydedildi", "Saved"))
    }

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let dir = current else { return false }
        for p in providers {
            if p.canLoadObject(ofClass: URL.self) {
                _ = p.loadObject(ofClass: URL.self) { url, _ in
                    guard let url = url, !url.isFileURL else { return }
                    Task { @MainActor in self.addExternal(url.absoluteString, into: dir, okMessage: L("Eklendi", "Added")) }
                }
                return true
            }
            if p.canLoadObject(ofClass: String.self) {
                _ = p.loadObject(ofClass: String.self) { s, _ in
                    guard let s = s, !s.trimmed.isEmpty else { return }
                    Task { @MainActor in self.addExternal(s, into: dir, okMessage: L("Eklendi", "Added")) }
                }
                return true
            }
        }
        return false
    }

    func paste() {
        if let s = NSPasteboard.general.string(forType: .string) { linkText = s }
    }

    // MARK: - Arama

    func startSearch() {
        let q = linkText.trimmed
        guard !q.isEmpty else { return }
        NSApp.keyWindow?.makeFirstResponder(nil)
        editMode = false
        selected = []
        runSearch(q)
    }

    func runSearch(_ q: String) {
        guard let rootURL = root else { return }
        searchFlag?.cancel()
        let flag = CancelFlag()
        searchFlag = flag
        searchQuery = q
        hits = nil
        Task.detached {
            let r = Store.search(root: rootURL, query: q, alive: { !flag.isCancelled })
            await MainActor.run {
                if !flag.isCancelled { Model.shared.hits = r }
            }
        }
    }

    func exitSearch(_ clearText: Bool) {
        searchFlag?.cancel()
        if clearText && linkText.trimmed == searchQuery { linkText = "" }
        searchQuery = nil
        hits = nil
    }

    // MARK: - Düzenleme

    func deleteSelected() {
        let items = list.filter { selected.contains($0.key) }
        selected = []
        Task {
            await self.io { for it in items { Store.delete(it.url) } }
            self.reload()
        }
    }

    func startRename(_ e: Entry) {
        renameText = e.title
        renaming = e
    }

    func saveRename() {
        guard let r = renaming, let dir = current else { return }
        let n = renameText
        if n.trimmed.isEmpty { return }
        renaming = nil
        Task {
            let ok = await self.io { Store.rename(dir, r, n) }
            self.reload()
            if !ok { self.toast(L("Ad değiştirilemedi (aynı adda öğe olabilir)", "Couldn't rename (an item with that name may exist)")) }
        }
    }

    func createFolder(_ name: String) {
        guard let dir = current else { return }
        Task {
            _ = await self.io { Store.addFolder(dir, name) }
            self.reload()
        }
    }

    func beginMove() {
        moving = list.filter { selected.contains($0.key) }
        sheet = .move
    }

    func performMove(to target: URL) {
        let files = moving
        sheet = nil
        moving = []
        selected = []
        Task {
            let ok = await self.io { files.filter { Store.moveEntry($0, to: target) }.count }
            self.reload()
            self.toast(ok == files.count
                  ? L("\(ok) öğe taşındı", "\(ok) item(s) moved")
                  : L("\(ok)/\(files.count) öğe taşınabildi", "\(ok)/\(files.count) item(s) could be moved"))
        }
    }

    /// Sürükle-bırak: yalnızca sıralama.
    func moveRows(from: IndexSet, to: Int) {
        guard var l = loaded, let dir = current else { return }
        l.move(fromOffsets: from, toOffset: to)
        loaded = l
        let names = l.map { $0.name }
        Task { await self.io { Store.saveOrder(dir, names) } }
    }
}
