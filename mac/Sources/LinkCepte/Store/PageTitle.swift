import Foundation

/// Bir web sayfasının <title> değerini indirir ve çözümler.
enum PageTitle {
    private static let badTitles = ["just a moment", "access denied", "attention required", "403 forbidden",
                                    "robot check", "are you a robot", "verifying you are human", "bir dakika", "erişim engellendi"]
    private static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    /// Sayfanın <title> değerini getirir (en fazla 7 sn); olmazsa nil.
    static func fetch(_ url: String) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask { await fetchInner(url) }
            group.addTask { try? await Task.sleep(nanoseconds: 7_000_000_000); return nil }
            var result: String? = nil
            if let r = await group.next() { result = r }
            group.cancelAll()
            return result
        }
    }

    private static func fetchInner(_ url: String) async -> String? {
        var target = url
        if target.lowercased().hasPrefix("http://") { target = "https://" + String(target.dropFirst(7)) }
        guard let u = Store.makeURL(target) else { return nil }
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
