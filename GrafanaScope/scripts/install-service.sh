#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP_NAME="Grafana Scope"
BUNDLE_ID="com.grafana.scope"
LABEL="com.grafana.scope"
CONFIG_ROOT="$HOME/Library/Application Support/Grafana_Scope"
APP_DEST="$HOME/Applications/$APP_NAME.app"
LEGACY_APP_DEST="$CONFIG_ROOT/$APP_NAME.app"
PLIST_PATH="$HOME/Library/LaunchAgents/${LABEL}.plist"
LOG_PATH="$HOME/Library/Logs/grafana-scope.log"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "macOS only."
  exit 1
fi

"$ROOT/GrafanaScope/scripts/build.sh"

pkill -f "$APP_DEST/Contents/MacOS" 2>/dev/null || true
pkill -f "$LEGACY_APP_DEST/Contents/MacOS" 2>/dev/null || true

launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
rm -f "$PLIST_PATH"

mkdir -p "$HOME/Applications" "$CONFIG_ROOT" "$(dirname "$LOG_PATH")"
rm -rf "$APP_DEST" "$LEGACY_APP_DEST"
ditto "$ROOT/build/$APP_NAME.app" "$APP_DEST"

EXECUTABLE="$APP_DEST/Contents/MacOS/$APP_NAME"
"$LSREGISTER" -f -R -trusted "$APP_DEST" 2>/dev/null || true

if ! "$EXECUTABLE" --register-login; then
  echo "Warning: could not register login item automatically."
  echo "Open Settings → General → Launch at login after starting the app."
fi

nohup "$EXECUTABLE" >/dev/null 2>&1 &

echo "Installed: $APP_DEST"
echo "Config: $CONFIG_ROOT/config.json"
echo "Logs: $LOG_PATH"
echo ""
echo "If an old Login Item still shows a generic exec icon, remove it in"
echo "System Settings → General → Login Items, then enable Launch at login"
echo "inside Grafana Scope Settings."
