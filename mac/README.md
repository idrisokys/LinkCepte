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
(seçme, ad değiştirme, taşıma + yeni klasör, sürükleyerek sıralama), karanlık/açık tema (sistemi izler).

## Mac'e özgü farklar

| Android | Mac |
|---|---|
| Paylaş → Link Cepte | **Servisler** menüsü → *Link Cepte’ye Ekle* (seçili link/metin için, herhangi bir uygulamada) ve bir linki **pencereye sürükleyip bırakma** |
| Uzun bas: `.txt` | `+` düğmesine uzun bas **veya ⌥ ile tıkla**, ya da ⇧⌘↩ |
| Silme onaysız, kalıcı | **Çöp Kutusu'na** taşınır (geri alınabilir) |
| Klasör kısıtları (Download vb.) | Yok; yazılabilir her klasör seçilebilir |
| Dokunmatik sürükleme tutamacı | Düzenleme modunda satırı doğrudan sürükleyin |

Klavye: ⌘↩ ekle, ⌘F ara, ⌘E düzenle, ⌘R yenile, ⌘[ geri, ⇧⌘N yeni klasör, ⌘O klasörü değiştir, Esc geri/çık.

**Servisler menüsü notu:** Yeni bir uygulama Servisler'de hemen görünmeyebilir. Uygulamayı **Uygulamalar** klasörüne
koyup bir kez açın; görünmezse oturumu kapatıp açın veya Sistem Ayarları → Klavye → Klavye Kısayolları → Servisler
bölümünden *Link Cepte’ye Ekle* kutusunu işaretleyin.
