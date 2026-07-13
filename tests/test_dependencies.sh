#!/usr/bin/env bash
# Parent entrypoint for the module-owned dependency inventory tests.
set -euo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$TEST_DIR/../modules/dependencies/tests/test_dependencies.sh" "$@"
