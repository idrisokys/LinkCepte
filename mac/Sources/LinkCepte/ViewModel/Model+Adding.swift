import SwiftUI
import AppKit

extension Model {
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

    /// Enter / gönder: link ise link olarak, sınırı aşan metin .txt olarak, kısa metin not olarak kaydedilir.
    func addFromText() {
        let text = linkText.trimmed
        guard !text.isEmpty, let dir = current else { return }
        let isUrl = Store.extractUrl(text) != nil
        let singleUrl = isUrl && !text.contains(where: { $0.isWhitespace })   // boşluksuz uzun link yine link kalır
        if text.count > addMax && !singleUrl { addTxt(); return }
        linkText = ""
        addExternal(text, into: dir, okMessage: L("Eklendi", "Added"))
    }

    /// Satıra uzun basınca metni doğrudan panoya kopyalar (.txt: içerik, link: adres, not: metin, klasör: ad).
    func copyEntry(_ e: Entry) {
        Task {
            var t: String? = e.title
            if !e.isDir {
                if e.isTxt { t = await self.io { Store.readPlain(e.url) } }
                else { let (u, n) = await self.io { Store.readLink(e.url) }; t = u ?? n ?? e.title }
            }
            if let t = t {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(t, forType: .string)
                self.toast(L("Kopyalandı", "Copied"))
            } else { self.toast(L("Kopyalanamadı", "Couldn't copy")) }
        }
    }

    /// Sürükle-bırak ve Servisler menüsünden gelen metin/link.
    func addExternal(_ text: String, into dir: URL, okMessage: String) {
        Task {
            let ok = await Store.addFromText(dir, text, nil)
            self.reload()
            self.toast(ok ? okMessage : L("Kaydedilemedi", "Couldn't save"))
        }
    }

    /// Servisler menüsü: ana listeye ekler (Paylaş → Link Cepte).
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
}
