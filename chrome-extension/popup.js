// Araç çubuğundaki simgeye tıklanınca açık sekmenin adresini Mac uygulamasına
// linkcepte://add?t=... adresiyle iletir (Paylaş eklentisiyle aynı yöntem).
const msg = document.getElementById('msg');
const sub = document.getElementById('sub');

(async () => {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  const url = tab && tab.url;
  if (!url || !/^https?:\/\//i.test(url)) {
    msg.textContent = 'Bu sayfa gönderilemez';
    sub.textContent = 'Yalnızca http/https adresleri desteklenir.';
    setTimeout(() => window.close(), 1800);
    return;
  }
  // Mac tarafındaki ShareViewController ile aynı kodlama
  const enc = encodeURIComponent(url).replace(/[!'()*]/g, c => '%' + c.charCodeAt(0).toString(16).toUpperCase());
  window.location.href = 'linkcepte://add?t=' + enc;
  msg.textContent = 'Link Cepte’ye gönderildi ✓';
  sub.textContent = tab.title || '';
  setTimeout(() => window.close(), 1200);
})();
