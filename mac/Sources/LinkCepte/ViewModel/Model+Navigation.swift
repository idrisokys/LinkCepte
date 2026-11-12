import SwiftUI
import AppKit

extension Model {
    // MARK: - Gezinme

    func reload(then: (() -> Void)? = nil) {
        guard let dir = current else { loaded = nil; return }
        Task {
            let r = await self.io { Store.list(dir) }
            if self.current == dir { self.loaded = r }
            then?()
        }
    }

    /// Yenile düğmesi: kayıtlı klasörü yeniden tarar (arama açıksa aramayı yeniden çalıştırır).
    func refresh() {
        root = Store.root
        guard root != nil else { return }
        // Klasör dışarıdan silinmiş veya taşınmışsa gezinme yolunu geçerli son klasöre indir
        let fm = FileManager.default
        var valid = [Entry]()
        for e in stack {
            var d: ObjCBool = false
            if fm.fileExists(atPath: e.url.path, isDirectory: &d), d.boolValue { valid.append(e) } else { break }
        }
        if valid.count != stack.count { stack = valid; selected = [] }
        if let q = searchQuery { runSearch(q); return }
        reload { HUD.show(L("Yenilendi", "Refreshed")) }
    }

    func setStack(_ s: [Entry]) {
        stack = s
        selected = []
        loaded = nil
        reload()
    }

    func goBack() {
        if txt != nil { txtBack() }
        else if searchQuery != nil { exitSearch(false) }
        else if editMode { editMode = false; selected = [] }
        else if !stack.isEmpty { setStack(Array(stack.dropLast())) }
    }
}
