# 🔗 Link Cepte

Favori linklerinizi telefonunuzda **kendi seçtiğiniz bir klasörde**, standart `.url` dosyaları olarak saklayan, sade ve hafif bir Android uygulaması.

Hesap yok, internet izni yok, reklam yok. Linkleriniz yalnızca sizin seçtiğiniz klasörde durur.

## Özellikler

- **Kendi klasörünüz:** İlk açılışta linklerin saklanacağı klasörü seçersiniz. Seçim hatırlanır.
- **Tek dokunuşla kaydetme:** Herhangi bir tarayıcıda **Paylaş → Link Cepte**'yi seçin. Uygulama açılmaz, yalnızca "Link kaydedildi" yazısı görünür ve link ana listeye eklenir.
- **Standart `.url` dosyaları:** Her link ayrı bir `.url` dosyasıdır, bilgisayarda da çalışır:
  ```
  [InternetShortcut]
  URL=https://ornek.com
  ```
- **Klasörler:** Linkleri alt klasörlerde düzenleyin.
- **Sıralama:** Yukarı/aşağı oklarıyla istediğiniz sıraya getirin. Sıra, her klasördeki gizli `.order.txt` dosyasında tutulur.
- **Ad değiştirme:** Kalem simgesiyle link veya klasör adını değiştirin.
- **Taşıma:** Bir linke uzun basıp birden fazla link seçin, taşı simgesiyle başka bir klasöre aktarın. Taşırken **yeni klasör** da oluşturabilirsiniz.
- **Yenile:** Üstteki yenile düğmesi listeyi yeniden okur. Uygulamaya her dönüşte liste kendiliğinden yenilenir.
- **Karanlık tema** ve güvenli silme (her silmede onay).

## Kullanım

| İşlem | Nasıl |
|---|---|
| Link eklemek | Tarayıcıda **Paylaş → Link Cepte** |
| Linki açmak | Satıra dokunun |
| Klasöre girmek | Klasör satırına dokunun, geri için sol üstteki ok |
| Yeni klasör | Üstteki klasör+ simgesi |
| Sıralamak | Satırdaki ▲ ▼ okları |
| Adını değiştirmek | Satırdaki kalem simgesi |
| Silmek | Satırdaki çöp kutusu (onay sorar) |
| Birden fazla seçmek | Bir linke uzun basın, diğerlerine dokunun |
| Taşımak | Seçtikten sonra üstteki taşı simgesi → klasör seç → **Buraya taşı** |
| Klasörü değiştirmek | Sağ üst ⋮ menüsü → **Klasörü değiştir** |

Eski bir klasörü sonradan seçerseniz içindeki linkler, klasörler ve sıralama olduğu gibi gelir.

## Yedekleme

Uygulamada ayrı bir yedekleme yoktur. Tüm veriniz seçtiğiniz klasördedir, o klasörü kopyalamanız yeterlidir. Klasörü Google Drive, Syncthing gibi bir senkronizasyon uygulamasıyla eşleştirirseniz yedekleme ve cihazlar arası eşitleme kendiliğinden olur.

## Kurulum (APK'yı GitHub'da derleme)

Bilgisayara Android Studio kurmanız gerekmez.

1. Bu projeyi kendi GitHub deponuza yükleyin.
2. Depoda **Actions → Build APK → Run workflow** ile derlemeyi başlatın (`main` dalına her gönderimde de otomatik başlar).
3. Derleme bitince (yeşil tik) çalışmanın sayfasındaki **Artifacts → LinkCepte-apk** dosyasını indirin.
4. Zip'ten çıkan `app-release.apk` dosyasını telefona aktarıp kurun. Telefon "bilinmeyen kaynaklardan kurulum" izni isterse onaylayın.

**Not:** APK, GitHub'ın her derlemede ürettiği geçici bir anahtarla imzalanır. Yeni bir sürümü eskisinin üzerine kurarken "uygulama yüklenemedi" derse önce eski sürümü kaldırın. Linkleriniz seçtiğiniz klasörde durduğu için bir şey kaybolmaz, yeniden kurulumdan sonra aynı klasörü seçmeniz yeterlidir.

## Android Studio ile çalıştırma

1. **Open** ile proje klasörünü açın, Gradle senkronizasyonunu bekleyin.
2. Telefonu bağlayıp ▶ ile çalıştırın.

## Teknik bilgiler

- Kotlin + Jetpack Compose (Material 3), en düşük Android sürümü 7.0 (API 24)
- Depolama: Android Storage Access Framework, uygulamaya özel depolama alanı veya geniş depolama izni gerekmez
- İzinler: yok (internet izni de yok)
- Klasör içeriği tek sorguyla okunur, tüm dosya işlemleri arka planda ve sıralı yapılır
- Derleme: R8 ile kod ve kaynak küçültme açık, yalnızca Türkçe ve İngilizce kaynaklar pakete girer

## Sınırlamalar

- Android'in kısıtladığı yerler (Download klasörünün kendisi, depolama kökü) seçilemez. Kendi açtığınız bir klasörü seçin.
- Linkin sayfa başlığı, tarayıcının paylaştığı başlıktan alınır. Başlık gelmezse site adresi kullanılır.
- Aynı adda ikinci bir link kaydedilirse adına (2) eklenir.
