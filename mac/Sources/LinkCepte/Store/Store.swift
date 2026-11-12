import Foundation

/// Disk işlemleri: ~/Link altındaki klasör/.url/.txt dosyalarını okur ve yazar.
/// Tüm yazma işlemleri `lock` ile sıralanır. Ad temizleme, okuma, arama ve sayfa başlığı
/// ayrı dosyalarda (Store+*.swift, PageTitle.swift) durur.
enum Store {
    private static let ORDER = ".order.txt"
    private static let lock = NSRecursiveLock()

    // MARK: - Kök klasör

    /// Varsayılan veri klasörü: <ana dizin>/Link.
    static var defaultRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Link", isDirectory: true)
    }

    private static func usable(_ p: String) -> Bool {
        var isDir: ObjCBool = false
        let fm = FileManager.default
        return fm.fileExists(atPath: p, isDirectory: &isDir) && isDir.boolValue && fm.isWritableFile(atPath: p)
    }

    /// Kök klasör: her zaman ~/Link (gerekirse oluşturulur). Oluşturulamaz ya da yazılamazsa nil.
    static var root: URL? {
        let d = defaultRoot
        if !usable(d.path) {
            try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
            if !usable(d.path) { return nil }
        }
        return d
    }

    // MARK: - Listeleme ve sıra

    private static func children(_ dir: URL) -> [Entry] {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: dir.path) else { return [] }
        return names.map { n in
            let u = dir.appendingPathComponent(n)
            var d: ObjCBool = false
            fm.fileExists(atPath: u.path, isDirectory: &d)
            return Entry(name: n, url: u, isDir: d.boolValue)
        }
    }

    private static func readOrder(_ all: [Entry]) -> [String] {
        guard let f = all.first(where: { $0.name == ORDER }),
              let data = try? Data(contentsOf: f.url) else { return [] }
        return String(decoding: data, as: UTF8.self)
            .components(separatedBy: .newlines)
            .filter { !$0.trimmed.isEmpty }
    }

    private static func ordered(_ all: [Entry]) -> [Entry] {
        let files = all.filter {
            let l = $0.name.lowercased()
            return !$0.name.hasPrefix(".") && ($0.isDir || l.hasSuffix(".url") || l.hasSuffix(".txt"))
        }
        var byName = [String: Entry]()
        for f in files { byName[f.name.precomposedStringWithCanonicalMapping] = f }
        var seen = Set<String>()
        var ord = [Entry]()
        for n in readOrder(all) {
            let k = n.precomposedStringWithCanonicalMapping
            if !seen.contains(k), let e = byName[k] { ord.append(e); seen.insert(k) }
        }
        let rest = files
            .filter { !seen.contains($0.name.precomposedStringWithCanonicalMapping) }
            .sorted { a, b in
                if a.isDir != b.isDir { return a.isDir }
                return a.name.lowercased() < b.name.lowercased()
            }
        return ord + rest
    }

    static func list(_ dir: URL) -> [Entry] {
        lock.lock(); defer { lock.unlock() }
        return ordered(children(dir))
    }

    private static func saveOrderIn(_ dir: URL, _ names: [String]) {
        let data = Data(names.joined(separator: "\n").utf8)
        try? data.write(to: dir.appendingPathComponent(ORDER), options: .atomic)   // yarım yazılmış sıra dosyası kalmasın
    }

    static func saveOrder(_ dir: URL, _ names: [String]) {
        lock.lock(); defer { lock.unlock() }
        saveOrderIn(dir, names)
    }

    // MARK: - Yazma

    private static func write(_ dir: URL, _ base: String, _ data: Data, limitChars: Int = 220, ext: String = ".url") -> Bool {
        lock.lock(); defer { lock.unlock() }
        let all = children(dir)
        let taken = Set(all.map { norm($0.name) })
        let b = clean(base, limitChars)
        var name = b + ext
        var i = 2
        while taken.contains(norm(name)) { name = "\(b) (\(i))\(ext)"; i += 1 }
        do { try data.write(to: dir.appendingPathComponent(name), options: .atomic) } catch { return false }
        // Yeni öğe listenin sonuna eklenir; mevcut sıra korunur.
        saveOrderIn(dir, ordered(all).map { $0.name } + [name])
        return true
    }

    static func addLink(_ dir: URL, title: String, url: String) -> Bool {
        write(dir, title, Data("[InternetShortcut]\r\nURL=\(url)\r\n".utf8))
    }

    /// Düz metni de kaydeder (URL olmayan kayıt).
    static func addNote(_ dir: URL, text: String) -> Bool {
        var title = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmed
        if title.isEmpty { title = "not" }
        let enc = text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "\\n")
        return write(dir, title, Data("[InternetShortcut]\r\nTEXT=\(enc)\r\n".utf8))
    }

    /// Metni, uzunluk sınırı olmadan düz .txt dosyası olarak kaydeder; ad metnin ilk 100 karakteridir.
    static func addTextFile(_ dir: URL, text: String) -> Bool {
        var title = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmed
        if title.isEmpty { title = "not" }
        return write(dir, title, Data(text.utf8), limitChars: 100, ext: ".txt")
    }

    static func readPlain(_ url: URL) -> String? {
        guard let d = try? Data(contentsOf: url) else { return nil }
        var s = String(decoding: d, as: UTF8.self)
        if s.hasPrefix("\u{FEFF}") { s.removeFirst() }
        return s
    }

    /// Mevcut .txt dosyasının içeriğini baştan yazar (dosya adı değişmez).
    static func writePlain(_ url: URL, _ text: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        do { try Data(text.utf8).write(to: url, options: .atomic); return true } catch { return false }
    }

    /// Metindeki ilk linki bulur; sondaki noktalama işaretlerini atar.
    static func extractUrl(_ text: String) -> String? {
        guard let r = text.range(of: "https?://\\S+", options: [.regularExpression, .caseInsensitive]) else { return nil }
        var u = String(text[r])
        while let last = u.last {
            let strip = ".,;:!?\"'>]}".contains(last) || (last == ")" && !u.contains("("))
            if strip { u.removeLast() } else { break }
        }
        return u.count > 8 ? u : nil
    }

    /// Link veya metni uygun şekilde kaydeder. Ağ erişimi yaptığı için arka planda çağrılmalı.
    static func addFromText(_ dir: URL, _ text: String, _ subject: String? = nil) async -> Bool {
        let t = text.trimmed
        if t.isEmpty { return false }
        guard let url = extractUrl(t) else { return addNote(dir, text: t) }
        var title: String? = await PageTitle.fetch(url)
        if title == nil {
            title = subject?.components(separatedBy: .newlines).first(where: { !$0.trimmed.isEmpty })?.trimmed
        }
        if title == nil {
            title = t.replacingOccurrences(of: url, with: "")
                .components(separatedBy: .newlines).first(where: { !$0.trimmed.isEmpty })?.trimmed
        }
        if title == nil { title = makeURL(url)?.host }
        return addLink(dir, title: title ?? "link", url: url)
    }

    // MARK: - Taşı / yeniden adlandır / sil

    static func moveEntry(_ e: Entry, to target: URL) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if e.isDir && (target.path == e.url.path || target.path.hasPrefix(e.url.path + "/")) { return false }
        let all = children(target)
        let taken = Set(all.map { norm($0.name) })
        let base = e.isDir ? e.name : e.title
        let ext = e.isDir ? "" : e.ext
        var name = base + ext
        var i = 2
        while taken.contains(norm(name)) { name = "\(base) (\(i))\(ext)"; i += 1 }
        do { try FileManager.default.moveItem(at: e.url, to: target.appendingPathComponent(name)) } catch { return false }
        saveOrderIn(target, ordered(all).map { $0.name } + [name])
        return true
    }

    @discardableResult
    static func addFolder(_ dir: URL, _ name: String) -> URL? {
        lock.lock(); defer { lock.unlock() }
        let all = children(dir)
        let base = clean(name)
        var n = base
        var i = 2
        while all.contains(where: { norm($0.name) == norm(n) }) { n = "\(base) (\(i))"; i += 1 }
        let u = dir.appendingPathComponent(n, isDirectory: true)
        do { try FileManager.default.createDirectory(at: u, withIntermediateDirectories: false) } catch { return nil }
        return u
    }

    /// Link (.url/.txt) veya klasör adını değiştirir; sıralamayı korur.
    static func rename(_ dir: URL, _ e: Entry, _ title: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let base = clean(title, 220)
        let newName = e.isDir ? base : base + e.ext
        if newName == e.name { return true }
        let all = children(dir)
        if all.contains(where: { norm($0.name) == norm(newName) && $0.url != e.url }) { return false }
        let order = ordered(all).map { $0.name }
        let dest = dir.appendingPathComponent(newName)
        let fm = FileManager.default
        do {
            if norm(newName) == norm(e.name) {
                // Yalnızca büyük/küçük harf değişiyor: büyük/küçük harfe duyarsız disklerde geçici ad gerekir.
                let tmp = dir.appendingPathComponent(".tmp-" + UUID().uuidString)
                try fm.moveItem(at: e.url, to: tmp)
                try fm.moveItem(at: tmp, to: dest)
            } else {
                try fm.moveItem(at: e.url, to: dest)
            }
        } catch { return false }
        saveOrderIn(dir, order.map { $0 == e.name ? newName : $0 })
        return true
    }

    /// Silinen öğe Çöp Kutusu'na gider (geri alınabilir).
    static func delete(_ url: URL) {
        lock.lock(); defer { lock.unlock() }
        let fm = FileManager.default
        do { try fm.trashItem(at: url, resultingItemURL: nil) }
        catch { try? fm.removeItem(at: url) }
    }
}
