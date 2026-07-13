#!/usr/bin/env bash

set -euo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$TEST_DIR/../modules/tmux-sessions/tests/test_tmux_persistence.sh" "$@"
