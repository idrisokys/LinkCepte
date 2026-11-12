import AppKit

extension Model {
    /// Chrome eklenti klasörünü hazırlar ve Finder'da gösterir.
    func openChromeExtension() {
        guard let target = ChromeExtensionInstaller.prepare() else {
            toast(L("Chrome eklentisi bu uygulama sürümünde bulunamadı", "The Chrome extension isn't included in this app build"))
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([target])   // klasörün içini değil, bulunduğu yeri açar ve klasörü seçili gösterir
        toast(L("Chrome eklentisi klasörü Finder’da gösterildi — kurulum için README.md’ye bakın",
                "Chrome extension folder shown in Finder — see README.md for setup"))
    }
}
