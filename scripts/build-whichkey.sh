#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/modules/shortcut-guide/install/build-whichkey.sh" "$@"
