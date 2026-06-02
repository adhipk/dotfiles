#!/usr/bin/env bash

# Tests for the default-apps helper command

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(dirname "$TEST_DIR")"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-default-apps-test.XXXXXX")"
FAKE_BIN="$TEMP_DIR/bin"
DUTI_LOG="$TEMP_DIR/duti.log"

PASSED=0
FAILED=0

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

assert_set_default() {
    local name="$1"
    local expected="$2"
    shift 2

    : > "$DUTI_LOG"
    if DUTI_LOG="$DUTI_LOG" PATH="$FAKE_BIN:$PATH" "$DOTFILES_DIR/scripts/default-apps.sh" "$@" >/dev/null &&
        [[ "$(cat "$DUTI_LOG")" == "$expected" ]]; then
        echo "  ✓ $name"
        ((PASSED++))
    else
        echo "  ✗ $name"
        echo "    Expected duti arguments: $expected"
        echo "    Actual duti arguments:   $(cat "$DUTI_LOG")"
        ((FAILED++))
    fi
}

mkdir -p "$FAKE_BIN"
cat > "$FAKE_BIN/duti" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$DUTI_LOG"
EOF
chmod +x "$FAKE_BIN/duti"

mkdir -p "$TEMP_DIR/Test Editor.app/Contents"
cat > "$TEMP_DIR/Test Editor.app/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.example.TestEditor</string>
</dict>
</plist>
EOF

echo "================================"
echo "Default Apps Tests"
echo "================================"

echo ""
echo "Testing extension defaults..."
assert_set_default "sets an extension default" "-s md.obsidian .md all" set .md md.obsidian
assert_set_default "resolves an app path to its bundle ID" "-s com.example.TestEditor .txt all" set .txt "$TEMP_DIR/Test Editor.app"

echo ""
echo "Testing URL-scheme defaults..."
assert_set_default "sets a URL-scheme default" "-s com.apple.Safari https" set https: com.apple.Safari

echo ""
echo "Testing list..."
list_output=$("$DOTFILES_DIR/scripts/default-apps.sh" list)
if grep -q "Markdown (.md)" <<< "$list_output"; then
    echo "  ✓ list prints current handlers"
    ((PASSED++))
else
    echo "  ✗ list does not print current handlers"
    ((FAILED++))
fi

echo ""
echo "Testing help..."
help_output=$("$DOTFILES_DIR/scripts/default-apps.sh" --help)
if grep -q "^Commands:" <<< "$help_output"; then
    echo "  ✓ help documents commands"
    ((PASSED++))
else
    echo "  ✗ help does not document commands"
    ((FAILED++))
fi

if grep -q "^Targets:" <<< "$help_output"; then
    echo "  ✓ help documents target formats"
    ((PASSED++))
else
    echo "  ✗ help does not document target formats"
    ((FAILED++))
fi

if grep -q "default-apps set .md Obsidian" <<< "$help_output"; then
    echo "  ✓ help includes a set example"
    ((PASSED++))
else
    echo "  ✗ help does not include a set example"
    ((FAILED++))
fi

if [[ "$("$DOTFILES_DIR/scripts/default-apps.sh" help)" == "$help_output" ]]; then
    echo "  ✓ help command matches --help"
    ((PASSED++))
else
    echo "  ✗ help command does not match --help"
    ((FAILED++))
fi

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

exit $FAILED
