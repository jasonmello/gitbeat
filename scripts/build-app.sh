#!/bin/zsh
# Compila em release e monta build/GitBeat.app (não precisa do Xcode).
# Uso: scripts/build-app.sh            → só monta
#      scripts/build-app.sh --install  → copia para /Applications
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/GitBeat.app
swift build -c release --product GitBeat
BIN="$(swift build -c release --show-bin-path)/GitBeat"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/GitBeat"

# Ícone: o próprio app desenha a marca (brand/) em 1024×1024 → .iconset → .icns
TMP=$(mktemp -d)
"$BIN" --render-icon "$TMP/icon.png"
mkdir "$TMP/AppIcon.iconset"
for s in 16 32 128 256 512; do
  sips -z $s $s "$TMP/icon.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$TMP/icon.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$TMP/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$TMP"

VERSION=$(git describe --tags --always 2>/dev/null || echo "0.1.0")
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>GitBeat</string>
  <key>NSHumanReadableCopyright</key><string>Proudly developed by Jason Mello</string>
  <key>CFBundleDisplayName</key><string>GitBeat</string>
  <key>CFBundleIdentifier</key><string>dev.gitbeat.app</string>
  <key>CFBundleExecutable</key><string>GitBeat</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null   # assinatura local (ad hoc)
echo "Pronto: $APP"

if [[ "${1:-}" == "--install" ]]; then
  rm -rf "/Applications/GitBeat.app"
  cp -R "$APP" /Applications/
  echo "Instalado em /Applications/GitBeat.app"
fi
