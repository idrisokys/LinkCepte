import AppKit

/// Ekranın altında kısa süre görünen küçük bildirim.
@MainActor
enum HUD {
    private static var panel: NSPanel?

    static func show(_ text: String) {
        panel?.close()
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.sizeToFit()
        let pad: CGFloat = 16
        let size = NSSize(width: label.frame.width + pad * 2, height: label.frame.height + pad)

        let p = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.level = .statusBar
        p.hasShadow = true
        p.ignoresMouseEvents = true
        p.isReleasedWhenClosed = false

        let bg = NSView(frame: NSRect(origin: .zero, size: size))
        bg.wantsLayer = true
        bg.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.82).cgColor
        bg.layer?.cornerRadius = 10
        label.frame.origin = NSPoint(x: pad, y: pad / 2)
        bg.addSubview(label)
        p.contentView = bg

        if let scr = NSScreen.main {
            p.setFrameOrigin(NSPoint(x: scr.visibleFrame.midX - size.width / 2, y: scr.visibleFrame.minY + 80))
        }
        p.orderFrontRegardless()
        panel = p
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak p] in p?.close() }
    }
}
