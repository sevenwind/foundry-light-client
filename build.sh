#!/bin/bash
# Собирает Foundry Lite.app рядом со скриптом
set -e
cd "$(dirname "$0")"
VERSION="${VERSION:-1.0}"
swift build -c release
APP="Foundry Lite.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/FoundryLite "$APP/Contents/MacOS/FoundryLite"

ICONS=$(mktemp -d)/AppIcon.iconset
swift tools/make_icon.swift "$ICONS"
# iconutil ждёт имена icon_16x16.png и т.д.
for pair in "16:16x16" "16x2:16x16@2x" "32:32x32" "32x2:32x32@2x" "128:128x128" "128x2:128x128@2x" "256:256x256" "256x2:256x256@2x" "512:512x512" "512x2:512x512@2x"; do
  mv "$ICONS/icon_${pair%%:*}.png" "$ICONS/icon_${pair##*:}.png"
done
iconutil -c icns "$ICONS" -o "$APP/Contents/Resources/AppIcon.icns"

# ATS: серверы Foundry обычно работают по http без сертификата
cat > "$APP/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Foundry Lite</string>
<key>CFBundleDisplayName</key><string>Foundry Lite</string>
<key>CFBundleIdentifier</key><string>local.foundrylite.app</string>
<key>CFBundleExecutable</key><string>FoundryLite</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSAppTransportSecurity</key><dict>
<key>NSAllowsArbitraryLoads</key><true/>
<key>NSAllowsArbitraryLoadsInWebContent</key><true/>
</dict>
<key>NSLocalNetworkUsageDescription</key><string>Подключение к серверам Foundry в локальной сети</string>
<key>NSCameraUsageDescription</key><string>Видеосвязь в игре Foundry</string>
<key>NSMicrophoneUsageDescription</key><string>Голосовая связь в игре Foundry</string>
</dict></plist>
PL
codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Готово: $PWD/$APP"
