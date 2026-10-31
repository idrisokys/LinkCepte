# 🔗 Link Cepte

**English** · [Türkçe](#türkçe)

A simple, lightweight app that keeps your favourite links **in a folder you choose**, as standard `.url` files. Available for **Android** and **Mac**, and both can share the same synced folder. A **Chrome extension** sends the open tab to the Mac app with one click.

No account, no ads. Your links live only in the folder you pick. The Android internet permission is used only to fetch the title of a page you add.

The apps follow the device language: Turkish if it is Turkish, English otherwise.

## Platforms

| | Folder | What it is |
|---|---|---|
| 📱 Android | repo root (`app/`) | Kotlin + Jetpack Compose, Android 7.0+ |
| 💻 Mac | [`mac/`](mac/README.md) | SwiftUI, macOS 13+ |
| 🌐 Chrome | [`chrome-extension/`](chrome-extension/README.md) | One-click "send to Link Cepte" for the Mac app |

## Features

- **Your own folder:** pick the save folder on first launch; it is remembered.
- **Quick add:** paste a link or plain text in the bottom field and press **+**. The page title is fetched automatically; text is saved as a note (tap to open, copy).
- **Search:** type one or more words and press 🔍. Link titles, addresses and notes are searched in all folders; every word must match. Case, Turkish dotted/dotless i and accents are ignored ("sehir" finds "Şehir").
- **Save in one tap:** in any browser choose **Share → Link Cepte**. The app does not open, you just see a short "Saved" message.
- **Standard `.url` files:** each link is its own file and also works on a computer:
  ```
  [InternetShortcut]
  URL=https://example.com
  ```
- **Folders:** organise links in sub-folders.
- **Edit mode:** the pencil at the top right shows checkboxes, a ☰ drag handle and a rename icon on every row. Select items to get Move and Delete icons.
- **Drag to reorder:** the order is stored in a hidden `.order.txt` file in each folder.
- **Move:** select one or more items, tap Move, pick a folder (you can create a new one while moving).
- **Refresh:** the ↻ icon at the far right of the top bar rescans the folder, so changes synced from another device show up right away.
- **Dark theme** and quick delete (no confirmation on Android; the Mac app moves items to the Trash).

## Usage (Android)

| Action | How |
|---|---|
| Add a link | Paste in the bottom field and press **+**, or **Share → Link Cepte** in a browser |
| Save long text as .txt | Paste it and **long-press +** |
| Search | Type words, press **🔍** |
| Open a link | Tap the row |
| Enter a folder / go back | Tap the folder row / arrow at the top left |
| New folder | Folder+ icon at the top |
| Edit | Pencil icon at the top right |
| Reorder | In edit mode drag the ☰ handle |
| Rename | In edit mode, pencil icon on the row |
| Delete | In edit mode select, then trash icon (no confirmation) |
| Move | In edit mode select → Move icon → pick folder → **Move here** |
| Change folder | ⋮ menu at the top right → **Change folder** |
| Refresh | ↻ icon at the top right |

If you later pick an old folder again, its links, folders and order come back as they were.

## Mac app and Chrome extension

The Mac app uses the same file format, so Android and Mac can use one folder synced with iCloud Drive, Syncthing, Google Drive, etc. It adds a Share-menu entry, a Services-menu entry and drag-and-drop. See [`mac/README.md`](mac/README.md).

The Chrome extension adds a toolbar button: click it and the current tab's link goes straight to the Mac app. See [`chrome-extension/README.md`](chrome-extension/README.md).

## Backup

There is no separate backup. All your data is in the chosen folder, so just copy it. Pair the folder with Google Drive, Syncthing or similar and backup and multi-device sync happen automatically.

## Install (build the APK on GitHub)

You do not need Android Studio.

1. Upload this project to your own GitHub repository.
2. Run **Actions → Build APK → Run workflow** (it also runs on every push to `main`).
3. When it turns green, download **Artifacts → LinkCepte-apk** from the run page.
4. Copy the `app-release.apk` from the zip to your phone and install it. Allow "install unknown apps" if asked.

For the Mac app run **Actions → Build Mac App** and download **LinkCepte-mac** (details in [`mac/README.md`](mac/README.md)).

**Note:** the APK is signed with a temporary key GitHub generates on every build. If a new version refuses to install over an old one, uninstall the old one first. Your links stay in your folder, so just pick the same folder again.

## Run with Android Studio

1. **Open** the project folder and wait for Gradle sync.
2. Connect a phone and press ▶.

## Technical notes

- Kotlin + Jetpack Compose (Material 3), minimum Android 7.0 (API 24)
- Storage: Android Storage Access Framework; no app-private storage or broad storage permission needed
- Permissions: internet only (to fetch page titles)
- A folder is read with a single query; file operations run in the background, one at a time
- Build: R8 shrinking on; only Turkish and English resources are packaged

## Limitations

- Places Android restricts (the Download folder itself, the storage root) cannot be chosen. Pick a folder you created.
- The page title is fetched from the link itself (waits a few seconds at most). If that fails, the shared title is used, otherwise the site address. Sites that require login or have bot protection may not give a title.
- Saving a second link with the same name appends (2) to its name.

---

<a name="türkçe"></a>

# 🔗 Link Cepte (Türkçe)

[English](#-link-cepte) · **Türkçe**

Favori linklerinizi **kendi seçtiğiniz bir klasörde**, standart `.url` dosyaları olarak saklayan, sade ve hafif bir uygulama. **Android** ve **Mac** sürümleri vardır, ikisi aynı eşitlenen klasörü kullanabilir. **Chrome eklentisi** açık sekmeyi tek tıkla Mac uygulamasına gönderir.

Hesap yok, reklam yok. Linkleriniz yalnızca sizin seçtiğiniz klasörde durur. Android'deki internet izni yalnızca eklenen sayfanın başlığını almak için kullanılır.

Uygulamalar cihaz dilini izler: Türkçe ise Türkçe, değilse İngilizce.

## Platformlar

| | Klasör | Ne olduğu |
|---|---|---|
| 📱 Android | depo kökü (`app/`) | Kotlin + Jetpack Compose, Android 7.0+ |
| 💻 Mac | [`mac/`](mac/README.md) | SwiftUI, macOS 13+ |
| 🌐 Chrome | [`chrome-extension/`](chrome-extension/README.md) | Mac uygulamasına tek tıkla "Link Cepte'ye gönder" |

## Özellikler

- **Kendi klasörünüz:** İlk açılışta linklerin saklanacağı klasörü seçersiniz. Seçim hatırlanır.
- **Alttan hızlı ekleme:** Alttaki alana link veya düz metin yapıştırıp **+** simgesine basın. Link eklenirken sayfanın başlığı otomatik alınır, metin ise not olarak kaydedilir (dokununca açılır, kopyalanabilir).
- **Arama:** Bir veya birkaç kelime yazıp 🔍 simgesine basın. Tüm klasörlerde link başlığı, adresi ve not metni taranır; yazdığınız kelimelerin hepsi geçmelidir. Büyük/küçük harf, Türkçe i/ı ve aksan farkı yok sayılır ("sehir" → "Şehir").
- **Tek dokunuşla kaydetme:** Herhangi bir tarayıcıda **Paylaş → Link Cepte**'yi seçin. Uygulama açılmaz, yalnızca "Kaydedildi" yazısı görünür.
- **Standart `.url` dosyaları:** Her link ayrı bir `.url` dosyasıdır, bilgisayarda da çalışır:
  ```
  [InternetShortcut]
  URL=https://ornek.com
  ```
- **Klasörler:** Linkleri alt klasörlerde düzenleyin.
- **Düzenleme modu:** Üstte en sağdaki kalem simgesine basınca satırlarda seçim kutusu, ☰ sürükleme tutamacı ve ad değiştirme simgesi görünür. Öğeleri işaretleyince üstte taşı ve sil simgeleri çıkar.
- **Sürükle-bırak sıralama:** Sıra, her klasördeki gizli `.order.txt` dosyasında tutulur.
- **Taşıma:** Bir veya birden fazla öğeyi işaretleyip taşı simgesiyle başka bir klasöre aktarın; taşırken **yeni klasör** de oluşturabilirsiniz.
- **Yenile:** Üst çubuğun en sağındaki ↻ simgesi klasörü yeniden tarar; başka cihazdan eşitlenen değişiklikler hemen görünür.
- **Karanlık tema** ve hızlı silme (Android'de onay sorulmaz; Mac uygulaması Çöp Kutusu'na taşır).

## Kullanım (Android)

| İşlem | Nasıl |
|---|---|
| Link eklemek | Alttaki alana yapıştırıp **+**, ya da tarayıcıda **Paylaş → Link Cepte** |
| Uzun metni .txt kaydetmek | Yapıştırıp **+** simgesine uzun basın |
| Aramak | Kelime yazıp **🔍** |
| Linki açmak | Satıra dokunun |
| Klasöre girmek / geri | Klasör satırına dokunun / sol üstteki ok |
| Yeni klasör | Üstteki klasör+ simgesi |
| Düzenlemek | Sağ üstteki kalem simgesi |
| Sıralamak | Düzenleme modunda ☰ tutamacından sürükleyin |
| Adını değiştirmek | Düzenleme modunda satırdaki kalem simgesi |
| Silmek | Düzenleme modunda işaretleyip çöp kutusuna basın (onay sorulmaz) |
| Taşımak | Düzenleme modunda işaretle → taşı simgesi → klasör seç → **Buraya taşı** |
| Klasörü değiştirmek | Sağ üst ⋮ menüsü → **Klasörü değiştir** |
| Yenilemek | Sağ üstteki ↻ simgesi |

Eski bir klasörü sonradan seçerseniz içindeki linkler, klasörler ve sıralama olduğu gibi gelir.

## Mac uygulaması ve Chrome eklentisi

Mac uygulaması aynı dosya biçimini kullanır; Android ve Mac, iCloud Drive, Syncthing, Google Drive gibi bir araçla eşitlenen tek klasörü paylaşabilir. Paylaş menüsü, Servisler menüsü ve sürükle-bırak desteği vardır. Ayrıntı: [`mac/README.md`](mac/README.md).

Chrome eklentisi araç çubuğuna bir düğme ekler: tıklayınca açık sekmenin linki doğrudan Mac uygulamasına gider. Ayrıntı: [`chrome-extension/README.md`](chrome-extension/README.md).

## Yedekleme

Ayrı bir yedekleme yoktur. Tüm veriniz seçtiğiniz klasördedir, o klasörü kopyalamanız yeterlidir. Klasörü Google Drive, Syncthing gibi bir uygulamayla eşleştirirseniz yedekleme ve cihazlar arası eşitleme kendiliğinden olur.

## Kurulum (APK'yı GitHub'da derleme)

Bilgisayara Android Studio kurmanız gerekmez.

1. Bu projeyi kendi GitHub deponuza yükleyin.
2. **Actions → Build APK → Run workflow** ile derlemeyi başlatın (`main` dalına her gönderimde de otomatik başlar).
3. Yeşil tik çıkınca çalışmanın sayfasından **Artifacts → LinkCepte-apk** dosyasını indirin.
4. Zip'ten çıkan `app-release.apk` dosyasını telefona aktarıp kurun. "Bilinmeyen kaynaklardan kurulum" izni isterse onaylayın.

Mac uygulaması için **Actions → Build Mac App** çalıştırıp **LinkCepte-mac** dosyasını indirin (ayrıntı: [`mac/README.md`](mac/README.md)).

**Not:** APK, GitHub'ın her derlemede ürettiği geçici bir anahtarla imzalanır. Yeni sürüm eskisinin üzerine kurulmazsa önce eskisini kaldırın. Linkleriniz klasörünüzde durduğu için bir şey kaybolmaz, aynı klasörü yeniden seçmeniz yeterlidir.

## Android Studio ile çalıştırma

1. **Open** ile proje klasörünü açın, Gradle senkronizasyonunu bekleyin.
2. Telefonu bağlayıp ▶ ile çalıştırın.

## Teknik bilgiler

- Kotlin + Jetpack Compose (Material 3), en düşük Android 7.0 (API 24)
- Depolama: Android Storage Access Framework; uygulamaya özel depolama veya geniş depolama izni gerekmez
- İzinler: yalnızca internet (sayfa başlığını almak için)
- Klasör içeriği tek sorguyla okunur, dosya işlemleri arka planda ve sıralı yapılır
- Derleme: R8 küçültme açık, yalnızca Türkçe ve İngilizce kaynaklar pakete girer

## Sınırlamalar

- Android'in kısıtladığı yerler (Download klasörünün kendisi, depolama kökü) seçilemez. Kendi açtığınız bir klasörü seçin.
- Sayfa başlığı linkin kendisinden alınır (en fazla birkaç saniye beklenir). Alınamazsa paylaşılan başlık, o da yoksa site adresi kullanılır. Giriş isteyen veya bot korumalı sitelerde başlık alınamayabilir.
- Aynı adda ikinci bir link kaydedilirse adına (2) eklenir.
