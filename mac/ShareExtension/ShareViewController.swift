import AppKit
import UniformTypeIdentifiers

/// Safari (ve diğer uygulamaların) Paylaş menüsündeki "Link Cepte" girişi.
/// Kendisi dosya yazmaz; linki `linkcepte://add?t=...` adresiyle ana uygulamaya iletir
/// (ana uygulama arka planda başlığı alıp kaydeder ve kısa bir bildirim gösterir).
@objc(ShareViewController)
final class ShareViewController: NSViewController {
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        collect { [weak self] text in
            DispatchQueue.main.async { self?.forward(text) }
        }
    }

    private func collect(_ done: @escaping (String?) -> Void) {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        let providers = items.flatMap { $0.attachments ?? [] }

        if let p = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
            p.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                if let u = item as? URL { done(u.isFileURL ? nil : u.absoluteString) }
                else if let s = item as? String { done(s) }
                else if let d = item as? Data, let s = String(data: d, encoding: .utf8) { done(s) }
                else { done(nil) }
            }
            return
        }
        if let p = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) {
            p.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                done(item as? String)
            }
            return
        }
        done(items.first?.attributedContentText?.string)
    }

    private func forward(_ text: String?) {
        guard let text = text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { finish(); return }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        let enc = text.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        guard let url = URL(string: "linkcepte://add?t=" + enc) else { finish(); return }
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.activates = false   // uygulamayı öne getirme
        NSWorkspace.shared.open(url, configuration: cfg) { [weak self] _, _ in
            DispatchQueue.main.async { self?.finish() }
        }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
