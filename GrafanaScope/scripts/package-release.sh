#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DIST="$ROOT/dist"
APP_NAME="Grafana Scope"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/GrafanaScope/GrafanaScope/Info.plist")"
ARCH="$(uname -m)"
ZIP_NAME="Grafana-Scope-${VERSION}-macos-${ARCH}.zip"

"$ROOT/GrafanaScope/scripts/build.sh"

mkdir -p "$DIST"
rm -f "$DIST/$ZIP_NAME"
ditto -c -k --sequesterRsrc --keepParent "$ROOT/build/$APP_NAME.app" "$DIST/$ZIP_NAME"

echo "Release zip: $DIST/$ZIP_NAME"
echo "Upload to GitHub Releases (attach this zip to the matching version tag)."
