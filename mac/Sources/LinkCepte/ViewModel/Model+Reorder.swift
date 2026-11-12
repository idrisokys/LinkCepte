import AppKit

// Düzenleme modunda ↑ / ↓ tuşları veya yukarı-aşağı kaydırma ile sıra değiştirme.
// Klavye ve kaydırma olaylarını `ReorderInput` dinler; bu dosya yalnızca sıranın kendisini değiştirir.
extension Model {
    /// Sıra değiştirme girdisi şu an dinlenmeli mi?
    var reorderActive: Bool {
        editMode && !selected.isEmpty && txt == nil && sheet == nil && searchQuery == nil && root != nil
    }

    func installReorderMonitors() { reorderInput.install() }

    /// İşaretli satır(lar)ı bir adım yukarı (-1) veya aşağı (+1) taşır ve yeni sırayı kaydeder.
    func moveSelected(_ delta: Int) {
        guard editMode, !selected.isEmpty, var l = loaded, l.count > 1, let dir = current else { return }
        var moved = false
        if delta < 0 {
            for i in 1..<l.count where selected.contains(l[i].key) && !selected.contains(l[i - 1].key) {
                l.swapAt(i, i - 1); moved = true
            }
        } else {
            for i in stride(from: l.count - 2, through: 0, by: -1) where selected.contains(l[i].key) && !selected.contains(l[i + 1].key) {
                l.swapAt(i, i + 1); moved = true
            }
        }
        guard moved else { return }
        loaded = l
        revealKey = (delta < 0 ? l.first(where: { selected.contains($0.key) }) : l.last(where: { selected.contains($0.key) }))?.key
        revealTick += 1
        let names = l.map { $0.name }
        Task { await self.io { Store.saveOrder(dir, names) } }
    }
}
