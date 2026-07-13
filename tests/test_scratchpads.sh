#!/usr/bin/env bash
# Parent compatibility entrypoint; the scratchpads module owns the test body.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODULE_TEST="$ROOT/modules/scratchpads/tests/test_scratchpads.sh"

if [[ ! -x "$MODULE_TEST" ]]; then
  printf 'Scratchpads module is absent; compatibility test skipped.\n'
  printf 'Results: 0 passed, 0 failed\n'
  exit 0
fi

exec "$MODULE_TEST" "$@"
