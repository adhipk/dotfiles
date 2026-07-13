#!/usr/bin/env bash

# Parent test entrypoint for the external todo adapter module.

set -euo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(dirname "$TEST_DIR")"

export TODO_TEST_REPO_ROOT="$DOTFILES_DIR"
exec "$DOTFILES_DIR/modules/todo/tests/test_todo.sh" "$@"
