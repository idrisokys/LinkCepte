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
                Button(L("Ekle", "Add")) { model.addFromText() }
                    .keyboardShortcut(.return, modifiers: .command)
                Button(L("Metin Dosyası Olarak Ekle (.txt)", "Add as Text File (.txt)")) { model.addTxt() }
                    .keyboardShortcut(.return, modifiers: [.command, .shift])
                Button(L("Ara", "Search")) { model.startSearch() }
                    .keyboardShortcut("f", modifiers: .command)
                Divider()
                Button(L("Yeni Klasör", "New Folder")) { model.sheet = .folder }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button(L("Düzenle", "Edit")) { model.toggleEdit() }
                    .keyboardShortcut("e", modifiers: .command)
                Button(L("Geri", "Back")) { model.goBack() }
                    .keyboardShortcut("[", modifiers: .command)
                Divider()
                Button(L("Yazıyı Büyüt", "Larger Text")) { model.bumpFont(1) }
                    .keyboardShortcut("+", modifiers: .command)
                Button(L("Yazıyı Küçült", "Smaller Text")) { model.bumpFont(-1) }
                    .keyboardShortcut("-", modifiers: .command)
                Divider()
                Button(L("Chrome Eklentisi Klasörünü Aç", "Open Chrome Extension Folder")) { model.openChromeExtension() }
            }
        }
    }
}
