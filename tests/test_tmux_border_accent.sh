#!/usr/bin/env bash

set -euo pipefail

MODULE_TEST_DIR="$(cd "$(dirname "$0")/../modules/appearance-pip/tests" && pwd)"
"$MODULE_TEST_DIR/test_module.sh" "$@"
exec "$MODULE_TEST_DIR/test_tmux_border_accent.sh" "$@"
