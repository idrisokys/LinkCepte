import SwiftUI
import AppKit

enum Sheet: Identifiable {
    case folder, move
    var id: Int {
        switch self {
        case .folder: return 0
        case .move: return 1
        }
    }
}

@MainActor
final class Model: ObservableObject {
    static let shared = Model()

    @Published var root: URL? = Store.root
    @Published var stack: [Entry] = []
    @Published var loaded: [Entry]? = nil
    @Published var editMode = false { didSet { syncRename() } }
    @Published var selected: Set<String> = [] { didSet { syncRename() } }
    @Published var linkText = ""
    @Published var searchQuery: String? = nil
    @Published var hits: [Hit]? = nil
    @Published var sheet: Sheet? = nil
    @Published var moving: [Entry] = []
    @Published var renaming: Entry? = nil      // düzenleme modunda tek öğe seçiliyse o öğe (adı altta değiştirilir)
    @Published var renameText = ""
    // Tam pencerede açık .txt dosyası
    @Published var txt: Entry? = nil
    @Published var txtSaved = ""               // dosyadaki son hâl
    @Published var txtDraft = ""               // düzenlenen metin
    @Published var txtEditing = false
    @Published var txtAskDiscard = false
    @Published var txtSaving = false
    var txtDirty: Bool { txtEditing && txtDraft != txtSaved }

