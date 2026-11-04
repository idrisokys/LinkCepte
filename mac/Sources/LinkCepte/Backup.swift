import Foundation

/// Yedekleme: kök klasörün tamamı tek zip olarak yazılır; geri alırken zip kök klasöre GÜVENLİ biçimde birleştirilir.
/// Zip düzeni Android sürümüyle aynıdır (kökten göreli yollar, UTF-8 adlar, `.order.txt` sıralama dosyaları dahil).
enum Backup {
    private static let ORDER = ".order.txt"
    private static let maxEntry = 20_000_000   // Android ile aynı: bundan büyük tek dosya atlanır

    // MARK: - Yedek oluştur

    /// Kök klasörün tamamını zip olarak döndürür (zip verisi, dosya sayısı).
    static func makeZip(root: URL) throws -> (Data, Int) {
        try Store.locked { () throws -> (Data, Int) in
            var z = ZipBuilder()
            let n = try z.addTree(root, prefix: "")
            return (try z.finish(), n)
        }
    }

    // MARK: - Geri al

    /// Zip içeriğini kök klasöre birleştirir: mevcut hiçbir dosya silinmez veya değiştirilmez.
    /// - Dosya yoksa oluşturulur.
    /// - Aynı ad ve aynı içerik varsa atlanır.
    /// - Aynı ad ama farklı içerik varsa "ad (Dropbox).uzantı" olarak ayrı kaydedilir.
    /// - Sıralama dosyası (.order.txt) ezilmez; yedekteki eksik satırlar sona eklenir.
    /// Eklenen/birleştirilen dosya sayısını döndürür.
    static func restore(zip: Data, into root: URL) throws -> Int {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("LinkCepte-restore-" + UUID().uuidString, isDirectory: true)
        let out = tmp.appendingPathComponent("x", isDirectory: true)
        try fm.createDirectory(at: out, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }

        let zipURL = tmp.appendingPathComponent("backup.zip")
        try zip.write(to: zipURL)
        try run("/usr/bin/ditto", ["-x", "-k", zipURL.path, out.path])   // ditto: UTF-8 (Türkçe) dosya adlarını doğru açar

        return Store.locked { () -> Int in merge(from: out, into: root) }
    }

    private static func run(_ tool: String, _ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        let err = Pipe()
        p.standardError = err
        p.standardOutput = FileHandle.nullDevice
        try p.run()
        let data = err.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        if p.terminationStatus != 0 {
            let detail = String(String(decoding: data, as: UTF8.self).prefix(300))
            throw DropboxError(L("Yedek dosyası açılamadı: ", "Could not open the backup file: ") + detail)
        }
    }

    private static func norm(_ s: String) -> String {
        s.precomposedStringWithCanonicalMapping.lowercased()
    }

    private static func lines(_ url: URL) -> [String] {
        guard let d = try? Data(contentsOf: url) else { return [] }
        return String(decoding: d, as: UTF8.self)
            .components(separatedBy: .newlines)
            .filter { !$0.trimmed.isEmpty }
    }

    private static func merge(from src: URL, into root: URL) -> Int {
        let fm = FileManager.default
        var n = 0

        func walk(_ s: URL, _ d: URL) {
            guard let names = try? fm.contentsOfDirectory(atPath: s.path) else { return }
            var siblings = (try? fm.contentsOfDirectory(atPath: d.path)) ?? []

            for name in names.sorted() {
                if name == "__MACOSX" || name.hasPrefix("._") { continue }
                if name.hasPrefix(".") && name != ORDER { continue }   // .DS_Store gibi gizli dosyalar geri alınmaz

                let su = s.appendingPathComponent(name)
                guard let attrs = try? fm.attributesOfItem(atPath: su.path),
                      let type = attrs[.type] as? FileAttributeType else { continue }

                let existing = siblings.first(where: { norm($0) == norm(name) })

                // Klasör: varsa içine birleştir, yoksa oluştur
                if type == .typeDirectory {
                    var du = d.appendingPathComponent(existing ?? name, isDirectory: true)
                    if existing != nil {
                        var isDir: ObjCBool = false
                        guard fm.fileExists(atPath: du.path, isDirectory: &isDir), isDir.boolValue else { continue }
                    } else {
                        du = d.appendingPathComponent(name, isDirectory: true)
                        do { try fm.createDirectory(at: du, withIntermediateDirectories: false) } catch { continue }
                        siblings.append(name)
                    }
                    walk(su, du)
                    continue
                }

                // Yalnızca düz dosyalar (sembolik bağlantılar atlanır)
                guard type == .typeRegular else { continue }
                let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
                if size > maxEntry { continue }

                guard let ex = existing else {
                    do { try fm.copyItem(at: su, to: d.appendingPathComponent(name)); siblings.append(name); n += 1 } catch { }
                    continue
                }

                let eu = d.appendingPathComponent(ex)
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: eu.path, isDirectory: &isDir), isDir.boolValue { continue }   // aynı adlı klasör var
                if fm.contentsEqual(atPath: eu.path, andPath: su.path) { continue }                    // aynısı zaten var

                if name == ORDER {                                                                     // sıralamayı birleştir, ezme
                    let have = lines(eu)
                    let haveSet = Set(have.map { $0.precomposedStringWithCanonicalMapping })
                    let extra = lines(su).filter { !haveSet.contains($0.precomposedStringWithCanonicalMapping) }
                    if !extra.isEmpty {
                        let text = (have + extra).joined(separator: "\n")
                        if (try? Data(text.utf8).write(to: eu)) != nil { n += 1 }
                    }
                    continue
                }

                // Farklı içerik: mevcut dosyaya dokunmadan yanına "(Dropbox)" ekli kopya
                let ns = name as NSString
                let ext = ns.pathExtension.isEmpty ? "" : "." + ns.pathExtension
                let base = ext.isEmpty ? name : ns.deletingPathExtension
                var i = 1
                while i < 100 {
                    let alt = Store.fitBytes(base, limit: 200) + (i == 1 ? " (Dropbox)" : " (Dropbox \(i))") + ext
                    if let ax = siblings.first(where: { norm($0) == norm(alt) }) {
                        if fm.contentsEqual(atPath: d.appendingPathComponent(ax).path, andPath: su.path) { break }   // bu kopya da zaten var
                        i += 1
                        continue
                    }
                    do { try fm.copyItem(at: su, to: d.appendingPathComponent(alt)); siblings.append(alt); n += 1 } catch { }
                    break
                }
            }
        }

