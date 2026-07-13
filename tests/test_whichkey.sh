#!/usr/bin/env bash

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(dirname "$TEST_DIR")"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/whichkey-test.XXXXXX")"
APP="$TEMP_DIR/whichkey"
JSON="$TEMP_DIR/shortcuts.json"
SKHDRC="$TEMP_DIR/skhdrc"
SWIFT_SOURCE="$DOTFILES_DIR/modules/shortcut-guide/app/WhichKey.swift"

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
    [[ -z "${2:-}" ]] || echo "    $2"
    ((FAILED++))
}

assert_jq() {
    local expression="$1"
    local name="$2"
    if jq -e "$expression" "$JSON" >/dev/null; then
        pass "$name"
    else
        fail "$name" "jq expression failed: $expression"
    fi
}

echo "================================"
echo "Shortcut Guide Tests"
echo "================================"

if [[ "$(uname -s)" != "Darwin" ]]; then
    pass "Shortcut guide build is macOS-only"
    echo ""
    echo "================================"
    echo "Results: $PASSED passed, $FAILED failed"
    echo "================================"
    exit 0
fi

echo ""
echo "Testing source-owned build..."
if WHICHKEY_BUILD_PATH="$TEMP_DIR/build/whichkey" WHICHKEY_INSTALL_PATH="$APP" \
    "$DOTFILES_DIR/scripts/build-whichkey.sh" >/dev/null; then
    pass "Shortcut guide builds and installs"
else
    fail "Shortcut guide builds and installs"
fi

if [[ -x "$APP" ]]; then
    pass "Installed shortcut guide is executable"
else
    fail "Installed shortcut guide is executable"
fi

echo ""
echo "Testing parser and search model..."
if "$APP" --self-test >/dev/null; then
    pass "Embedded parser and search self-test passes"
else
    fail "Embedded parser and search self-test passes"
fi

if grep -q 'NSApp.activate' "$SWIFT_SOURCE"; then
    fail "Shortcut guide does not activate away from the current app"
else
    pass "Shortcut guide does not activate away from the current app"
fi

if grep -q 'case 125:' "$SWIFT_SOURCE" &&
   grep -q 'case 123:' "$SWIFT_SOURCE"; then
    pass "Shortcut guide navigation stays on the Option layer"
else
    fail "Shortcut guide navigation stays on the Option layer"
fi

if chezmoi -S "$DOTFILES_DIR" cat "$HOME/.skhdrc" >"$SKHDRC"; then
    pass "Live skhd source renders through module composition"
else
    fail "Live skhd source renders through module composition"
fi

if "$APP" --dump-json "$SKHDRC" >"$JSON"; then
    pass "Live skhd source parses to JSON"
else
    fail "Live skhd source parses to JSON"
fi

assert_jq 'length >= 50' "Parser covers the active shortcut surface"
assert_jq 'any(.[]; .rawKey == "shift + alt - tab")' "Parser includes Shift+Alt bindings"
assert_jq 'any(.[]; .displayKey == "fn ," and .title == "Open dotfiles scratchpad" and .category == "Apps & Focus")' "Parser categorizes Fn+Comma as the dotfiles scratchpad"
assert_jq 'any(.[]; .displayKey == "fn 1" and .title == "Open projects scratchpad" and .category == "Apps & Focus")' "Parser categorizes Fn+1 as the projects scratchpad"
assert_jq 'all(.[]; (.rawKey | startswith("fn -") | not) or .displayKey == "fn ," or .displayKey == "fn 1")' "Parser exposes only scratchpads on Fn"
assert_jq '([.[] | select(.rawKey | startswith("rcmd -"))] | length) == 4' "Parser includes the four right-Command Ghostty actions"
assert_jq 'any(.[]; .displayKey == "R⌘ D" and .title == "Duplicate current tmux window" and .category == "Apps & Focus")' "Parser formats the right-Command duplicate action"
assert_jq 'any(.[]; .displayKey == "R⌘ R" and .title == "Rename current tmux window")' "Parser includes the right-Command rename action"
assert_jq 'any(.[]; .displayKey == "R⌘ S" and .title == "Open tmux session picker")' "Parser includes the right-Command session picker"
assert_jq 'any(.[]; .displayKey == "R⌘ Space" and .title == "Open tmux command center")' "Parser includes the right-Command command center"
assert_jq 'all(.[] | select(.rawKey | startswith("rcmd -")); .detail | contains("every other app receives the chord directly"))' "Parser explains the right-Command wildcard passthrough"
assert_jq 'all(.[]; (.rawKey | contains("ctrl + alt + cmd") | not))' "Parser exposes no active Hyper bindings"
assert_jq 'all(.[]; (.command | contains("/projects ") | not))' "Parser exposes no project-context commands"
assert_jq 'any(.[]; .rawKey == "alt + shift - h" and .title == "Grow window left")' "Parser includes Option+Shift window resizing"
assert_jq 'any(.[]; .displayKey == "⌥ /" and .title == "Open shortcut guide")' "Parser understands the shortcut-guide mode trigger"
assert_jq 'any(.[]; .displayKey == "⌥ ⇧ [" and .command == "~/.config/yabai/display-move prev" and .owner == "space-display")' "Parser captures the module-owned previous-display command"
assert_jq 'all(.[]; (.title | contains("yabai -m") | not) and (.title | contains("/.config/") | not))' "Shortcut rows never expose raw shell commands as titles"
assert_jq '([.[].category] | unique | length) == 4' "Only active shortcut categories are populated"

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

exit "$FAILED"
