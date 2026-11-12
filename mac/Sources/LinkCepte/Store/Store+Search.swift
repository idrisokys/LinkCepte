import Foundation

private final class HitBox {
    private let l = NSLock()
    private var items: [Hit?]
    init(count: Int) { items = Array(repeating: nil, count: count) }
    func set(_ i: Int, _ h: Hit) { l.lock(); items[i] = h; l.unlock() }
    func all() -> [Hit] { l.lock(); defer { l.unlock() }; return items.compactMap { $0 } }
}

extension Store {
    // MARK: - Arama

    /// Büyük/küçük harf, Türkçe i/ı/İ/I ve aksan (ş→s, ğ→g, é→e...) farkını yok sayar.
    static func fold(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        for c in s {
            switch c {
            case "İ", "ı": out.append("i")
            case "ş", "Ş": out.append("s")
            case "ğ", "Ğ": out.append("g")
            case "ü", "Ü": out.append("u")
            case "ö", "Ö": out.append("o")
            case "ç", "Ç": out.append("c")
            default:
                // Karakter (grapheme) değil, unicode scalar düzeyinde ayrıştır:
                // "e" + birleşik aksan tek Character sayıldığı için aksan ancak böyle atılabilir.
                for u in String(c).decomposedStringWithCanonicalMapping.unicodeScalars
                where u.properties.generalCategory != .nonspacingMark {
                    out.append(contentsOf: String(u).lowercased().unicodeScalars)
                }
            }
        }
        return String(out)
    }

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
}
