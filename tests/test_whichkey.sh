#!/usr/bin/env bash

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(dirname "$TEST_DIR")"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/whichkey-test.XXXXXX")"
APP="$TEMP_DIR/whichkey"
JSON="$TEMP_DIR/shortcuts.json"

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

if grep -q 'NSApp.activate' "$DOTFILES_DIR/scripts/whichkey/WhichKey.swift"; then
    fail "Shortcut guide does not activate away from the current app"
else
    pass "Shortcut guide does not activate away from the current app"
fi

if grep -q 'case 125:' "$DOTFILES_DIR/scripts/whichkey/WhichKey.swift" &&
   grep -q 'case 123:' "$DOTFILES_DIR/scripts/whichkey/WhichKey.swift"; then
    pass "Shortcut guide navigation stays on the Option layer"
else
    fail "Shortcut guide navigation stays on the Option layer"
fi

if "$APP" --dump-json "$DOTFILES_DIR/home/dot_skhdrc" >"$JSON"; then
    pass "Live skhd source parses to JSON"
else
    fail "Live skhd source parses to JSON"
fi

assert_jq 'length >= 85' "Parser covers the full shortcut surface"
assert_jq 'any(.[]; .rawKey == "shift + alt - tab")' "Parser includes Shift+Alt bindings"
assert_jq 'any(.[]; .displayKey == "fn 1" and .category == "Capture")' "Parser includes Fn screenshot bindings"
assert_jq 'any(.[]; .displayKey == "⌥ ⇧ =" and .title == "Assign a project-space shortcut")' "Parser includes modal shortcut activators"
assert_jq 'any(.[]; .displayKey == "Hyper ⇧ ⌫" and .title == "Detach current Space")' "Parser formats Hyper and physical keycodes"
assert_jq 'any(.[]; .displayKey == "⌥ /" and .title == "Open shortcut guide")' "Parser understands the shortcut-guide mode trigger"
assert_jq 'any(.[]; .displayKey == "⌥ ⌘ [" and (.command | contains("window --focus")))' "Parser joins multiline display commands"
assert_jq 'all(.[]; (.title | contains("yabai -m") | not) and (.title | contains("/.config/") | not))' "Shortcut rows never expose raw shell commands as titles"
assert_jq '([.[].category] | unique | length) == 6' "All shortcut categories are populated"

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

exit "$FAILED"
