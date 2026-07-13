#!/usr/bin/env bash
# Parent entrypoint for the module-owned lifecycle contract tests.
set -euo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$TEST_DIR/../modules/module-lifecycle/tests/test_module_lifecycle.sh" "$@"
