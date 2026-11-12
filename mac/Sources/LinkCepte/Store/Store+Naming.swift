import Foundation

extension Store {
    // MARK: - Ad temizleme

    static func norm(_ s: String) -> String {
        s.precomposedStringWithCanonicalMapping.lowercased()
    }

    /// Dosya adında sorun çıkaran karakterleri temizler.
    static func clean(_ s: String, _ limitChars: Int = 80) -> String {
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
    static func fitBytes(_ s: String, limit: Int = 240) -> String {
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
}
