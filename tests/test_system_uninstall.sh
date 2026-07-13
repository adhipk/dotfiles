#!/usr/bin/env bash
# Parent entrypoint for the module-owned whole-system uninstall tests.
set -euo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$TEST_DIR/../modules/system-uninstall/tests/test_system_uninstall.sh" "$@"
