import AppKit

/// Araç çubuğundaki Chrome düğmesi için çizilmiş küçük renkli simge (şablon değil, renkleri korunur).
enum ChromeLogo {
    static let image: NSImage = {
        let s: CGFloat = 18
        let img = NSImage(size: NSSize(width: s, height: s), flipped: false) { rect in
            let c = NSPoint(x: rect.midX, y: rect.midY)
            let r = rect.width / 2

            func wedge(_ from: CGFloat, _ to: CGFloat, _ color: NSColor) {
                let p = NSBezierPath()
                p.move(to: c)
                p.appendArc(withCenter: c, radius: r, startAngle: from, endAngle: to)
                p.close()
                color.setFill()
                p.fill()
            }
            func dot(_ radius: CGFloat, _ color: NSColor) {
                color.setFill()
                NSBezierPath(ovalIn: NSRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2)).fill()
            }

            wedge(30, 150, NSColor(srgbRed: 0.918, green: 0.263, blue: 0.208, alpha: 1))    // kırmızı (üst)
            wedge(150, 270, NSColor(srgbRed: 0.204, green: 0.659, blue: 0.325, alpha: 1))   // yeşil (sol alt)
            wedge(270, 390, NSColor(srgbRed: 0.984, green: 0.737, blue: 0.016, alpha: 1))   // sarı (sağ alt)
            dot(r * 0.50, .white)
            dot(r * 0.38, NSColor(srgbRed: 0.259, green: 0.522, blue: 0.957, alpha: 1))     // mavi merkez
            return true
        }
        img.isTemplate = false
        return img
    }()
}
