import Foundation

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

struct Entry: Identifiable, Hashable {
    let name: String
    let url: URL
    let isDir: Bool
    /// Liste anahtarı (yol).
    let key: String
    /// Düz metin dosyası (.txt) mı?
    let isTxt: Bool
    /// Listede gösterilen ad (uzantısız).
    let title: String
    let ext: String
    var id: String { key }

    init(name: String, url: URL, isDir: Bool) {
        self.name = name
        self.url = url
        self.isDir = isDir
        self.key = url.path
        let lower = name.lowercased()
        let txt = !isDir && lower.hasSuffix(".txt")
        self.isTxt = txt
        self.title = (!isDir && (lower.hasSuffix(".url") || txt)) ? String(name.dropLast(4)) : name
        self.ext = txt ? ".txt" : ".url"
    }
}

/// Arama sonucu: bulunan öğe, bulunduğu klasör zinciri ve gösterilecek özet.
struct Hit: Identifiable {
    let entry: Entry
    let path: [Entry]
    let detail: String
    let isNote: Bool
    let titleMatch: Bool
    var id: String { entry.key }
}

final class CancelFlag {
    private let l = NSLock()
    private var v = false
    func cancel() { l.lock(); v = true; l.unlock() }
    var isCancelled: Bool { l.lock(); defer { l.unlock() }; return v }
}

private final class HitBox {
    private let l = NSLock()
    private var items: [Hit?]
    init(count: Int) { items = Array(repeating: nil, count: count) }
    func set(_ i: Int, _ h: Hit) { l.lock(); items[i] = h; l.unlock() }
    func all() -> [Hit] { l.lock(); defer { l.unlock() }; return items.compactMap { $0 } }
}

enum Store {
    private static let ORDER = ".order.txt"
    private static let lock = NSRecursiveLock()
    private static let defaults = UserDefaults.standard

    // MARK: - Kök klasör

    /// Seçili kök klasör; yoksa veya yazılamıyorsa nil.
    static var root: URL? {
        guard let p = defaults.string(forKey: "root") else { return nil }
        var isDir: ObjCBool = false
        let fm = FileManager.default
        guard fm.fileExists(atPath: p, isDirectory: &isDir), isDir.boolValue, fm.isWritableFile(atPath: p) else { return nil }
        return URL(fileURLWithPath: p, isDirectory: true)
    }

    static func setRoot(_ url: URL) -> Bool {
        guard FileManager.default.isWritableFile(atPath: url.path) else { return false }
        defaults.set(url.path, forKey: "root")
        return root != nil
    }

    // MARK: - Ad temizleme

    private static func norm(_ s: String) -> String {
        s.precomposedStringWithCanonicalMapping.lowercased()
    }

