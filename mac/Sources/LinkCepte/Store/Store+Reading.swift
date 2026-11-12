import Foundation

extension Store {
    // MARK: - Okuma

    static func lines(_ url: URL) -> [String] {
        guard let d = try? Data(contentsOf: url) else { return [] }
        return String(decoding: d, as: UTF8.self).components(separatedBy: .newlines).map { l in
            var s = l
            if s.hasPrefix("\u{FEFF}") { s.removeFirst() }
            return s.trimmed
        }
    }

    static func urlOf(_ ls: [String]) -> String? {
        guard let l = ls.first(where: { $0.lowercased().hasPrefix("url=") }) else { return nil }
        let v = String(l.dropFirst(4)).trimmed
        return v.isEmpty ? nil : v
    }

    static func textOf(_ ls: [String]) -> String? {
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
}
