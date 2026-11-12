# 🔗 Link Cepte

**Türkçe** · [English](#english)

Link Cepte, linklerinizi ve kısa notlarınızı düz dosyalar olarak (`.url` ve `.txt`) klasörlerde saklayan basit bir
link/not defteridir. macOS ve Chrome için sürümleri vardır. Hesap, bulut veya sunucu gerekmez; her şey
kendi cihazınızdaki klasörlerde durur.

## Özellikler

- Linkleri `.url`, notları `.txt` dosyası olarak kaydeder; dosyalar başka uygulamalarla da açılabilir.
- Klasörlerle düzenleme, yeniden adlandırma, taşıma ve sıralama.
- Link ve notlar içinde arama.
- Başka uygulamalardan **Paylaş** menüsüyle link kaydetme (macOS Paylaş eklentisi ve Servisler menüsü).
- Chrome eklentisiyle açık sekmeyi tek tıkla Mac uygulamasına gönderme.
- Türkçe ve İngilizce arayüz (cihaz diline göre otomatik).

## Proje yapısı

| Klasör | İçerik |
|---|---|
| `mac/` | macOS uygulaması (Swift, SwiftUI, macOS 13+) ve Paylaş eklentisi |
| `chrome-extension/` | Chrome eklentisi (Manifest V3); Mac uygulamasının içinde gelir |

## Kurulum

Hazır sürümleri [Releases](https://github.com/idrisokys/LinkCepte/releases) sayfasından indirebilirsiniz.

### macOS

1. `LinkCepte-mac.zip` dosyasını indirip açın, uygulamayı **Uygulamalar** klasörüne taşıyın.
2. Uygulama Apple Developer hesabıyla imzalanmadığı için ilk açılışta uygulamaya sağ tıklayıp **Aç**'ı seçin.
3. Linkler varsayılan olarak ana dizindeki `~/Link` klasörüne kaydedilir (yoksa otomatik oluşturulur); klasör seçimi yoktur.

### Chrome eklentisi

Menü çubuğunda **Link → Chrome Eklentisi Klasörünü Aç** seçeneğini kullanın. Ayrıntılı kurulum için
[chrome-extension/README.md](chrome-extension/README.md) dosyasına bakın.

## Kaynaktan derleme

**macOS** (Xcode / Swift 5.9+):

```bash
bash mac/scripts/build_app.sh
```

Uygulama `mac/build/LinkCepte.app` ve `mac/build/LinkCepte-mac.zip` olarak oluşur. Birim testleri için:

```bash
swift test --package-path mac
```

Kod düzeni için [mac/README.md](mac/README.md) dosyasına bakın.

GitHub Actions iş akışı (`.github/workflows/`) her `main` push'unda Mac uygulamasını otomatik derler.

## İletişim

- GitHub: <https://github.com/idrisokys>
- E-posta: sislivadi@gmail.com

## Lisans

[MIT](LICENSE)

---

<a name="english"></a>

# 🔗 Link Cepte (English)

Link Cepte is a simple link and note keeper that stores your links and short notes as plain files (`.url` and `.txt`)
in folders. It comes for macOS and Chrome. No account, cloud or server is needed; everything stays in folders
on your own device.

## Features

- Saves links as `.url` files and notes as `.txt` files, so other apps can open them too.
- Organize with folders: rename, move and reorder.
- Search across links and notes.
- Save links from other apps via **Share** (macOS Share extension and Services menu).
- Send the current Chrome tab to the Mac app with one click using the Chrome extension.
- Turkish and English interface (chosen automatically from the device language).

## Project structure

| Folder | Contents |
|---|---|
| `mac/` | macOS app (Swift, SwiftUI, macOS 13+) and Share extension |
| `chrome-extension/` | Chrome extension (Manifest V3); bundled inside the Mac app |

## Installation

Download ready-made builds from the [Releases](https://github.com/idrisokys/LinkCepte/releases) page.

### macOS

1. Download and unzip `LinkCepte-mac.zip`, then move the app to **Applications**.
2. The app is not signed with an Apple Developer account, so on first launch right-click it and choose **Open**.
3. Links are saved to `~/Link` in your home directory by default (created automatically if missing); there is no folder picker.

### Chrome extension

Use **Link → Open Chrome Extension Folder** in the menu bar. See
[chrome-extension/README.md](chrome-extension/README.md) for detailed steps.

## Building from source

**macOS** (Xcode / Swift 5.9+):

```bash
bash mac/scripts/build_app.sh
```

This produces `mac/build/LinkCepte.app` and `mac/build/LinkCepte-mac.zip`. Run the unit tests with:

```bash
swift test --package-path mac
```

See [mac/README.md](mac/README.md) for the code layout.

The GitHub Actions workflow in `.github/workflows/` build the Mac app automatically on every push to `main`.

## Contact

- GitHub: <https://github.com/idrisokys>
- Email: sislivadi@gmail.com

## License

[MIT](LICENSE)
