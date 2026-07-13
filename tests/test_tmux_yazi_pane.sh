#!/usr/bin/env bash

set -euo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_TEST_DIR="$TEST_DIR/../modules/tmux-yazi/tests"

"$MODULE_TEST_DIR/test_module.sh" "$@"
exec "$MODULE_TEST_DIR/test_tmux_yazi_pane.sh" "$@"
