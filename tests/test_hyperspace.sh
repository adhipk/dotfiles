#!/usr/bin/env bash
# Optional parent entrypoint for the module-owned Hyperspace tests.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODULE="$ROOT/modules/hyperspace"
if [[ ! -d "$MODULE" ]]; then
  echo "Hyperspace module absent; parent tests remain valid."
  exit 0
fi

exec "$MODULE/tests/test_module.sh"