    /// Dosya adında sorun çıkaran karakterleri temizler.
    private static func clean(_ s: String, _ limitChars: Int = 80) -> String {
        var t = s.replacingOccurrences(of: "[\\r\\n\\t]+", with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\s*[:|/\\\\]\\s*", with: " - ", options: .regularExpression)
        t = t.replacingOccurrences(of: "[*?\"<>]", with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        t = t.trimmed
        while let f = t.first, f == "." || f == " " || f == "-" { t.removeFirst() }
        t = String(t.prefix(limitChars))
        t = fitBytes(t).trimmed
        return t.isEmpty ? "link" : t
    }

    /// Dosya sistemi adı 255 bayt ile sınırlı; ".url" ve " (2)" payı bırakarak bayt cinsinden kısaltır.
    private static func fitBytes(_ s: String, limit: Int = 240) -> String {
        var bytes = 0
        var out = String.UnicodeScalarView()
        for sc in s.unicodeScalars {
            let n = String(sc).utf8.count
            if bytes + n > limit { break }
            bytes += n
            out.append(sc)
        }
        return String(out)
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
        try? data.write(to: dir.appendingPathComponent(ORDER))
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
        do { try data.write(to: dir.appendingPathComponent(name)) } catch { return false }
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
        var title: String? = await fetchTitle(url)
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

    // MARK: - Okuma

    private static func lines(_ url: URL) -> [String] {
        guard let d = try? Data(contentsOf: url) else { return [] }
        return String(decoding: d, as: UTF8.self).components(separatedBy: .newlines).map { l in
            var s = l
            if s.hasPrefix("\u{FEFF}") { s.removeFirst() }
            return s.trimmed
        }
    }

    private static func urlOf(_ ls: [String]) -> String? {
        guard let l = ls.first(where: { $0.lowercased().hasPrefix("url=") }) else { return nil }
        let v = String(l.dropFirst(4)).trimmed
        return v.isEmpty ? nil : v
    }

    private static func textOf(_ ls: [String]) -> String? {
        guard let l = ls.first(where: { $0.lowercased().hasPrefix("text=") }) else { return nil }
        return unescape(String(l.dropFirst(5)))
    }

    /// Dosyayı bir kez okuyup (link, metin) çiftini döndürür.
    static func readLink(_ url: URL) -> (String?, String?) {
        let ls = lines(url)
        return (urlOf(ls), textOf(ls))
    }

    private static func unescape(_ s: String) -> String {
        var out = ""
        let cs = Array(s)
        var i = 0
        while i < cs.count {
            let c = cs[i]
            if c == "\\" && i + 1 < cs.count {
                out.append(cs[i + 1] == "n" ? "\n" : cs[i + 1])
                i += 2
            } else { out.append(c); i += 1 }
        }
        return out
    }

    static func makeURL(_ s: String) -> URL? {
        if let u = URL(string: s) { return u }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "#%&=?/:@+;,$-_.!~*'()[]")
        return s.addingPercentEncoding(withAllowedCharacters: allowed).flatMap { URL(string: $0) }
    }

    // MARK: - Arama

    private static func foldChars(_ s: String) -> [Character] {
        s.map { c -> Character in
            switch c {
            case "İ", "ı": return "i"
            case "ş", "Ş": return "s"
            case "ğ", "Ğ": return "g"
            case "ü", "Ü": return "u"
            case "ö", "Ö": return "o"
            case "ç", "Ç": return "c"
            default:
                if c.isASCII { return Character(String(c).lowercased()) }
                let d = String(c).decomposedStringWithCanonicalMapping
                return String(d.first ?? c).lowercased().first ?? c
            }
        }
    }

    /// Büyük/küçük harf, Türkçe i/ı/İ/I ve aksan (ş→s, ğ→g...) farkını yok sayar.
    static func fold(_ s: String) -> String { String(foldChars(s)) }

    /// Tüm klasörlerde; başlık, link adresi ve not metninde arar. Yazılan her kelime bulunmalıdır.
    static func search(root: URL, query: String, alive: @escaping () -> Bool) -> [Hit] {
        let terms = fold(query).components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        if terms.isEmpty { return [] }

        var files = [(Entry, [Entry])]()
        func walk(_ dir: URL, _ path: [Entry]) {
            for e in list(dir) {
                if !alive() { return }
                if e.isDir { walk(e.url, path + [e]) } else { files.append((e, path)) }
            }
        }
        walk(root, [])
        let snapshot = files

        func match(_ e: Entry, _ path: [Entry]) -> Hit? {
            let ls = e.isTxt ? [] : lines(e.url)
            let url = urlOf(ls)
            let text = e.isTxt ? (readPlain(e.url) ?? "") : (textOf(ls) ?? "")
            let ft = fold(e.title)
            let body = url ?? text
            let fb = fold(body)
            let all = ft + "\n" + fb
            if !terms.allSatisfy({ all.contains($0) }) { return nil }
            let detail: String
            if let u = url {
                detail = u
            } else {
                let idxs = terms.compactMap { t -> Int? in
                    guard let r = fb.range(of: t) else { return nil }
                    return fb.distance(from: fb.startIndex, to: r.lowerBound)
                }
                let i = idxs.min() ?? 0
                let chars = Array(text)
                let st = max(0, i - 30)
                let end = min(chars.count, st + 120)
                let slice = st < end ? String(chars[st..<end]) : ""
                detail = (st > 0 ? "…" : "") + slice.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            }
            return Hit(entry: e, path: path, detail: detail, isNote: url == nil,
                       titleMatch: terms.allSatisfy { ft.contains($0) })
        }

        let box = HitBox(count: snapshot.count)
        DispatchQueue.concurrentPerform(iterations: snapshot.count) { i in
            if !alive() { return }
            let (e, path) = snapshot[i]
            if let h = match(e, path) { box.set(i, h) }
        }
        let hits = Array(box.all().prefix(500))
        // başlıkta geçenler önce
        return hits.filter { $0.titleMatch } + hits.filter { !$0.titleMatch }
    }

    // MARK: - Sayfa başlığı

    private static let badTitles = ["just a moment", "access denied", "attention required", "403 forbidden",
                                    "robot check", "are you a robot", "verifying you are human", "bir dakika", "erişim engellendi"]
    private static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    /// Sayfanın <title> değerini getirir (en fazla 7 sn); olmazsa nil.
    static func fetchTitle(_ url: String) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask { await fetchTitleInner(url) }
            group.addTask { try? await Task.sleep(nanoseconds: 7_000_000_000); return nil }
            var result: String? = nil
            if let r = await group.next() { result = r }
            group.cancelAll()
            return result
        }
    }

