#!/bin/bash
set -euo pipefail

CONFIG_ROOT="$HOME/Library/Application Support/Grafana_Scope"
CONFIG="$CONFIG_ROOT/config.json"
BACKUP="$CONFIG_ROOT/config.json.backup"
EXAMPLE="$(cd "$(dirname "$0")/../.." && pwd)/config.example.json"

mkdir -p "$CONFIG_ROOT"

if [[ -f "$CONFIG" ]]; then
  cp "$CONFIG" "$BACKUP"
  echo "Backup saved: $BACKUP"
fi

cp "$EXAMPLE" "$CONFIG"
echo "Demo config installed: $CONFIG"
echo "Restart Grafana Scope to load example instances."
echo ""
echo "To restore your previous config:"
echo "  ./GrafanaScope/scripts/restore-config-backup.sh"
