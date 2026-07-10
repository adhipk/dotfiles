#!/usr/bin/env bash

# Lifecycle tests for the idempotent Yazi side-pane toggle.

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(dirname "$TEST_DIR")"
HELPER="$DOTFILES_DIR/home/bin/executable_tmux-yazi-pane"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-tmux-yazi-test.XXXXXX")"
SOCKET_NAME="dotfiles-yazi-test-$$"
FAKE_BIN="$TEMP_DIR/bin"
PROJECT_DIR="$TEMP_DIR/project's folder"
TMUX_CONFIG="$TEMP_DIR/tmux.conf"
ENTRY_LOG="$TEMP_DIR/yazi-entry.log"

PASSED=0
FAILED=0

cleanup() {
    tmux -L "$SOCKET_NAME" kill-server >/dev/null 2>&1 || true
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

tmux_test() {
    tmux -L "$SOCKET_NAME" "$@"
}

run_toggle() {
    PATH="$FAKE_BIN:$PATH" \
        TMUX_YAZI_PANE_SOCKET="$SOCKET_NAME" \
        "$HELPER" toggle "$1"
}

pane_count() {
    tmux_test list-panes -t "$1" -F '#{pane_id}' | wc -l | tr -d '[:space:]'
}

managed_pane() {
    tmux_test list-panes -t "$1" -F '#{pane_id}|#{@dotfiles_yazi_side}' \
        | awk -F '|' '$2 == "1" { print $1; exit }'
}

managed_count() {
    tmux_test list-panes -t "$1" -F '#{@dotfiles_yazi_side}' \
        | awk '$0 == "1" { count++ } END { print count + 0 }'
}

mkdir -p "$FAKE_BIN" "$PROJECT_DIR"

cat > "$FAKE_BIN/yazi" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${1:-}" > "$TMUX_YAZI_TEST_ENTRY_LOG"
exec sleep 300
EOF
chmod +x "$FAKE_BIN/yazi"

cat > "$TMUX_CONFIG" <<'EOF'
set -g default-shell /bin/bash
set -g status off
EOF

echo "================================"
echo "Tmux Yazi Pane Tests"
echo "================================"

if [[ -x "$HELPER" ]]; then
    pass "tmux-yazi-pane helper is executable"
else
    fail "tmux-yazi-pane helper is executable" "executable" "not executable"
fi

if bash -n "$HELPER"; then
    pass "tmux-yazi-pane has valid shell syntax"
else
    fail "tmux-yazi-pane has valid shell syntax" "valid bash" "syntax error"
fi

PATH="$FAKE_BIN:$PATH" tmux -L "$SOCKET_NAME" -f "$TMUX_CONFIG" \
    new-session -d -s bootstrap "sleep 300"
tmux_test set-environment -g PATH "$FAKE_BIN:$PATH"
tmux_test set-environment -g TMUX_YAZI_TEST_ENTRY_LOG "$ENTRY_LOG"
tmux_test new-session -d -s toggle -n main -c "$PROJECT_DIR"

MAIN_PANE=$(tmux_test list-panes -t '=toggle:main' -F '#{pane_id}')

echo ""
echo "Testing open and close behavior..."
run_toggle "$MAIN_PANE"
SIDE_PANE=$(managed_pane '=toggle:main')
assert_equals "first toggle creates exactly one side pane" "2:1" "$(pane_count '=toggle:main'):$(managed_count '=toggle:main')"
assert_equals "new Yazi pane is focused" "$SIDE_PANE" "$(tmux_test list-panes -t '=toggle:main' -F '#{?pane_active,#{pane_id},}' | sed '/^$/d')"
assert_equals "Yazi inherits a path containing spaces and quotes" "$(cd "$PROJECT_DIR" && pwd -P)" "$(tmux_test display-message -p -t "$SIDE_PANE" '#{pane_current_path}')"
assert_equals "Yazi receives the current folder as its entry" "$(cd "$PROJECT_DIR" && pwd -P)" "$(cat "$ENTRY_LOG")"
assert_equals "Yazi side pane spans the full window height" "$(tmux_test display-message -p -t "$MAIN_PANE" '#{pane_height}')" "$(tmux_test display-message -p -t "$SIDE_PANE" '#{pane_height}')"

WINDOW_WIDTH=$(tmux_test display-message -p -t "$MAIN_PANE" '#{window_width}')
SIDE_WIDTH=$(tmux_test display-message -p -t "$SIDE_PANE" '#{pane_width}')
SIDE_PERCENT=$((SIDE_WIDTH * 100 / WINDOW_WIDTH))
if [[ "$SIDE_PERCENT" -ge 38 && "$SIDE_PERCENT" -le 42 ]]; then
    pass "Yazi side pane is approximately 40 percent wide"
else
    fail "Yazi side pane is approximately 40 percent wide" "38-42 percent" "$SIDE_PERCENT percent"
fi

run_toggle "$SIDE_PANE"
assert_equals "second toggle from Yazi closes it without closing the window" "1:$MAIN_PANE" "$(pane_count '=toggle:main'):$(tmux_test list-panes -t '=toggle:main' -F '#{pane_id}')"

echo ""
echo "Testing recovery and rapid repeats..."
run_toggle "$MAIN_PANE"
KILLED_PANE=$(managed_pane '=toggle:main')
tmux_test kill-pane -t "$KILLED_PANE"
run_toggle "$MAIN_PANE"
REOPENED_PANE=$(managed_pane '=toggle:main')
if [[ -n "$REOPENED_PANE" && "$REOPENED_PANE" != "$KILLED_PANE" ]]; then
    pass "manual pane closure leaves the next toggle recoverable"
else
    fail "manual pane closure leaves the next toggle recoverable" "a new marked pane" "$REOPENED_PANE"
fi
run_toggle "$REOPENED_PANE"

FIRST_STATUS=0
SECOND_STATUS=0
run_toggle "$MAIN_PANE" &
FIRST_PID=$!
run_toggle "$MAIN_PANE" &
SECOND_PID=$!
wait "$FIRST_PID" || FIRST_STATUS=$?
wait "$SECOND_PID" || SECOND_STATUS=$?
assert_equals "concurrent toggles both succeed" "0:0" "$FIRST_STATUS:$SECOND_STATUS"
assert_equals "concurrent double-toggle never leaves duplicates" "1:0" "$(pane_count '=toggle:main'):$(managed_count '=toggle:main')"

echo ""
echo "Testing per-window scope..."
tmux_test new-window -d -t '=toggle:' -n other -c "$PROJECT_DIR"
OTHER_PANE=$(tmux_test list-panes -t '=toggle:other' -F '#{pane_id}')
run_toggle "$MAIN_PANE"
run_toggle "$OTHER_PANE"
assert_equals "each tmux window owns an independent side pane" "1:1" "$(managed_count '=toggle:main'):$(managed_count '=toggle:other')"

echo ""
echo "Testing last-pane safety..."
SOLE_YAZI_PANE=$(managed_pane '=toggle:main')
tmux_test kill-pane -t "$MAIN_PANE"
SOLE_TOGGLE_STATUS=0
run_toggle "$SOLE_YAZI_PANE" || SOLE_TOGGLE_STATUS=$?
assert_equals \
    "a promoted Yazi side pane cannot delete its final window" \
    "0:1:1" \
    "$SOLE_TOGGLE_STATUS:$(pane_count '=toggle:main'):$(managed_count '=toggle:main')"

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

exit "$FAILED"
