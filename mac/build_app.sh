#!/bin/bash
# Link Cepte Mac uygulamasını derler: mac/build/LinkCepte.app ve mac/build/LinkCepte-mac.zip
set -euo pipefail
cd "$(dirname "$0")"

APP="build/LinkCepte.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Evrensel (Apple Silicon + Intel) derleme
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/LinkCepte"
cp "$BIN" "$APP/Contents/MacOS/LinkCepte"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Sistem menülerinin Türkçe görünmesi için dil klasörleri
mkdir -p "$APP/Contents/Resources/tr.lproj" "$APP/Contents/Resources/en.lproj"

# İkon
ICONSET="build/AppIcon.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

# Paylaş eklentisi (Safari Paylaş menüsü). Derlenemezse uygulama eklentisiz devam eder.
if bash ./build_share.sh "$APP"; then
  echo "Paylaş eklentisi eklendi"
else
  echo "UYARI: Paylaş eklentisi derlenemedi, uygulama eklentisiz hazırlanıyor"
  rm -rf "$APP/Contents/PlugIns"
fi

# Geçici (ad-hoc) imza: Apple Developer hesabı gerekmez (--deep yok: eklentinin kendi imzası korunur)
codesign --force --sign - "$APP"

ditto -c -k --keepParent "$APP" build/LinkCepte-mac.zip
echo "Hazır: $(pwd)/$APP"
