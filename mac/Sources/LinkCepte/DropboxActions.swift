import SwiftUI
import AppKit

/// Dropbox eylemleri (⋮ menüsü ve menü çubuğundaki Link menüsü bunları çağırır).
extension Model {
    /// Tarayıcıda Dropbox girişini açar; dönüş AppDelegate üzerinden dropboxCallback'e gelir.
    func dbxConnect() {
        Dropbox.startAuth()
    }

    /// Giriş sayfasından db-<APP_KEY>://1/connect ile dönüş.
    func dropboxCallback(_ url: URL) {
        NSApp.activate(ignoringOtherApps: true)
        Task {
            do {
                try await Dropbox.finishAuth(url)
                dbxConnected = Dropbox.connected
                toast(L("Dropbox'a bağlandı", "Connected to Dropbox"))
            } catch {
                dbxConnected = Dropbox.connected
                dbxAlert(L("Dropbox bağlantısı başarısız: ", "Dropbox connection failed: ") + error.localizedDescription)
            }
        }
    }

    func dbxDisconnect() {
        Task {
            await Dropbox.disconnect()
            dbxConnected = Dropbox.connected
            toast(L("Bağlantı kesildi", "Disconnected"))
        }
    }

    /// Tüm klasörü tek zip olarak Dropbox'a yükler.
    func dbxBackup() {
        guard !dbxBusy, let r = root else { return }
        dbxBusy = true
        toast(L("Yedekleniyor…", "Backing up…"))
        Task {
            let msg: String
            do {
                let (data, n) = try await Task.detached(priority: .userInitiated) { () throws -> (Data, Int) in
                    try Backup.makeZip(root: r)
                }.value
                try await Dropbox.upload(data)
                msg = L("Dropbox'a yedeklendi (\(n) dosya)", "Backed up to Dropbox (\(n) files)")
            } catch {
                msg = L("Yedekleme hatası: ", "Backup error: ") + error.localizedDescription
            }
            dbxBusy = false
            dbxConnected = Dropbox.connected
            dbxAlert(msg)
        }
    }

    /// Önce onay sorar; sonra yedeği indirip mevcut klasöre güvenle birleştirir.
    func dbxAskRestore() {
        guard !dbxBusy else { return }
        let a = NSAlert()
        a.messageText = L("Dropbox'tan geri yükle", "Restore from Dropbox")
        a.informativeText = L(
            "Dropbox'taki yedek mevcut klasöre eklenir. Var olan hiçbir dosya silinmez veya değiştirilmez; yalnızca eksik olanlar getirilir. Aynı adlı ama farklı içerikli dosyalar \"(Dropbox)\" ekiyle ayrı kaydedilir.",
            "The Dropbox backup is merged into your current folder. No existing file is deleted or changed; only missing items are added. Files with the same name but different content are saved separately with a \"(Dropbox)\" suffix.")
        a.addButton(withTitle: L("Geri yükle", "Restore"))
        a.addButton(withTitle: L("İptal", "Cancel"))
        if a.runModal() == .alertFirstButtonReturn { dbxRestore() }
    }

    private func dbxRestore() {
        guard !dbxBusy, let r = root else { return }
        dbxBusy = true
        toast(L("Geri yükleniyor…", "Restoring…"))
        Task {
            let msg: String
            do {
                let data = try await Dropbox.download()
                let n = try await Task.detached(priority: .userInitiated) { () throws -> Int in
                    try Backup.restore(zip: data, into: r)
                }.value
                msg = L("Geri yüklendi (\(n) dosya)", "Restored (\(n) files)")
            } catch {
                msg = L("Geri yükleme hatası: ", "Restore error: ") + error.localizedDescription
            }
            dbxBusy = false
            dbxConnected = Dropbox.connected
            reload()
            dbxAlert(msg)
        }
    }

    /// Android'deki Dropbox sonuç/hata penceresinin karşılığı.
    func dbxAlert(_ text: String) {
        let a = NSAlert()
        a.messageText = "Dropbox"
        a.informativeText = text
        a.addButton(withTitle: L("Tamam", "OK"))
        a.runModal()
    }
}