        walk(src, root)
        return n
    }
}

// MARK: - Zip yazıcı (sıkıştırmasız "stored" yöntem; metin/link dosyaları küçük olduğundan yeterli)

private struct ZipBuilder {
    private var out = Data()
    private var central = Data()
    private var count = 0

    private static let crcTable: [UInt32] = (0..<256).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0..<8 { c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1) }
        return c
    }

    private static func crc32(_ d: Data) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for b in d { c = crcTable[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFF_FFFF
    }

    private static func dos(_ date: Date) -> (UInt16, UInt16) {
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = min(max((c.year ?? 1980) - 1980, 0), 127)
        let time = ((c.hour ?? 0) << 11) | ((c.minute ?? 0) << 5) | ((c.second ?? 0) / 2)
        let day = (year << 9) | (max(c.month ?? 1, 1) << 5) | max(c.day ?? 1, 1)
        return (UInt16(truncatingIfNeeded: time), UInt16(truncatingIfNeeded: day))
    }

    private mutating func add(_ rawName: String, _ data: Data, isDir: Bool, date: Date) throws {
        let name = Data(rawName.precomposedStringWithCanonicalMapping.utf8)   // adlar NFC: Android ile uyumlu
        if name.count >= 65535 || count >= 65535 || UInt64(out.count) + UInt64(data.count) > 0xF000_0000 {
            throw DropboxError(L("Klasör yedeklenemeyecek kadar büyük", "The folder is too large to back up"))
        }
        let (t, d) = ZipBuilder.dos(date)
        let crc = isDir ? 0 : ZipBuilder.crc32(data)
        let size = UInt32(data.count)
        let offset = UInt32(out.count)

        // Yerel başlık + veri
        out.le32(0x0403_4B50); out.le16(20); out.le16(0x0800); out.le16(0)
        out.le16(t); out.le16(d)
        out.le32(crc); out.le32(size); out.le32(size)
        out.le16(UInt16(name.count)); out.le16(0)
        out.append(name); out.append(data)

        // Merkezi dizin kaydı
        let attr: UInt32 = isDir ? ((UInt32(0o040755) << 16) | 0x10) : (UInt32(0o100644) << 16)
        central.le32(0x0201_4B50); central.le16(0x0314); central.le16(20); central.le16(0x0800); central.le16(0)
        central.le16(t); central.le16(d)
        central.le32(crc); central.le32(size); central.le32(size)
        central.le16(UInt16(name.count)); central.le16(0); central.le16(0)
        central.le16(0); central.le16(0); central.le32(attr); central.le32(offset)
        central.append(name)
        count += 1
    }

    /// Klasörü (alt klasörler dahil) ekler; eklenen dosya sayısını döndürür.
    mutating func addTree(_ dir: URL, prefix: String) throws -> Int {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: dir.path) else { return 0 }
        var files = 0
        for name in names.sorted() {
            if name == ".DS_Store" || name.hasPrefix(".tmp-") { continue }
            let u = dir.appendingPathComponent(name)
            guard let attrs = try? fm.attributesOfItem(atPath: u.path),
                  let type = attrs[.type] as? FileAttributeType else { continue }
            let date = (attrs[.modificationDate] as? Date) ?? Date()
            if type == .typeDirectory {
                try add("\(prefix)\(name)/", Data(), isDir: true, date: date)
                files += try addTree(u, prefix: "\(prefix)\(name)/")
            } else if type == .typeRegular {
                guard let data = try? Data(contentsOf: u) else { continue }   // okunamayan dosya atlanır
                try add(prefix + name, data, isDir: false, date: date)
                files += 1
            }
        }
        return files
    }

    mutating func finish() throws -> Data {
        let cdOffset = out.count
        out.append(central)
        out.le32(0x0605_4B50); out.le16(0); out.le16(0)
        out.le16(UInt16(count)); out.le16(UInt16(count))
        out.le32(UInt32(central.count)); out.le32(UInt32(cdOffset)); out.le16(0)
        return out
    }
}

private extension Data {
    mutating func le16(_ v: UInt16) {
        append(UInt8(v & 0xFF)); append(UInt8(v >> 8))
    }
    mutating func le32(_ v: UInt32) {
        append(UInt8(v & 0xFF)); append(UInt8((v >> 8) & 0xFF))
        append(UInt8((v >> 16) & 0xFF)); append(UInt8(v >> 24))
    }
}
