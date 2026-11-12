import Foundation

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
