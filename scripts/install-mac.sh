#!/bin/sh
# Mac uygulamasını Release olarak derler ve /Applications/TaskTracker.app'e kurar.
#   scripts/install-mac.sh
# Çalışan uygulama kapatılır, kurulum sonrası yeniden açılır. Ayarlar (sunucu adresi,
# anahtar, kısayollar) UserDefaults'ta durur; kurulumdan etkilenmez.
set -eu

cd "$(dirname "$0")/../macos"
DEST="${TT_INSTALL_DIR:-/Applications}/TaskTracker.app"
BUILD="build/Build/Products/Release/TaskTracker.app"

command -v xcodegen >/dev/null || { echo "xcodegen yok: brew install xcodegen"; exit 1; }
command -v xcodebuild >/dev/null || { echo "Xcode gerekir"; exit 1; }

echo "→ proje üretiliyor"
xcodegen generate >/dev/null

echo "→ Release derlemesi (ilk seferde birkaç dakika)"
xcodebuild -project TaskTracker.xcodeproj -scheme TaskTracker -configuration Release \
    -derivedDataPath build build 2>&1 | grep -E 'error:|warning: .*deprecated|BUILD' || true
test -d "$BUILD" || { echo "derleme başarısız"; exit 1; }

if pgrep -x TaskTracker >/dev/null; then
    echo "→ çalışan uygulama kapatılıyor"
    osascript -e 'tell application "TaskTracker" to quit' 2>/dev/null || pkill -x TaskTracker || true
    for i in $(seq 1 20); do pgrep -x TaskTracker >/dev/null || break; sleep 0.5; done
fi

echo "→ kopyalanıyor: $DEST"
rm -rf "$DEST"
ditto "$BUILD" "$DEST"

open "$DEST"
cat <<EOF

kuruldu: $DEST
Sürüm: $(defaults read "$DEST/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo ?)
Oturum açılışında başlatma açıksa uygulama yeni konumunu ilk açılışta kendisi kaydeder.
EOF
