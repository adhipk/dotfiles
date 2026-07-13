#!/usr/bin/env bash

set -euo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$TEST_DIR/../modules/terminal-window-types/tests/test_tmux_session_template.sh" "$@"
