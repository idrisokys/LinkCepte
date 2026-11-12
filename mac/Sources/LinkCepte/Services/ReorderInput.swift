import AppKit

/// Sıra değiştirme için ok tuşları ve kaydırma olaylarını dinler (bir kez kurulur).
@MainActor
final class ReorderInput {
    private weak var model: Model?
    private var monitors: [Any] = []
    private var scrollArmed = true
    private var scrollAccum: CGFloat = 0
    private var lastWheelStep: TimeInterval = 0

    init(model: Model) { self.model = model }

    func install() {
        guard monitors.isEmpty else { return }
        if let k = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] ev in
            guard let self = self else { return ev }
            return self.handleKey(ev) ? nil : ev
        }) { monitors.append(k) }
        if let s = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel, handler: { [weak self] ev in
            guard let self = self else { return ev }
            return self.handleScroll(ev) ? nil : ev
        }) { monitors.append(s) }
    }

    private func handleKey(_ ev: NSEvent) -> Bool {
        guard let model = model, model.reorderActive else { return false }
        // Bir metin alanı odaktaysa ok tuşları imleci taşır
        if NSApp.keyWindow?.firstResponder is NSTextView { return false }
        if !ev.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty { return false }
        switch ev.keyCode {
        case 126: model.moveSelected(-1); return true   // ↑
        case 125: model.moveSelected(1); return true    // ↓
        default: return false
        }
    }

    /// Parmak/tekerlek yukarı → satır yukarı, aşağı → aşağı. Bir kaydırma hareketi tek adım sayılır;
    /// ⌥ basılıyken veya metin alanının üzerindeyken normal kaydırma çalışır.
    private func handleScroll(_ ev: NSEvent) -> Bool {
        guard let model = model, model.reorderActive, !ev.modifierFlags.contains(.option) else { return false }
        if let root = ev.window?.contentView?.superview ?? ev.window?.contentView,
           var v: NSView = root.hitTest(ev.locationInWindow) {
            while true {
                if v is NSTextView { return false }
                guard let p = v.superview else { break }
                v = p
            }
        }
        let dy = ev.scrollingDeltaY
        func step(_ amount: CGFloat) {
            let up = ev.isDirectionInvertedFromDevice ? amount < 0 : amount > 0
            model.moveSelected(up ? -1 : 1)
        }
        if ev.hasPreciseScrollingDeltas {
            // Dokunmatik yüzey: her yeni harekette bir kez; hareket ve ivmesi bitene kadar liste kaymaz
            if ev.phase == .began || ev.phase == .mayBegin { scrollArmed = true; scrollAccum = 0 }
            if scrollArmed {
                scrollAccum += dy
                if abs(scrollAccum) >= 10 { step(scrollAccum); scrollArmed = false }
            }
        } else if dy != 0 {
            // Fare tekerleği: her tık bir adım
            if ev.timestamp - lastWheelStep > 0.08 { step(dy); lastWheelStep = ev.timestamp }
        }
        return true
    }
}
