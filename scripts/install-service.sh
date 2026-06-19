#!/bin/bash
set -euo pipefail
exec "$(cd "$(dirname "$0")" && pwd)/GrafanaScope/scripts/install-service.sh" "$@"
