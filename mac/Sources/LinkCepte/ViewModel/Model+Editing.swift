import SwiftUI
import AppKit

extension Model {
    // MARK: - Düzenleme

    func deleteSelected() {
        let items = list.filter { selected.contains($0.key) }
        selected = []
        Task {
            await self.io { for it in items { Store.delete(it.url) } }
            self.reload()
        }
    }

    func pasteIntoRename() {
        if let s = NSPasteboard.general.string(forType: .string) { renameText = String(s.prefix(maxChars)) }
    }

    func saveRename() {
        guard let r = renaming, let dir = current else { return }
        let n = renameText
        if n.trimmed.isEmpty { return }
        selected = []   // seçim kalkınca ad alanı da kapanır; düzenleme modu açık kalır
        Task {
            let ok = await self.io { Store.rename(dir, r, n) }
            self.reload()
            if !ok { self.toast(L("Ad değiştirilemedi (aynı adda öğe olabilir)", "Couldn't rename (an item with that name may exist)")) }
        }
    }

    func createFolder(_ name: String) {
        guard let dir = current else { return }
        Task {
            _ = await self.io { Store.addFolder(dir, name) }
            self.reload()
        }
    }

    func beginMove() {
        moving = list.filter { selected.contains($0.key) }
        sheet = .move
    }

    func performMove(to target: URL) {
        let files = moving
        sheet = nil
        moving = []
        selected = []
        Task {
            let ok = await self.io { files.filter { Store.moveEntry($0, to: target) }.count }
            self.reload()
            self.toast(ok == files.count
                  ? L("\(ok) öğe taşındı", "\(ok) item(s) moved")
                  : L("\(ok)/\(files.count) öğe taşınabildi", "\(ok)/\(files.count) item(s) could be moved"))
        }
    }
}
