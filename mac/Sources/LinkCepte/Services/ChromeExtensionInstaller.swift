import Foundation

/// Uygulamanın içindeki Chrome eklentisini sabit bir klasöre kopyalar.
/// Chrome eklentiyi yüklendiği klasörden okur; uygulama taşınsa ya da güncellense de yol bozulmasın diye
/// kopya `~/Library/Application Support/Link Cepte/chrome-extension` içinde durur.
enum ChromeExtensionInstaller {
    /// Finder'da gösterilecek klasörü döndürür. Eklenti uygulamaya eklenmemişse nil.
    /// Kopyalanamazsa uygulamanın içindeki klasör döner.
    static func prepare() -> URL? {
        let fm = FileManager.default
        guard let src = Bundle.main.resourceURL?.appendingPathComponent("chrome-extension", isDirectory: true),
              fm.fileExists(atPath: src.appendingPathComponent("manifest.json").path) else { return nil }
        guard let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return src }
        let dst = base.appendingPathComponent(AppInfo.supportFolderName, isDirectory: true)
            .appendingPathComponent("chrome-extension", isDirectory: true)
        return syncFolder(src, to: dst) ? dst : src
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
}
