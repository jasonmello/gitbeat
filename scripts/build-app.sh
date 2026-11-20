#!/bin/zsh
# Compila em release e monta build/GitBeat.app (não precisa do Xcode).
# Uso: scripts/build-app.sh                      → só monta
#      scripts/build-app.sh --install            → copia para /Applications
#      scripts/build-app.sh --notarize           → assina com Developer ID, notariza e gera build/GitBeat.zip
#      (as opções podem ir juntas, em qualquer ordem)
# Assinatura: usa o certificado "Developer ID Application" do Keychain, se existir
# (ou o nome em GITBEAT_SIGN_ID); sem ele, assina só localmente (ad hoc).
# Notarização: perfil "gitbeat-notary" do notarytool (ou GITBEAT_NOTARY_PROFILE).
# Passo a passo em docs/distribuicao.md.
set -euo pipefail
cd "$(dirname "$0")/.."

INSTALL=0; NOTARIZE=0
for arg in "$@"; do
  case "$arg" in
    --install) INSTALL=1 ;;
    --notarize) NOTARIZE=1 ;;
    *) echo "Opção desconhecida: $arg" >&2; exit 2 ;;
  esac
done

SIGN_ID="${GITBEAT_SIGN_ID:-$(security find-identity -v -p codesigning 2>/dev/null \
  | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' | head -1)}"
NOTARY_PROFILE="${GITBEAT_NOTARY_PROFILE:-gitbeat-notary}"
if [[ $NOTARIZE == 1 && -z "$SIGN_ID" ]]; then
  echo "Sem certificado Developer ID no Keychain: não dá para notarizar. Veja docs/distribuicao.md." >&2
  exit 1
fi

APP=build/GitBeat.app
swift build -c release --product GitBeat
BIN="$(swift build -c release --show-bin-path)/GitBeat"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/GitBeat"

# Recursos da marca (ícone do kit do mascote, logos, barra de menu, animações): Resources/ → Contents/Resources
cp -R Resources/. "$APP/Contents/Resources/"

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

if [[ -n "$SIGN_ID" ]]; then
  # Runtime endurecido + carimbo de hora: exigidos pela notarização.
  codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$APP"
  codesign --verify --strict --verbose=2 "$APP"
  echo "Assinado com: $SIGN_ID"
else
  codesign --force --sign - "$APP" >/dev/null   # assinatura local (ad hoc)
  echo "Assinado só localmente (sem Developer ID no Keychain)."
fi

if [[ $NOTARIZE == 1 ]]; then
  ZIP=build/GitBeat.zip
  rm -f "$ZIP"
  ditto -c -k --keepParent "$APP" "$ZIP"
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  spctl --assess --type execute --verbose=2 "$APP"
  rm -f "$ZIP"
  ditto -c -k --keepParent "$APP" "$ZIP"   # zip final já com o ticket grampeado
  echo "Notarizado: $APP e $ZIP"
fi
echo "Pronto: $APP"

if [[ $INSTALL == 1 ]]; then
  rm -rf "/Applications/GitBeat.app"
  cp -R "$APP" /Applications/
  echo "Instalado em /Applications/GitBeat.app"
fi
