#!/usr/bin/env bash

set -uo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$TEST_DIR")"
DOTFILES_DIR="$(cd "$MODULE_DIR/../.." && pwd)"
CONFIG="$MODULE_DIR/config/config.py"
BRIDGE="$DOTFILES_DIR/home/private_dot_qutebrowser/config.py.tmpl"
TEMP_HOME="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-qutebrowser-module.XXXXXX")"
PASSED=0
FAILED=0

cleanup() { rm -rf "$TEMP_HOME"; }
trap cleanup EXIT
pass() { printf '  ✓ %s\n' "$1"; PASSED=$((PASSED + 1)); }
fail() { printf '  ✗ %s\n    Expected: %s\n    Actual:   %s\n' "$1" "$2" "$3"; FAILED=$((FAILED + 1)); }
assert_file() { [[ -f "$1" ]] && pass "$2" || fail "$2" "$1" "missing"; }
assert_contains() { grep -Fq -- "$2" "$1" && pass "$3" || fail "$3" "text containing $2" "$1"; }

printf '================================\nqutebrowser Module Contract Tests\n================================\n'

assert_file "$MODULE_DIR/module.yaml" "module manifest exists"
assert_file "$MODULE_DIR/README.md" "module documents the shortcut layer"
assert_file "$CONFIG" "module owns qutebrowser config"
assert_file "$BRIDGE" "parent exposes one thin ChezMoi bridge"

if yq eval '.' "$MODULE_DIR/module.yaml" >/dev/null 2>&1; then
    pass "module manifest parses as YAML"
else
    fail "module manifest parses as YAML" "valid YAML" "parse error"
fi

if python3 -c 'import pathlib; compile(pathlib.Path(__import__("sys").argv[1]).read_text(), __import__("sys").argv[1], "exec")' "$CONFIG"; then
    pass "qutebrowser config parses as Python"
else
    fail "qutebrowser config parses as Python" "valid Python" "parse error"
fi

assert_contains "$CONFIG" 'config.load_autoconfig()' "UI settings remain loadable"
assert_contains "$CONFIG" 'bind_browser("<Meta-t>", "open -t")' "Cmd+T opens a tab"
assert_contains "$CONFIG" 'bind_browser("<Meta-Shift-t>", "undo")' "Cmd+Shift+T restores a tab"
assert_contains "$CONFIG" 'bind_browser("<Meta-Alt-Right>", "tab-next")' "Chrome tab cycling is present"
assert_contains "$CONFIG" 'config.bind(",td", "tab-clone")' "keyboard-first tab duplication is present"
assert_contains "$CONFIG" 'config.bind(",er", "greasemonkey-reload")' "userscript reload is present"
assert_contains "$DOTFILES_DIR/Brewfile" 'cask "qutebrowser"' "bootstrap installs qutebrowser"

if chezmoi -S "$DOTFILES_DIR" -D "$TEMP_HOME" \
    --persistent-state "$TEMP_HOME/state.db" \
    apply --exclude=scripts,externals --force >/dev/null 2>&1; then
    pass "ChezMoi renders the enabled module into a cold home"
else
    fail "ChezMoi renders the enabled module into a cold home" "successful apply" "apply failed"
fi

RENDERED_CONFIG="$TEMP_HOME/.qutebrowser/config.py"
assert_file "$RENDERED_CONFIG" "rendered config uses the macOS qutebrowser path"
assert_contains "$RENDERED_CONFIG" '<Meta-Shift-e>' "rendered config exposes userscript help"

QUTEBROWSER_BIN="${QUTEBROWSER_BIN:-}"
if [[ -z "$QUTEBROWSER_BIN" ]] && command -v qutebrowser >/dev/null 2>&1; then
    QUTEBROWSER_BIN="$(command -v qutebrowser)"
elif [[ -z "$QUTEBROWSER_BIN" && -x /Applications/qutebrowser.app/Contents/MacOS/qutebrowser ]]; then
    QUTEBROWSER_BIN=/Applications/qutebrowser.app/Contents/MacOS/qutebrowser
fi

if [[ -n "$QUTEBROWSER_BIN" ]] && "$QUTEBROWSER_BIN" -T -C "$RENDERED_CONFIG" --version \
    >"$TEMP_HOME/qutebrowser-version.log" 2>"$TEMP_HOME/qutebrowser-error.log" \
    && ! grep -Fq 'Error while loading config.py' "$TEMP_HOME/qutebrowser-error.log"; then
    pass "installed qutebrowser accepts the rendered configuration"
elif [[ -z "$QUTEBROWSER_BIN" ]]; then
    pass "qutebrowser runtime validation is optional when the app is absent"
else
    fail "installed qutebrowser accepts the rendered configuration" "clean --version validation" "$(cat "$TEMP_HOME/qutebrowser-error.log")"
fi

printf '\n================================\nResults: %d passed, %d failed\n================================\n' "$PASSED" "$FAILED"
exit "$FAILED"
