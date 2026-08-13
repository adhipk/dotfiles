#!/usr/bin/env bash

set -uo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$TEST_DIR")"
DOTFILES_DIR="$(cd "$MODULE_DIR/../.." && pwd)"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-tmux-yazi-module.XXXXXX")"
DESTINATION="$TEMP_DIR/home"
STATE="$TEMP_DIR/state.db"

PASSED=0
FAILED=0

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

pass() {
    echo "  ✓ $1"
    ((PASSED++))
}

fail() {
    echo "  ✗ $1"
    echo "    Expected: $2"
    echo "    Actual:   $3"
    ((FAILED++))
}

assert_file() {
    if [[ -f "$1" ]]; then
        pass "$2"
    else
        fail "$2" "$1" "missing"
    fi
}

assert_contains() {
    if grep -Fq -- "$2" "$1"; then
        pass "$3"
    else
        fail "$3" "text containing $2" "$1"
    fi
}

assert_absent() {
    if [[ ! -e "$1" ]]; then
        pass "$2"
    else
        fail "$2" "absent" "$1 exists"
    fi
}

echo "================================"
echo "Tmux Yazi Module Contract Tests"
echo "================================"

assert_file "$MODULE_DIR/module.yaml" "module manifest exists"
assert_file "$MODULE_DIR/bin/tmux-yazi-pane" "module owns its runtime command"
assert_file "$MODULE_DIR/bin/tmux-yazi-open" "module owns its Neovim opener"
assert_file "$MODULE_DIR/targets/tmux.conf.tmpl" "module owns its tmux bindings"
assert_file "$MODULE_DIR/targets/ghostty.conf.tmpl" "module owns its Ghostty bindings"
assert_file "$MODULE_DIR/targets/tmux-which-key-new-window.yaml.tmpl" "module owns its Yazi window menu item"
assert_file "$MODULE_DIR/targets/tmux-which-key-pane.yaml.tmpl" "module owns its Yazi pane menu item"

if yq eval '.' "$MODULE_DIR/module.yaml" >/dev/null 2>&1; then
    pass "module manifest parses as YAML"
else
    fail "module manifest parses as YAML" "valid YAML" "parse error"
fi

assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-yazi-pane.tmpl" \
    'includeTemplate "../modules/tmux-yazi/bin/tmux-yazi-pane"' \
    "stable command path is a thin module bridge"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-yazi-open.tmpl" \
    'includeTemplate "../modules/tmux-yazi/bin/tmux-yazi-open"' \
    "Neovim opener path is a thin module bridge"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf.tmpl" \
    'includeTemplate "../modules/tmux-yazi/targets/tmux.conf.tmpl"' \
    "tmux mounts the module through one binding fragment"
assert_contains "$DOTFILES_DIR/home/Library/Application Support/com.mitchellh.ghostty/config.tmpl" \
    'includeTemplate "../modules/tmux-yazi/targets/ghostty.conf.tmpl"' \
    "Ghostty mounts the module through one binding fragment"
assert_contains "$MODULE_DIR/bin/tmux-yazi-pane" \
    'source "$DOTFILES_LIB_DIR/$library"' \
    "runtime command consumes the public standard library"

mkdir -p "$DESTINATION"
chezmoi \
    -S "$DOTFILES_DIR" \
    -D "$DESTINATION" \
    --persistent-state "$STATE" \
    apply --exclude=scripts,externals --force >/dev/null

if [[ -x "$DESTINATION/bin/tmux-yazi-pane" ]]; then
    pass "enabled profile installs the helper as executable"
else
    fail "enabled profile installs the helper as executable" "executable helper" "missing or not executable"
fi
if [[ -x "$DESTINATION/bin/tmux-yazi-open" ]]; then
    pass "enabled profile installs the Neovim opener as executable"
else
    fail "enabled profile installs the Neovim opener as executable" "executable helper" "missing or not executable"
fi
if HOME="$DESTINATION" "$DESTINATION/bin/tmux-yazi-pane" --help >/dev/null 2>&1; then
    pass "installed helper resolves its managed standard-library dependencies"
else
    fail "installed helper resolves its managed standard-library dependencies" "successful --help" "dependency load failed"
fi
assert_contains "$DESTINATION/.tmux.conf" 'bind-key -N "Toggle Yazi side pane"' "enabled profile renders the tmux pane binding"
assert_contains "$DESTINATION/.tmux.conf" "@resurrect-processes 'codex tuxedo yazi'" "enabled profile contributes Yazi persistence"
assert_contains "$DESTINATION/Library/Application Support/com.mitchellh.ghostty/config" 'keybind = cmd+b=text:\x01\x62' "enabled profile renders the Ghostty bridge"
assert_contains "$DESTINATION/.config/tmux/which-key.yaml" 'name: Yazi side pane' "enabled profile renders the command-center item"

chezmoi \
    -S "$DOTFILES_DIR" \
    -D "$DESTINATION" \
    --persistent-state "$STATE" \
    --override-data '{"modules":{"tmuxYazi":{"enabled":false}}}' \
    apply --exclude=scripts,externals --force >/dev/null

assert_absent "$DESTINATION/bin/tmux-yazi-pane" "disabled profile removes the previously installed helper"
assert_absent "$DESTINATION/bin/tmux-yazi-open" "disabled profile removes the previously installed Neovim opener"

if ! rg -q 'tmux-yazi-pane|Open Yazi|Toggle Yazi|tuxedo yazi' "$DESTINATION/.tmux.conf"; then
    pass "disabled profile removes tmux integrations"
else
    fail "disabled profile removes tmux integrations" "no Yazi integration" "stale tmux contribution"
fi

if ! rg -q 'cmd\+b=|cmd\+shift\+b=|Yazi' "$DESTINATION/Library/Application Support/com.mitchellh.ghostty/config"; then
    pass "disabled profile removes Ghostty integrations"
else
    fail "disabled profile removes Ghostty integrations" "no Yazi integration" "stale Ghostty contribution"
fi

if ! rg -q 'Yazi|yazi|tmux-yazi' "$DESTINATION/.config/tmux/which-key.yaml"; then
    pass "disabled profile removes command-center integrations"
else
    fail "disabled profile removes command-center integrations" "no Yazi integration" "stale menu contribution"
fi

if yq eval '.' "$DESTINATION/.config/tmux/which-key.yaml" >/dev/null 2>&1; then
    pass "disabled command-center YAML remains valid"
else
    fail "disabled command-center YAML remains valid" "valid YAML" "parse error"
fi

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

exit "$FAILED"
