#!/bin/bash
set -euo pipefail

APP_NAME="Grafana Scope"
LABEL="com.grafana.scope"
CONFIG_ROOT="$HOME/Library/Application Support/Grafana_Scope"
APP_DEST="$HOME/Applications/$APP_NAME.app"
LEGACY_APP_DEST="$CONFIG_ROOT/$APP_NAME.app"
PLIST_PATH="$HOME/Library/LaunchAgents/${LABEL}.plist"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

pkill -f "$APP_DEST/Contents/MacOS" 2>/dev/null || true
pkill -f "$LEGACY_APP_DEST/Contents/MacOS" 2>/dev/null || true

launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
rm -f "$PLIST_PATH"

if [[ -x "$APP_DEST/Contents/MacOS/$APP_NAME" ]]; then
  "$APP_DEST/Contents/MacOS/$APP_NAME" --unregister-login 2>/dev/null || true
fi

for path in "$APP_DEST" "$LEGACY_APP_DEST"; do
  if [[ -d "$path" ]]; then
    "$LSREGISTER" -u -r "$path" 2>/dev/null || true
    rm -rf "$path"
  fi
done

rm -rf "$CONFIG_ROOT"

echo "Grafana Scope uninstalled."
echo ""
echo "If it still appears in System Settings → Login Items, turn it off manually."
