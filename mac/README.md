# 🔗 Link Cepte — Mac sürümü

Android uygulamasının SwiftUI ile yeniden yazılmış Mac karşılığı. **Aynı dosya biçimini** kullanır
(`.url` dosyaları, metin notları için `TEXT=` satırı, `.txt` dosyaları, her klasörde gizli `.order.txt`),
bu yüzden Android'de ve Mac'te **aynı klasörü** (iCloud Drive, Syncthing, Drive vb. ile eşitleyerek) kullanabilirsiniz.

## Kurulum (GitHub'da derleme)

1. Projeyi GitHub deponuza yükleyin (`mac/` klasörü ve `.github/workflows/build-mac.yml` dahil).
2. **Actions → Build Mac App → Run workflow**.
3. Bitince **Artifacts → LinkCepte-mac** dosyasını indirin, zip'ten çıkan `LinkCepte.app`'i **Uygulamalar** klasörüne taşıyın.
4. İlk açılışta macOS "doğrulanamadı" derse: uygulamaya sağ tık → **Aç**, ya da Terminal'de
   `xattr -cr /Applications/LinkCepte.app`

Kendi Mac'inizde derlemek isterseniz (Xcode veya Command Line Tools kuruluyken): `bash mac/build_app.sh`
(Xcode'da `mac/Package.swift` dosyasını da açıp ▶ ile çalıştırabilirsiniz.)

## Android ile aynı olanlar

Klasör seçimi, alttan link/metin ekleme (başlığı otomatik alma, 220 karakter sınırı, uzun metin → `.txt`),
arama (Türkçe i/ı ve aksan duyarsız, tüm kelimeler geçmeli), klasörler, düzenleme modu
(seçme, taşıma + yeni klasör, sürükleyerek sıralama), karanlık/açık tema (sistemi izler).

**Ad değiştirme:** Düzenleme modunda tek bir öğe seçince adı alttaki geniş alanda belirir; değiştirip (ya da yapıştırıp)
Yapıştır simgesinin yanındaki 💾 **Kaydet** simgesine basın (⌘S). Satırlarda ayrıca kalem simgesi yoktur.

**Metin dosyaları (.txt):** Bir `.txt` dosyasına tıklayınca tüm pencerede açılır. Sağ üstteki **kalem** simgesiyle (⌘E)
düzenleyin, 💾 **Kaydet** simgesiyle (⌘S) kaydedip okuma görünümüne dönün. Kaydedilmemiş değişiklik varken geri çıkarsanız
kaydetmek isteyip istemediğiniz sorulur. Dosya adı değişmez, yalnızca içerik güncellenir.

**Diller:** Cihazın birinci dili Türkçe ise uygulama Türkçe, değilse İngilizce çalışır.

**Yenile:** Araç çubuğunun en sağındaki ↻ simgesi (veya ⌘R) kayıtlı klasörü yeniden tarar.

## Mac'e özgü farklar

| Android | Mac |
|---|---|
| Paylaş → Link Cepte | Safari'de **Paylaş** düğmesi → *Link Cepte* (deneysel, aşağıya bakın); ayrıca **Servisler** menüsü → *Link Cepte’ye Ekle* ve bir linki **pencereye sürükleyip bırakma** |
| Uzun bas: `.txt` | `+` düğmesine uzun bas **veya ⌥ ile tıkla**, ya da ⇧⌘↩ |
| Silme onaysız, kalıcı | **Çöp Kutusu'na** taşınır (geri alınabilir) |
| Klasör kısıtları (Download vb.) | Yok; yazılabilir her klasör seçilebilir |
| Dokunmatik sürükleme tutamacı | Düzenleme modunda satırı doğrudan sürükleyin |

Klavye: ⌘↩ ekle, ⌘F ara, ⌘E düzenle (`.txt` açıkken metni düzenler), ⌘S kaydet (ad değiştirme / `.txt`), ⌘R yenile, ⌘[ geri, ⇧⌘N yeni klasör, ⌘O klasörü değiştir, Esc geri/çık.

**Servisler menüsü notu:** Yeni bir uygulama Servisler'de hemen görünmeyebilir. Uygulamayı **Uygulamalar** klasörüne
koyup bir kez açın; görünmezse oturumu kapatıp açın veya Sistem Ayarları → Klavye → Klavye Kısayolları → Servisler
bölümünden *Link Cepte’ye Ekle* kutusunu işaretleyin.

## Safari ve Chrome Paylaş menüsü (deneysel)

Uygulamayı **Uygulamalar** klasörüne taşıyıp **bir kez açın**. Sonra Safari'de Paylaş düğmesine basın.
Chrome'da tek tıkla göndermek için eklenti **uygulamanın içinde** gelir: üst araç çubuğundaki **Chrome simgesine** tıklayın, eklenti klasörü Finder'da açılır (içindeki `README.md` Chrome'a kurulumu adım adım anlatır; menü çubuğunda **Link → Chrome Eklentisi Klasörünü Aç** de aynı işi yapar).
*Link Cepte* listede yoksa: Paylaş menüsünün altındaki **Eklentileri Düzenle…** (veya Sistem Ayarları →
Gizlilik ve Güvenlik → Eklentiler → Paylaşım) bölümünden *Link Cepte* kutusunu işaretleyin.
Eklenti imzasız (geçici imzalı) olduğu için macOS bunu engelleyebilir; çalışmazsa Servisler menüsü ve
sürükle-bırak yolları yine kullanılabilir.

---

# Link Cepte — Mac version (English)

A SwiftUI rewrite of the Android app. It uses the **same file format** (`.url` files, `TEXT=` notes, `.txt`, hidden `.order.txt`),
so Android and Mac can share one synced folder. The app runs in English unless the device's first language is Turkish.
The ↻ button at the far right of the toolbar (or ⌘R) rescans the saved folder.
Rename: in edit mode select a single item, change its name in the bottom field and press the 💾 Save icon (⌘S).
Text files: clicking a `.txt` opens it in the whole window; the pencil (⌘E) edits, the 💾 Save icon (⌘S) saves and returns to reading.
Share: Safari's Share button, Chrome's *File → Share*, the Services menu, or drag a link into the window.
Chrome: the extension is bundled in the app. Click the **Chrome icon** in the top toolbar to open its folder in Finder; the `README.md` inside explains how to add it to Chrome.