    private static func fetchTitleInner(_ url: String) async -> String? {
        var target = url
        if target.lowercased().hasPrefix("http://") { target = "https://" + String(target.dropFirst(7)) }
        guard let u = makeURL(target) else { return nil }
        var req = URLRequest(url: u)
        req.timeoutInterval = 3
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("tr,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        do {
            let (bytes, resp) = try await URLSession.shared.bytes(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            var buf = Data()
            for try await b in bytes {
                buf.append(b)
                if buf.count >= 160_000 { break }
                // </title> görüldüyse fazlasını indirme
                if b == 0x3E, buf.count >= 8,
                   String(data: Data(buf.suffix(8)), encoding: .isoLatin1)?.lowercased() == "</title>" { break }
            }
            return parseTitle(buf, contentType: http.value(forHTTPHeaderField: "Content-Type"))
        } catch {
            return nil
        }
    }

    private static func firstGroup(_ pattern: String, in s: String, options: NSRegularExpression.Options = [.caseInsensitive]) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let ns = s as NSString
        guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)), m.numberOfRanges > 1,
              m.range(at: 1).location != NSNotFound else { return nil }
        return ns.substring(with: m.range(at: 1))
    }

    private static func encoding(_ name: String?) -> String.Encoding {
        guard let n = name else { return .utf8 }
        let cf = CFStringConvertIANACharSetNameToEncoding(n as CFString)
        if cf == kCFStringEncodingInvalidId { return .utf8 }
        return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cf))
    }

    private static func parseTitle(_ buf: Data, contentType: String?) -> String? {
        let head = String(data: buf, encoding: .isoLatin1) ?? ""
        let cs = firstGroup("charset=([\\w-]+)", in: contentType ?? "")
            ?? firstGroup("<meta[^>]+charset=[\"']?([\\w-]+)", in: head)
        let html = String(data: buf, encoding: encoding(cs)) ?? String(decoding: buf, as: UTF8.self)
        guard let raw = firstGroup("<title[^>]*>(.*?)</title>", in: html, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return nil }
        let t = decodeEntities(raw).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmed
        if t.isEmpty || badTitles.contains(where: { t.lowercased().hasPrefix($0) }) { return nil }
        return t
    }

    private static func decodeEntities(_ s: String) -> String {
        var result = s
        if let re = try? NSRegularExpression(pattern: "&#([xX]?)([0-9a-fA-F]+);") {
            let ns = s as NSString
            for m in re.matches(in: s, range: NSRange(location: 0, length: ns.length)).reversed() {
                let hex = ns.substring(with: m.range(at: 1)).isEmpty == false
                let digits = ns.substring(with: m.range(at: 2))
                if let code = UInt32(digits, radix: hex ? 16 : 10), let sc = Unicode.Scalar(code),
                   let r = Range(m.range, in: result) {
                    result.replaceSubrange(r, with: String(Character(sc)))
                }
            }
        }
        let named: [(String, String)] = [
            ("&nbsp;", " "), ("&quot;", "\""), ("&apos;", "'"), ("&lt;", "<"), ("&gt;", ">"),
            ("&ccedil;", "ç"), ("&Ccedil;", "Ç"), ("&ouml;", "ö"), ("&Ouml;", "Ö"), ("&uuml;", "ü"), ("&Uuml;", "Ü"),
            ("&ndash;", "–"), ("&mdash;", "—"), ("&hellip;", "…"), ("&rsquo;", "’"), ("&lsquo;", "‘"),
            ("&ldquo;", "“"), ("&rdquo;", "”"), ("&amp;", "&")
        ]
        for (k, v) in named { result = result.replacingOccurrences(of: k, with: v) }
        return result
    }
}
