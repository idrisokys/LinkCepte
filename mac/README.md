# Link Cepte — macOS

Swift 5.9 · SwiftUI · macOS 13+ · SwiftPM (Xcode gerekmez)

## Klasör yapısı

```
mac/
├── Package.swift            # LinkCepte (uygulama) + LinkCepteTests
├── version.env              # Sürüm numarası (tek yer; scriptler Info.plist'e yazar)
├── scripts/
│   ├── build_app.sh         # .app + .zip üretir (evrensel, ad-hoc imzalı)
│   └── build_share.sh       # Paylaş eklentisini derler (build_app.sh çağırır)
├── Resources/               # Info.plist, ikonlar, tr/en ServicesMenu.strings
├── ShareExtension/          # Safari/Paylaş menüsü eklentisi (ayrı derlenir)
├── Sources/LinkCepte/
│   ├── App/                 # LinkCepteApp (giriş), AppDelegate, HUD (kısa bildirim)
│   ├── Models/              # Entry, Hit, Sheet — saf veri tipleri
│   ├── Store/               # Disk katmanı: Store (+Naming/+Reading/+Search), PageTitle
│   ├── Services/            # ChromeExtensionInstaller, ReorderInput (klavye/kaydırma)
│   ├── ViewModel/           # Model (durum) + Model+*.swift (davranış, konuya göre)
│   ├── Views/               # SwiftUI görünümleri; Components/ ve Sheets/ alt klasörleri
│   └── Support/             # AppInfo (sabitler), Localization (L()), küçük yardımcılar
└── Tests/LinkCepteTests/    # Store ve Entry için birim testleri
```

Katman kuralı: `Views → ViewModel → Store/Services → Models`. Store, SwiftUI'yi bilmez;
disk işlemleri `Model.io { }` ile sıralı kuyrukta çalışır.

## Komutlar

```bash
bash mac/scripts/build_app.sh        # mac/build/LinkCepte.app
swift test --package-path mac        # birim testleri
```

## Sürüm yükseltme

`mac/version.env` içindeki `MARKETING_VERSION` ve `BUILD_NUMBER` değerlerini değiştirin.
Chrome eklentisinin sürümü ayrıdır: `chrome-extension/manifest.json`.

## Not: sabitlerin iki kopyası

`AppInfo.swift` içindeki `bundleID`, `shareExtensionID` ve `urlScheme`, `Resources/Info.plist`,
`ShareExtension/Info.plist` ve `ShareExtension/ShareViewController.swift` içinde de yazılıdır
(Paylaş eklentisi ayrı derlendiği için kodu paylaşamaz). Değiştirirseniz hepsini güncelleyin.
