#!/bin/bash
set -euo pipefail

CONFIG_ROOT="$HOME/Library/Application Support/Grafana_Scope"
CONFIG="$CONFIG_ROOT/config.json"
BACKUP="$CONFIG_ROOT/config.json.backup"

if [[ ! -f "$BACKUP" ]]; then
  echo "No backup found at: $BACKUP"
  echo ""
  echo "If you still have real instances, re-add them in Settings → Instances."
  echo "Or delete config.json and restart the app to try legacy migration:"
  echo "  rm \"$CONFIG\""
  exit 1
fi

cp "$BACKUP" "$CONFIG"
echo "Restored: $CONFIG"
echo "Restart Grafana Scope to load your instances."
