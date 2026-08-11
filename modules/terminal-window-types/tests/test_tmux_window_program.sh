#!/usr/bin/env bash

set -uo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$TEST_DIR")"
PROGRAM="$MODULE_DIR/bin/tmux-window-program"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-tmux-window-program.XXXXXX")"
FAKE_BIN="$TEMP_DIR/bin"

PASSED=0
FAILED=0

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

assert_label() {
  local name="$1"
  local expected="$2"
  local scenario="$3"
  local actual

  actual=$(PATH="$FAKE_BIN:$PATH" TMUX_WINDOW_PROGRAM_SCENARIO="$scenario" \
    "$PROGRAM" /dev/ttys001)
  if [[ "$actual" == "$expected" ]]; then
    printf '  ✓ %s\n' "$name"
    ((PASSED++))
  else
    printf '  ✗ %s\n    Expected: %s\n    Actual:   %s\n' "$name" "$expected" "$actual"
    ((FAILED++))
  fi
}

mkdir -p "$FAKE_BIN"
cat >"$FAKE_BIN/ps" <<'EOF'
#!/usr/bin/env bash
case "${TMUX_WINDOW_PROGRAM_SCENARIO:?}" in
  shell) printf '%s\n' '101 101 101 -zsh -zsh' ;;
  codex) printf '%s\n' '101 101 202 -zsh -zsh' '202 202 202 node node /opt/bin/codex' '203 202 202 codex /opt/vendor/codex' ;;
  opencode) printf '%s\n' '101 101 204 -zsh -zsh' '204 204 204 bun bun /opt/bin/opencode' ;;
  python_module) printf '%s\n' '101 101 205 -zsh -zsh' '205 205 205 Python python3 -m aider' ;;
  nvim) printf '%s\n' '101 101 206 -zsh -zsh' '206 206 206 nvim nvim' ;;
  background_child) printf '%s\n' '101 101 202 -zsh -zsh' '202 202 202 node node /opt/bin/codex' '210 210 202 node node background-server.js' ;;
esac
EOF
chmod +x "$FAKE_BIN/ps"

echo "================================="
echo "Tmux Window Program Label Tests"
echo "================================="

assert_label "idle shells collapse to tilde" "~" shell
assert_label "Node launchers expose the actual Codex command" "codex" codex
assert_label "Bun launchers expose the actual OpenCode command" "opencode" opencode
assert_label "Python module launchers expose the actual module" "aider" python_module
assert_label "native programs keep their executable name" "nvim" nvim
assert_label "background descendants do not replace the foreground program" "codex" background_child

echo ""
echo "Passed: $PASSED"
echo "Failed: $FAILED"

((FAILED == 0))
