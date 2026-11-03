# 🔗 Link Cepte — Chrome eklentisi

**Türkçe** · [English](#english)

Chrome araç çubuğundaki simgeye tıklayınca açık sekmenin linki Mac'teki **Link Cepte** uygulamasına kaydedilir.
Başlık otomatik alınır; link, uygulamada seçtiğiniz klasöre `.url` dosyası olarak yazılır.

> Bu klasör **Link Cepte Mac uygulamasının içinde** gelir. Uygulamanın üst araç çubuğundaki **Chrome simgesine**
> tıklayınca bu klasör Finder'da kendiliğinden açılır.

## Kurulum (yaklaşık 1 dakika)

**1. Uygulamayı hazırlayın**
Link Cepte'yi **Uygulamalar** klasörüne taşıyıp bir kez açın ve linklerin kaydedileceği klasörü seçin.
(Bu adım, Chrome'un kullandığı `linkcepte://` adresini sisteme tanıtır.)

**2. Eklenti klasörünü açın**
Uygulamanın üst araç çubuğundaki **Chrome simgesine** tıklayın (veya menü çubuğundan
**Link → Chrome Eklentisi Klasörünü Aç**). Finder'da bu klasör açılır.

Klasör şu konumda durur:
`~/Library/Application Support/Link Cepte/chrome-extension`

**3. Chrome'da Geliştirici modunu açın**
Chrome'un adres çubuğuna `chrome://extensions` yazıp Enter'a basın. Sağ üstteki **Geliştirici modu** düğmesini açın.

**4. Eklentiyi yükleyin**
**Paketlenmemiş öğe yükle** (Load unpacked) düğmesine basın. Açılan pencerede **⌘ ⇧ G** tuşlarına basıp
yukarıdaki yolu yapıştırın (`~/Library/Application Support/Link Cepte/chrome-extension`), Enter'a basın ve
**Seç**'e tıklayın. Listede **Link Cepte** görünür.

**5. Simgeyi araç çubuğuna sabitleyin**
Chrome araç çubuğundaki yapboz simgesine (Eklentiler) tıklayın, **Link Cepte**'nin yanındaki iğneye basın.

## İlk kullanım

Bir sayfadayken Link Cepte simgesine tıklayın. Chrome ilk seferde *"Link Cepte'yi açmak istiyor musunuz?"* diye sorar.
**"Her zaman … bağlantıları ilişkili uygulamada açabilir"** kutusunu işaretleyip **Aç**'a basın; sonraki tıklamalarda sormaz.

Başarılı gönderimde simgede kısa süre **✓**, gönderilemeyen sayfalarda **!** görünür.

## Nasıl kullanılır

- **Araç çubuğu simgesi:** Açık sekmeyi gönderir.
- **Sağ tık menüsü:** Sayfaya sağ tıklayıp **Link Cepte'ye gönder**; bir linke sağ tıklayıp **Linki Link Cepte'ye gönder**.
- Yalnızca `http` ve `https` sayfaları gönderilir (`chrome://` gibi iç sayfalar gönderilemez, **!** görünür).
- Uygulama kapalıysa link gönderilirken uygulama açılır. Klasör seçilmemişse önce klasörü seçmeniz istenir.

## Güncelleme

Link Cepte uygulamasını yeni sürümle değiştirdikten sonra uygulamadaki **Chrome simgesine** bir kez daha tıklayın
(klasör güncellenir), sonra `chrome://extensions` sayfasında **Link Cepte** kartındaki **↻ (yeniden yükle)** düğmesine basın.
Eklentiyi yeniden kurmanız gerekmez.

## Sorun giderme

| Sorun | Çözüm |
|---|---|
| Simgeye tıklayınca hiçbir şey olmuyor | Link Cepte uygulamasını **Uygulamalar** klasöründen bir kez açın, sonra tekrar deneyin. |
| Chrome "Link Cepte'yi açmak istiyor musunuz?" diye hep soruyor | Çıkan pencerede "her zaman izin ver" kutusunu işaretleyin. |
| `chrome://extensions` içinde "Paketlenmemiş öğe yükle" yok | Sağ üstten **Geliştirici modu**'nu açın. |
| Eklenti "Manifest dosyası eksik" diyor | Seçtiğiniz klasörün içinde `manifest.json` olmalı. Klasörü **içine girmeden** seçin (yol `…/chrome-extension` ile bitmeli). |

## Kaldırma

`chrome://extensions` sayfasında **Link Cepte** kartındaki **Kaldır**'a basın. İsterseniz
`~/Library/Application Support/Link Cepte/chrome-extension` klasörünü de silebilirsiniz (linkleriniz etkilenmez).

---

<a name="english"></a>

# 🔗 Link Cepte — Chrome extension (English)

Click the toolbar icon in Chrome to save the current tab's link to the **Link Cepte** Mac app. The page title is fetched
automatically and the link is written as a `.url` file into the folder you chose in the app.

> This folder is **bundled inside the Link Cepte Mac app**. Click the **Chrome icon** in the app's top toolbar and this
> folder opens in Finder.

## Install (about 1 minute)

**1. Prepare the app**
Move Link Cepte to **Applications**, open it once and choose the folder where links will be saved.
(This registers the `linkcepte://` address Chrome uses.)

**2. Open the extension folder**
Click the **Chrome icon** in the app's top toolbar (or use **Link → Open Chrome Extension Folder** in the menu bar).
The folder opens in Finder. It lives at:
`~/Library/Application Support/Link Cepte/chrome-extension`

**3. Turn on Developer mode in Chrome**
Type `chrome://extensions` in the address bar and press Enter. Switch on **Developer mode** (top right).

**4. Load the extension**
Click **Load unpacked**. In the dialog press **⌘ ⇧ G**, paste the path above
(`~/Library/Application Support/Link Cepte/chrome-extension`), press Enter, then click **Select**.
**Link Cepte** now appears in the list.

**5. Pin the icon**
Click the puzzle-piece (Extensions) icon in Chrome's toolbar and pin **Link Cepte**.

## First use

Click the Link Cepte icon on any page. Chrome asks *"Open Link Cepte?"* the first time. Tick
**"Always allow … to open links of this type in the associated app"** and click **Open**; it won't ask again.

A **✓** appears briefly on the icon on success, and **!** if the page can't be sent.

## Usage

- **Toolbar icon:** sends the current tab.
- **Right-click menu:** right-click a page → **Send to Link Cepte**; right-click a link → **Send link to Link Cepte**.
- Only `http` and `https` pages can be sent (internal pages such as `chrome://` show **!**).
- If the app is closed it is launched with the link. If no folder is chosen yet, you'll be asked to choose one first.

## Updating

After replacing the Link Cepte app with a newer version, click the app's **Chrome icon** once more (this refreshes the
folder), then press the **↻ (reload)** button on the **Link Cepte** card at `chrome://extensions`. No reinstall needed.

## Troubleshooting

| Problem | Fix |
|---|---|
| Nothing happens when I click the icon | Open Link Cepte once from the **Applications** folder, then try again. |
| Chrome keeps asking "Open Link Cepte?" | Tick the "always allow" box in the prompt. |
| No **Load unpacked** button | Turn on **Developer mode** at the top right of `chrome://extensions`. |
| "Manifest file is missing" | The selected folder must contain `manifest.json`. Select the folder itself (the path must end with `…/chrome-extension`). |

## Uninstall

Click **Remove** on the **Link Cepte** card at `chrome://extensions`. You may also delete
`~/Library/Application Support/Link Cepte/chrome-extension` (your links are not affected).
