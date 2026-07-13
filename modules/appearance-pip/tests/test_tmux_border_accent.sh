#!/usr/bin/env bash

# Lifecycle tests for the tmux-driven JankyBorders accent helper.

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$TEST_DIR")"
DOTFILES_DIR="$(cd "$MODULE_DIR/../.." && pwd)"
HELPER="$MODULE_DIR/bin/tmux-border-accent"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-tmux-border-test.XXXXXX")"
FAKE_BIN="$TEMP_DIR/bin"
CALL_LOG="$TEMP_DIR/borders.log"
EARLY_APPLY_LOG="$TEMP_DIR/borders-early-apply.log"
ENDPOINT_STATE="$TEMP_DIR/borders.endpoint"
ENDPOINT_COUNT="$TEMP_DIR/launchctl.count"

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
if [[ "${1:-}" == apply-to=* && ! -f "$FAKE_BORDERS_ENDPOINT_STATE" ]]; then
    printf '%s\n' "$*" >> "$FAKE_BORDERS_EARLY_APPLY_LOG"
fi
if [[ "${FAKE_BORDERS_STARTS_DAEMON:-0}" == "1" && "${1:-}" == "style=square" ]]; then
    : > "$FAKE_BORDERS_STATE"
    sleep 0.2
fi
EOF

cat > "$FAKE_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "list-clients" ]]; then
    printf '%s\n' "${FAKE_TMUX_ACCENT:-}"
fi
EOF

cat > "$FAKE_BIN/pgrep" <<'EOF'
#!/usr/bin/env bash
if [[ -n "${FAKE_BORDERS_STATE:-}" && -f "$FAKE_BORDERS_STATE" ]]; then
    exit 0
fi
[[ "${FAKE_BORDERS_RUNNING:-1}" == "1" ]]
EOF

