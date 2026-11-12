import SwiftUI
import AppKit

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
            for args in [["-a", appex.path], ["-e", "use", "-i", AppInfo.shareExtensionID]] {
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
        for u in urls where u.scheme == AppInfo.urlScheme {
            guard let c = URLComponents(url: u, resolvingAgainstBaseURL: false),
                  let t = c.queryItems?.first(where: { $0.name == "t" })?.value else { continue }
            Task { @MainActor in Model.shared.shareAdd(t) }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// Servisler menüsü → "Link Cepte'ye Ekle" (Info.plist'teki NSServices, NSMessage = addLink).
    /// Paylaş → Link Cepte: pencere açmaz, yalnızca kısa bir bildirim gösterir.
    @objc func addLink(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        let text = pboard.string(forType: .string) ?? ""
        Task { @MainActor in Model.shared.shareAdd(text) }
    }
}
