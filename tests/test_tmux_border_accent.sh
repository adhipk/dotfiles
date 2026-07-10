#!/usr/bin/env bash

# Lifecycle tests for the tmux-driven JankyBorders accent helper.

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(dirname "$TEST_DIR")"
HELPER="$DOTFILES_DIR/home/bin/executable_tmux-border-accent"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-tmux-border-test.XXXXXX")"
FAKE_BIN="$TEMP_DIR/bin"
CALL_LOG="$TEMP_DIR/borders.log"

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
    local name="$1"
    local expected="$2"
    local actual="$3"

    echo "  ✗ $name"
    echo "    Expected: $expected"
    echo "    Actual:   $actual"
    ((FAILED++))
}

assert_equals() {
    local name="$1"
    local expected="$2"
    local actual="$3"

    if [[ "$actual" == "$expected" ]]; then
        pass "$name"
    else
        fail "$name" "$expected" "$actual"
    fi
}

mkdir -p "$FAKE_BIN"

cat > "$FAKE_BIN/borders" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$TMUX_BORDER_TEST_LOG"
EOF

cat > "$FAKE_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "list-clients" ]]; then
    printf '%s\n' "${FAKE_TMUX_ACCENT:-}"
fi
EOF

cat > "$FAKE_BIN/pgrep" <<'EOF'
#!/usr/bin/env bash
[[ "${FAKE_BORDERS_RUNNING:-1}" == "1" ]]
EOF

chmod +x "$FAKE_BIN/borders" "$FAKE_BIN/tmux" "$FAKE_BIN/pgrep"

run_helper() {
    local accent="$1"
    local running="$2"
    shift 2

    env \
        PATH="$FAKE_BIN:$PATH" \
        TMUX_BORDER_ACCENT_BORDERS_BIN="$FAKE_BIN/borders" \
        TMUX_BORDER_ACCENT_TMUX_BIN="$FAKE_BIN/tmux" \
        TMUX_BORDER_TEST_LOG="$CALL_LOG" \
        FAKE_TMUX_ACCENT="$accent" \
        FAKE_BORDERS_RUNNING="$running" \
        "$HELPER" "$@"
}

echo "================================"
echo "Tmux Border Accent Tests"
echo "================================"

if [[ -x "$HELPER" ]]; then
    pass "tmux-border-accent helper is executable"
else
    fail "tmux-border-accent helper is executable" "executable" "not executable"
fi

if bash -n "$HELPER"; then
    pass "tmux-border-accent has valid shell syntax"
else
    fail "tmux-border-accent has valid shell syntax" "valid bash" "syntax error"
fi

: > "$CALL_LOG"
run_helper '#cba6f7' 0 start 4.0 0xff000000
assert_equals \
    "start mode supplies the complete JankyBorders configuration" \
    "style=square width=4.0 hidpi=on ax_focus=on active_color=0xffcba6f7 inactive_color=0xff000000" \
    "$(cat "$CALL_LOG")"

: > "$CALL_LOG"
run_helper '#74c7ec' 1 update
assert_equals \
    "update mode converts the focused tmux accent to JankyBorders RGBA" \
    "active_color=0xff74c7ec" \
    "$(cat "$CALL_LOG")"

: > "$CALL_LOG"
run_helper '' 1 update
assert_equals \
    "focus outside tmux restores the black active border" \
    "active_color=0xff000000" \
    "$(cat "$CALL_LOG")"

: > "$CALL_LOG"
run_helper '#89b4fa' 0 update
assert_equals \
    "update mode does not accidentally start a partial borders daemon" \
    "" \
    "$(cat "$CALL_LOG")"

INVALID_STATUS=0
run_helper '#89b4fa' 1 invalid >/dev/null 2>&1 || INVALID_STATUS=$?
assert_equals \
    "unknown modes fail with a usage error" \
    "2" \
    "$INVALID_STATUS"

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

exit "$FAILED"