cat > "$FAKE_BIN/launchctl" <<'EOF'
#!/usr/bin/env bash
[[ "${1:-}" == "print" && "${2:-}" == gui/* ]] || exit 1

if [[ -f "$FAKE_BORDERS_ENDPOINT_STATE" ]]; then
    printf '        "git.felix.borders" = {\n'
    exit 0
fi

if [[ "${FAKE_BORDERS_RUNNING:-1}" != "1" && ! -f "$FAKE_BORDERS_STATE" ]]; then
    exit 0
fi

count=0
if [[ -f "$FAKE_LAUNCHCTL_COUNT" ]]; then
    read -r count < "$FAKE_LAUNCHCTL_COUNT"
fi
count=$((count + 1))
printf '%s\n' "$count" > "$FAKE_LAUNCHCTL_COUNT"

if ((count >= ${FAKE_LAUNCHCTL_READY_AFTER:-1})); then
    : > "$FAKE_BORDERS_ENDPOINT_STATE"
    printf '        "git.felix.borders" = {\n'
fi
EOF

cat > "$FAKE_BIN/yabai" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-m" && "${2:-}" == "query" && "${3:-}" == "--windows" ]]; then
    printf '%s\n' "${FAKE_YABAI_WINDOWS:-[]}"
fi
EOF

chmod +x "$FAKE_BIN/borders" "$FAKE_BIN/tmux" "$FAKE_BIN/pgrep" "$FAKE_BIN/launchctl" "$FAKE_BIN/yabai"

run_helper() {
    local accent="$1"
    local running="$2"
    local windows_json="$3"
    shift 3

    rm -f "$ENDPOINT_STATE" "$ENDPOINT_COUNT"
    : > "$EARLY_APPLY_LOG"

    env \
        PATH="$FAKE_BIN:$PATH" \
        TMUX_BORDER_ACCENT_BORDERS_BIN="$FAKE_BIN/borders" \
        TMUX_BORDER_ACCENT_TMUX_BIN="$FAKE_BIN/tmux" \
        TMUX_BORDER_ACCENT_YABAI_BIN="$FAKE_BIN/yabai" \
        TMUX_BORDER_ACCENT_LAUNCHCTL_BIN="$FAKE_BIN/launchctl" \
        TMUX_BORDER_TEST_LOG="$CALL_LOG" \
        TMUX_BORDER_ACCENT_SUPPRESS_ATTEMPTS="${TEST_SUPPRESS_ATTEMPTS:-1}" \
        TMUX_BORDER_ACCENT_SUPPRESS_RETRY_DELAY=0.01 \
        FAKE_TMUX_ACCENT="$accent" \
        FAKE_BORDERS_RUNNING="$running" \
        FAKE_BORDERS_STARTS_DAEMON="${TEST_FAKE_BORDERS_STARTS_DAEMON:-0}" \
        FAKE_BORDERS_STATE="$TEMP_DIR/borders.running" \
        FAKE_BORDERS_ENDPOINT_STATE="$ENDPOINT_STATE" \
        FAKE_BORDERS_EARLY_APPLY_LOG="$EARLY_APPLY_LOG" \
        FAKE_LAUNCHCTL_COUNT="$ENDPOINT_COUNT" \
        FAKE_LAUNCHCTL_READY_AFTER="${TEST_FAKE_LAUNCHCTL_READY_AFTER:-1}" \
        FAKE_YABAI_WINDOWS="$windows_json" \
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
run_helper '#cba6f7' 0 '[]' start 4.0 0xff000000
assert_equals \
    "start mode supplies the complete JankyBorders configuration" \
    "style=square width=4.0 hidpi=on ax_focus=on active_color=0xffcba6f7 inactive_color=0xff000000" \
    "$(cat "$CALL_LOG")"

: > "$CALL_LOG"
run_helper '#74c7ec' 1 '[]' update
assert_equals \
    "update mode converts the focused tmux accent to JankyBorders RGBA" \
    "active_color=0xff74c7ec" \
    "$(cat "$CALL_LOG")"

: > "$CALL_LOG"
run_helper '' 1 '[]' update
assert_equals \
    "focus outside tmux restores the black active border" \
    "active_color=0xff000000" \
    "$(cat "$CALL_LOG")"

: > "$CALL_LOG"
run_helper '#89b4fa' 0 '[]' update
assert_equals \
    "update mode does not accidentally start a partial borders daemon" \
    "" \
    "$(cat "$CALL_LOG")"

: > "$CALL_LOG"
run_helper '#cba6f7' 1 \
    '[{"id":100,"app":"Ghostty","scratchpad":""},{"id":200,"app":"Ghostty","scratchpad":"terminal"},{"id":300,"app":"Ghostty","scratchpad":null}]' \
    update
assert_equals \
    "accent updates restore the transparent per-window scratchpad override" \
    $'active_color=0xffcba6f7\napply-to=200 width=0 active_color=0x00000000 inactive_color=0x00000000' \
    "$(cat "$CALL_LOG")"

: > "$CALL_LOG"
run_helper '' 1 '[]' suppress-scratchpads 200
assert_equals \
    "a newly focused scratchpad can suppress its exact JankyBorders window" \
    "apply-to=200 width=0 active_color=0x00000000 inactive_color=0x00000000" \
    "$(cat "$CALL_LOG")"

: > "$CALL_LOG"
run_helper '#cba6f7' 1 \
    '[{"id":200,"scratchpad":"terminal"},{"id":400,"scratchpad":"quick_terminal"}]' \
    start 4.0 0xff000000
assert_equals \
    "reloading a running border daemon keeps every existing scratchpad borderless" \
    $'style=square width=4.0 hidpi=on ax_focus=on active_color=0xffcba6f7 inactive_color=0xff000000\napply-to=200 width=0 active_color=0x00000000 inactive_color=0x00000000\napply-to=400 width=0 active_color=0x00000000 inactive_color=0x00000000' \
    "$(cat "$CALL_LOG")"

: > "$CALL_LOG"
rm -f "$TEMP_DIR/borders.running"
TEST_FAKE_BORDERS_STARTS_DAEMON=1 TEST_FAKE_LAUNCHCTL_READY_AFTER=3 run_helper '#cba6f7' 0 \
    '[{"id":200,"scratchpad":"terminal"}]' \
    start 4.0 0xff000000
assert_equals \
    "cold daemon startup suppresses an existing scratchpad after Mach-service readiness" \
    $'style=square width=4.0 hidpi=on ax_focus=on active_color=0xffcba6f7 inactive_color=0xff000000\napply-to=200 width=0 active_color=0x00000000 inactive_color=0x00000000' \
    "$(cat "$CALL_LOG")"
assert_equals \
    "cold startup waits through the pgrep-before-Mach-service race" \
    "3" \
    "$(cat "$ENDPOINT_COUNT")"
assert_equals \
    "cold startup never sends apply-to before the Mach service exists" \
    "" \
    "$(cat "$EARLY_APPLY_LOG")"

: > "$CALL_LOG"
TEST_SUPPRESS_ATTEMPTS=3 run_helper '' 1 '[]' suppress-scratchpads 200
assert_equals \
    "new scratchpad suppression retries the exact window while JankyBorders indexes it" \
    $'apply-to=200 width=0 active_color=0x00000000 inactive_color=0x00000000\napply-to=200 width=0 active_color=0x00000000 inactive_color=0x00000000\napply-to=200 width=0 active_color=0x00000000 inactive_color=0x00000000' \
    "$(cat "$CALL_LOG")"

INVALID_STATUS=0
run_helper '#89b4fa' 1 '[]' invalid >/dev/null 2>&1 || INVALID_STATUS=$?
assert_equals \
    "unknown modes fail with a usage error" \
    "2" \
    "$INVALID_STATUS"

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

exit "$FAILED"
