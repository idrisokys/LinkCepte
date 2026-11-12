import SwiftUI
import AppKit

extension Model {
    // MARK: - Satır işlemleri

    func tap(_ e: Entry) {
        if editMode { toggle(e.key) }
        else if e.isDir { setStack(stack + [e]) }
        else { open(e) }
    }

    func toggle(_ key: String) {
        if selected.contains(key) { selected.remove(key) } else { selected.insert(key) }
    }

    func toggleEdit() {
        if txt != nil { txtStartEdit(); return }   // .txt açıkken ⌘E metni düzenler
        editMode.toggle()
        selected = []
    }

    func open(_ e: Entry) {
        Task {
            if e.isTxt {
                let t = await self.io { Store.readPlain(e.url) }
                if let t = t { self.openTxt(e, t) } else { self.toast(L("Dosya okunamadı", "Couldn't read the file")) }
                return
            }
            let (u, t) = await self.io { Store.readLink(e.url) }
            if let u = u {
                // Yerel dosya / uygulama çalıştıran şemalar açılmaz (elle yazılmış veya geri yüklenmiş .url dosyalarına karşı)
                if let link = Store.makeURL(u), !["file", "javascript"].contains(link.scheme?.lowercased() ?? ""),
                   NSWorkspace.shared.open(link) { return }
                self.toast(L("Link açılamadı", "Couldn't open the link"))
            } else if let t = t {
                self.noteText = t
                self.sheet = .note
            } else {
                self.toast(L("Link okunamadı", "Couldn't read the link"))
            }
        }
    }
}
