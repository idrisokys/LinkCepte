#!/bin/bash
# Paylaş eklentisini derleyip uygulamanın içine koyar. Kullanım: build_share.sh <LinkCepte.app>
set -euo pipefail
cd "$(dirname "$0")"
APP="$1"
X="$APP/Contents/PlugIns/LinkCepteShare.appex"
mkdir -p "$X/Contents/MacOS" build

for a in arm64 x86_64; do
  swiftc -parse-as-library -O -module-name LinkCepteShare \
    -target "${a}-apple-macos13.0" -framework AppKit \
    -Xlinker -e -Xlinker _NSExtensionMain \
    ShareExtension/ShareViewController.swift -o "build/share-$a"
done
lipo -create build/share-arm64 build/share-x86_64 -output "$X/Contents/MacOS/LinkCepteShare"
cp ShareExtension/Info.plist "$X/Contents/Info.plist"
codesign --force --sign - --entitlements ShareExtension/Share.entitlements "$X"
