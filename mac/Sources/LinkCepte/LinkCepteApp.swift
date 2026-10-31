import SwiftUI
import AppKit

@main
struct LinkCepteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = Model.shared

    var body: some Scene {
        // Tek pencere: linkcepte:// adresi geldiğinde yeni pencere açılmaz.
        Window("Link Cepte", id: "main") {
            ContentView()
                .environmentObject(model)
        }
        .defaultSize(width: 520, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Link") {
                Button("Ekle") { model.addFromText() }
                    .keyboardShortcut(.return, modifiers: .command)
                Button("Metin Dosyası Olarak Ekle (.txt)") { model.addTxt() }
                    .keyboardShortcut(.return, modifiers: [.command, .shift])
                Button("Ara") { model.startSearch() }
                    .keyboardShortcut("f", modifiers: .command)
                Divider()
                Button("Yeni Klasör") { model.sheet = .folder }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Düzenle") { model.toggleEdit() }
                    .keyboardShortcut("e", modifiers: .command)
                Button("Geri") { model.goBack() }
                    .keyboardShortcut("[", modifiers: .command)
                Button("Yenile") { model.reload() }
                    .keyboardShortcut("r", modifiers: .command)
                Divider()
                Button("Klasörü Değiştir…") { model.chooseFolder() }
                    .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        registerShareExtension()
    }

    /// Paylaş eklentisini sisteme tanıtır ve etkinleştirmeyi dener (hata olursa sessizce geçer).
    private func registerShareExtension() {
        let appex = Bundle.main.bundleURL.appendingPathComponent("Contents/PlugIns/LinkCepteShare.appex")
        guard FileManager.default.fileExists(atPath: appex.path) else { return }
        DispatchQueue.global(qos: .utility).async {
            for args in [["-a", appex.path], ["-e", "use", "-i", "com.example.linkcepte.mac.share"]] {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
                p.arguments = args
                try? p.run()
                p.waitUntilExit()
            }
        }
    }

    /// Paylaş eklentisinden gelen linkcepte://add?t=... adresi.
    func application(_ application: NSApplication, open urls: [URL]) {
        for u in urls where u.scheme == "linkcepte" {
            guard let c = URLComponents(url: u, resolvingAgainstBaseURL: false),
                  let t = c.queryItems?.first(where: { $0.name == "t" })?.value else { continue }
            Task { @MainActor in Model.shared.shareAdd(t) }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// Servisler menüsü → "Link Cepte'ye Ekle" (Info.plist'teki NSServices, NSMessage = addLink).
    /// Android'deki Paylaş → Link Cepte karşılığı: pencere açmaz, yalnızca kısa bir bildirim gösterir.
    @objc func addLink(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        let text = pboard.string(forType: .string) ?? ""
        Task { @MainActor in Model.shared.shareAdd(text) }
    }
}

/// Android'deki Toast karşılığı: ekranın altında kısa süre görünen küçük bildirim.
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
