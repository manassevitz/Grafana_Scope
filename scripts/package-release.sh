#!/bin/bash
set -euo pipefail
exec "$(cd "$(dirname "$0")/.." && pwd)/GrafanaScope/scripts/package-release.sh" "$@"