    // Yazı boyutu (punto): liste, arama sonuçları, alt alanlar ve .txt görünümü bunu kullanır; kalıcıdır.
    static let minFont = 10.0, maxFont = 32.0, defaultFont = 13.0
    @Published var fontSize: Double = Model.loadFontSize() {
        didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") }
    }
    private static func loadFontSize() -> Double {
        let v = UserDefaults.standard.double(forKey: "fontSize")
        return v == 0 ? defaultFont : min(max(v, minFont), maxFont)
    }
    func bumpFont(_ delta: Double) { fontSize = min(max(fontSize + delta, Model.minFont), Model.maxFont) }

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
        if txt != nil { txtBack() }
        else if searchQuery != nil { exitSearch(false) }
        else if editMode { editMode = false; selected = [] }
        else if !stack.isEmpty { setStack(Array(stack.dropLast())) }
    }

    // MARK: - Metin dosyası (.txt) tam pencere görünümü

    func openTxt(_ e: Entry, _ text: String) {
        txt = e
        txtSaved = text
        txtDraft = text
        txtEditing = false
        txtAskDiscard = false
        txtSaving = false
    }

    func txtStartEdit() {
        guard txt != nil, !txtEditing else { return }
        txtDraft = txtSaved
        txtEditing = true
    }

    /// Kaydeder ve okuma görünümüne döner.
    func txtSave() {
        guard let e = txt, !txtSaving else { return }
        let t = txtDraft
        txtSaving = true
        Task {
            let ok = await self.io { Store.writePlain(e.url, t) }
            self.txtSaving = false
            if ok {
                if self.txt?.key == e.key { self.txtSaved = t; self.txtEditing = false; self.txtAskDiscard = false }
            } else {
                self.toast(L("Kaydedilemedi", "Couldn't save"))
            }
        }
    }

    func txtDiscard() {
        txtDraft = txtSaved
        txtEditing = false
        txtAskDiscard = false
    }

    /// Geri: kaydedilmemiş değişiklik varsa sorar; düzenliyorsa okumaya döner; değilse listeye çıkar.
    func txtBack() {
        if txtDirty { txtAskDiscard = true }
        else if txtEditing { txtEditing = false }
        else { txt = nil }
    }

    // MARK: - Chrome eklentisi

    /// Uygulamanın içindeki Chrome eklentisini sabit bir klasöre kopyalar ve o klasörü Finder'da açar.
    /// (Chrome eklentiyi yüklediği klasörden okur; uygulama taşınsa ya da güncellense de yol bozulmasın diye
    /// kopya `~/Library/Application Support/Link Cepte/chrome-extension` içinde durur.)
    func openChromeExtension() {
        let fm = FileManager.default
        guard let src = Bundle.main.resourceURL?.appendingPathComponent("chrome-extension", isDirectory: true),
              fm.fileExists(atPath: src.appendingPathComponent("manifest.json").path) else {
            toast(L("Chrome eklentisi bu uygulama sürümünde bulunamadı", "The Chrome extension isn't included in this app build"))
            return
        }
        var target = src   // kopyalanamazsa uygulamanın içindeki klasör açılır
        if let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let dst = base.appendingPathComponent("Link Cepte", isDirectory: true)
                .appendingPathComponent("chrome-extension", isDirectory: true)
            if Self.syncFolder(src, to: dst) { target = dst }
        }
        NSWorkspace.shared.open(target)
        toast(L("Chrome eklentisi klasörü açıldı — kurulum için README.md’ye bakın",
                "Chrome extension folder opened — see README.md for setup"))
    }

    /// Klasörü dosya dosya kopyalar; aynı adlı dosyaların üzerine yazar. Hedef klasör silinmez,
    /// böylece Chrome'a daha önce yüklenmiş eklenti güncelleme sırasında bozulmaz.
    private static func syncFolder(_ src: URL, to dst: URL) -> Bool {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: dst, withIntermediateDirectories: true)
            guard let en = fm.enumerator(at: src, includingPropertiesForKeys: [.isDirectoryKey]) else { return false }
            for case let u as URL in en {
                if u.lastPathComponent == ".DS_Store" { continue }
                let rel = u.pathComponents.dropFirst(src.pathComponents.count)
                let out = rel.reduce(dst) { $0.appendingPathComponent($1) }
                let isDir = try u.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false
                if isDir {
                    try fm.createDirectory(at: out, withIntermediateDirectories: true)
                } else {
                    if fm.fileExists(atPath: out.path) { try fm.removeItem(at: out) }
                    try fm.copyItem(at: u, to: out)
                }
            }
            return true
        } catch {
            return false
        }
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
                txt = nil
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
        if txt != nil { txtStartEdit(); return }   // .txt açıkken ⌘E metni düzenler
        editMode.toggle()
        selected = []
    }

    func open(_ e: Entry) {
        Task {
            if e.isTxt {
                let t = await self.io { Store.readPlain(e.url) }
                if let t = t { self.openTxt(e, t) } else { self.toast(L("Dosya okunamadı", "Couldn't read the file")) }
                return
            }
            let (u, t) = await self.io { Store.readLink(e.url) }
            if let u = u {
                if let link = Store.makeURL(u), NSWorkspace.shared.open(link) { return }
                self.toast(L("Link açılamadı", "Couldn't open the link"))
            } else if let t = t {
                self.copyToPasteboard(t)
            } else {
                self.toast(L("Link okunamadı", "Couldn't read the link"))
            }
        }
    }

    private func copyToPasteboard(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
        toast(L("Kopyalandı", "Copied"))
    }

    /// Sağ tık → Kopyala: dosya her seferinde yeniden okunur (ad değişince eski metin kopyalanmaz).
    func copyEntry(_ e: Entry) {
        Task {
            let (u, t) = await self.io { Store.readLink(e.url) }
            if let s = u ?? t { self.copyToPasteboard(s) } else { self.toast(L("Link okunamadı", "Couldn't read the link")) }
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

    /// Düzenleme modunda tam bir öğe seçiliyse adı alttaki alanda değiştirilir.
    private func syncRename() {
        let e: Entry? = (editMode && selected.count == 1) ? list.first(where: { selected.contains($0.key) }) : nil
        if e?.key != renaming?.key {
            renaming = e
            renameText = e?.title ?? ""
        }
    }

    func pasteIntoRename() {
        if let s = NSPasteboard.general.string(forType: .string) { renameText = String(s.prefix(maxChars)) }
    }

    func saveRename() {
        guard let r = renaming, let dir = current else { return }
        let n = renameText
        if n.trimmed.isEmpty { return }
        selected = []   // seçim kalkınca ad alanı da kapanır; düzenleme modu açık kalır
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

    // MARK: - Sıra değiştirme (düzenleme modunda ↑ / ↓ tuşları veya yukarı-aşağı kaydırma)

    /// Son taşınan satır: liste bu satırı görünür tutmak için kaydırılır.
    @Published var revealKey: String? = nil
    @Published var revealTick = 0
    private var eventMonitors: [Any] = []
    private var scrollArmed = true
    private var scrollAccum: CGFloat = 0
    private var lastWheelStep: TimeInterval = 0

    /// İşaretli satır(lar)ı bir adım yukarı (-1) veya aşağı (+1) taşır ve yeni sırayı kaydeder.
    func moveSelected(_ delta: Int) {
        guard editMode, !selected.isEmpty, var l = loaded, l.count > 1, let dir = current else { return }
        var moved = false
        if delta < 0 {
            for i in 1..<l.count where selected.contains(l[i].key) && !selected.contains(l[i - 1].key) {
                l.swapAt(i, i - 1); moved = true
            }
        } else {
            for i in stride(from: l.count - 2, through: 0, by: -1) where selected.contains(l[i].key) && !selected.contains(l[i + 1].key) {
                l.swapAt(i, i + 1); moved = true
            }
        }
        guard moved else { return }
        loaded = l
        revealKey = (delta < 0 ? l.first(where: { selected.contains($0.key) }) : l.last(where: { selected.contains($0.key) }))?.key
        revealTick += 1
        let names = l.map { $0.name }
        Task { await self.io { Store.saveOrder(dir, names) } }
    }

    /// Ok tuşları ve kaydırma olaylarını dinler (bir kez kurulur).
    func installReorderMonitors() {
        guard eventMonitors.isEmpty else { return }
        if let k = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] ev in
            guard let self = self else { return ev }
            return self.handleReorderKey(ev) ? nil : ev
        }) { eventMonitors.append(k) }
        if let s = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel, handler: { [weak self] ev in
            guard let self = self else { return ev }
            return self.handleReorderScroll(ev) ? nil : ev
        }) { eventMonitors.append(s) }
    }

    private var reorderActive: Bool {
        editMode && !selected.isEmpty && txt == nil && sheet == nil && searchQuery == nil && root != nil
    }

    private func handleReorderKey(_ ev: NSEvent) -> Bool {
        guard reorderActive else { return false }
        // Bir metin alanı odaktaysa ok tuşları imleci taşır
        if NSApp.keyWindow?.firstResponder is NSTextView { return false }
        if !ev.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty { return false }
        switch ev.keyCode {
        case 126: moveSelected(-1); return true   // ↑
        case 125: moveSelected(1); return true    // ↓
        default: return false
        }
    }

    /// Parmak/tekerlek yukarı → satır yukarı, aşağı → aşağı. Bir kaydırma hareketi tek adım sayılır;
    /// ⌥ basılıyken veya metin alanının üzerindeyken normal kaydırma çalışır.
    private func handleReorderScroll(_ ev: NSEvent) -> Bool {
        guard reorderActive, !ev.modifierFlags.contains(.option) else { return false }
        if let root = ev.window?.contentView?.superview ?? ev.window?.contentView,
           var v: NSView = root.hitTest(ev.locationInWindow) {
            while true {
                if v is NSTextView { return false }
                guard let p = v.superview else { break }
                v = p
            }
        }
        let dy = ev.scrollingDeltaY
        func step(_ amount: CGFloat) {
            let up = ev.isDirectionInvertedFromDevice ? amount < 0 : amount > 0
            moveSelected(up ? -1 : 1)
        }
        if ev.hasPreciseScrollingDeltas {
            // Dokunmatik yüzey: her yeni harekette bir kez; hareket ve ivmesi bitene kadar liste kaymaz
            if ev.phase == .began || ev.phase == .mayBegin { scrollArmed = true; scrollAccum = 0 }
            if scrollArmed {
                scrollAccum += dy
                if abs(scrollAccum) >= 10 { step(scrollAccum); scrollArmed = false }
            }
        } else if dy != 0 {
            // Fare tekerleği: her tık bir adım
            if ev.timestamp - lastWheelStep > 0.08 { step(dy); lastWheelStep = ev.timestamp }
        }
        return true
    }
}
