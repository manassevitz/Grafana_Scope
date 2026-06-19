#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/GrafanaScope/GrafanaScope"
BUILD="$ROOT/build"
APP="$BUILD/Grafana Scope.app"
SDK="$(xcrun --show-sdk-path)"
ARCH="$(uname -m)"
TARGET="${ARCH}-apple-macos13.0"

mkdir -p "$BUILD"

python3 "$(dirname "$0")/generate-icons.py"

SWIFT_FILES=(
  "$SRC/GrafanaScopeApp.swift"
  "$SRC/AppModel.swift"
  "$SRC/Models/Models.swift"
  "$SRC/Services/ConfigStore.swift"
  "$SRC/Services/GrafanaClient.swift"
  "$SRC/Views/AlertsView.swift"
  "$SRC/Views/SettingsWindowView.swift"
  "$SRC/Views/AboutView.swift"
  "$SRC/Views/Helpers.swift"
  "$SRC/Views/MenuBarLabelView.swift"
)

swiftc \
  -O \
  -sdk "$SDK" \
  -target "$TARGET" \
  -parse-as-library \
  -framework ServiceManagement \
  -o "$BUILD/GrafanaScope" \
  "${SWIFT_FILES[@]}"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BUILD/GrafanaScope" "$APP/Contents/MacOS/Grafana Scope"
cp "$SRC/Info.plist" "$APP/Contents/Info.plist"
cp "$SRC/Resources/"*.png "$APP/Contents/Resources/"

ICON="$SRC/Resources/AppIcon.png"
ICONSET="$BUILD/AppIcon.iconset"
mkdir -p "$ICONSET"

sips -z 16 16 "$ICON" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON" --out "$ICONSET/icon_512x512@2x.png" >/dev/null

iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

printf 'APPL????' > "$APP/Contents/PkgInfo"

/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconName string AppIcon" "$APP/Contents/Info.plist" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Set :CFBundleIconName AppIcon" "$APP/Contents/Info.plist"

chmod +x "$APP/Contents/MacOS/Grafana Scope"
codesign --force --sign - --identifier com.grafana.scope "$APP/Contents/MacOS/Grafana Scope"
codesign --force --deep --sign - --identifier com.grafana.scope "$APP"

echo "Built: $APP"
