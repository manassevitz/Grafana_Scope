#!/bin/bash
set -euo pipefail

APP_NAME="Grafana Scope"
BUNDLE_ID="com.grafana.scope"
REPO="${GRAFANA_SCOPE_REPO:-manassevitz/Grafana_Scope}"
VERSION="${1:-latest}"
CONFIG_ROOT="$HOME/Library/Application Support/Grafana_Scope"
APP_DEST="$HOME/Applications/$APP_NAME.app"
STAGING="$(mktemp -d)"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

cleanup() {
  rm -rf "$STAGING"
}
trap cleanup EXIT

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "macOS only."
  exit 1
fi

api_url="https://api.github.com/repos/${REPO}/releases/${VERSION}"
release_json="$(curl -fsSL "$api_url")"
asset_url="$(python3 -c "
import json, sys
release = json.load(sys.stdin)
assets = [a for a in release.get('assets', []) if a['name'].endswith('.zip')]
if not assets:
    raise SystemExit('No .zip asset found on this release.')
print(assets[0]['browser_download_url'])
" <<<"$release_json")"

zip_path="$STAGING/download.zip"
echo "Downloading: $asset_url"
curl -fsSL -o "$zip_path" "$asset_url"
ditto -x -k "$zip_path" "$STAGING"

app_path="$(find "$STAGING" -maxdepth 3 -name "$APP_NAME.app" -type d | head -1)"
if [[ -z "$app_path" ]]; then
  echo "Could not find $APP_NAME.app inside the release zip."
  exit 1
fi

pkill -f "$APP_DEST/Contents/MacOS" 2>/dev/null || true
mkdir -p "$HOME/Applications"
rm -rf "$APP_DEST"
ditto "$app_path" "$APP_DEST"

EXECUTABLE="$APP_DEST/Contents/MacOS/$APP_NAME"
"$LSREGISTER" -f -R -trusted "$APP_DEST" 2>/dev/null || true

if ! "$EXECUTABLE" --register-login; then
  echo "Warning: could not register login item automatically."
  echo "Enable Launch at login in Settings → General after starting the app."
fi

nohup "$EXECUTABLE" >/dev/null 2>&1 &

echo "Installed: $APP_DEST"
echo "Config: $CONFIG_ROOT/config.json"
