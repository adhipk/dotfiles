#!/usr/bin/env bash

# Lifecycle tests for the default tmux session template.

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(dirname "$TEST_DIR")"
TEMPLATE_HELPER="$DOTFILES_DIR/home/bin/executable_tmux-session-template"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-tmux-template-test.XXXXXX")"
SOCKET_NAME="dotfiles-template-test-$$"
FAKE_BIN="$TEMP_DIR/bin"
PROJECT_DIR="$TEMP_DIR/project"
TMUX_CONFIG="$TEMP_DIR/tmux.conf"

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

new_session() {
    tmux_test new-session "$@"
}

session_windows() {
    tmux_test list-windows -t "=$1" -F '#{window_index}:#{window_name}'
}

session_window_count() {
    tmux_test list-windows -t "=$1" -F '#{window_id}' | wc -l | tr -d '[:space:]'
}

session_marker() {
    tmux_test show-options -qv -t "$1" @dotfiles_tmux_template 2>/dev/null || true
}

assert_auto_succeeds() {
    local session="$1"
    local name="$2"

    if TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" "$TEMPLATE_HELPER" auto "$session"; then
        pass "$name"
    else
        fail "$name" "exit 0" "nonzero exit"
    fi
}

mkdir -p "$FAKE_BIN" "$PROJECT_DIR"

cat > "$FAKE_BIN/codex" <<'EOF'
#!/usr/bin/env bash
exec sleep 300
EOF
cat > "$FAKE_BIN/nvim" <<'EOF'
#!/usr/bin/env bash
exec sleep 300
EOF
chmod +x "$FAKE_BIN/codex" "$FAKE_BIN/nvim"

cat > "$TMUX_CONFIG" <<EOF
set -g default-shell /bin/bash
set -g base-index 1
set-option -g allow-rename off
set-hook -g after-new-session[50] 'run-shell "$TEMPLATE_HELPER auto #{q:session_name}"'
EOF

echo "================================"
echo "Tmux Session Template Tests"
echo "================================"

if ! command -v tmux >/dev/null 2>&1; then
    fail "tmux is installed" "tmux on PATH" "not found"
else
    pass "tmux is installed"
fi

if [[ -x "$TEMPLATE_HELPER" ]]; then
    pass "session-template helper is executable"
else
    fail "session-template helper is executable" "executable" "not executable"
fi

# Keep the isolated server alive with a command session. The hook must skip it.
PATH="$FAKE_BIN:$PATH" \
    tmux -L "$SOCKET_NAME" -f "$TMUX_CONFIG" \
    new-session -d -s bootstrap "sleep 300"
tmux_test set-environment -g PATH "$FAKE_BIN:$PATH"

echo ""
echo "Testing the automatic template..."
new_session -d -s ordinary -c "$PROJECT_DIR"
assert_equals \
    "ordinary sessions get terminal/codex/nvim at 0/1/2" \
    $'0:terminal\n1:codex\n2:nvim' \
    "$(session_windows ordinary)"

CANONICAL_PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd -P)"
assert_equals \
    "all template windows inherit the session directory" \
    "$CANONICAL_PROJECT_DIR" \
    "$(tmux_test list-panes -s -t '=ordinary' -F '#{pane_current_path}' | sort -u)"
assert_equals \
    "terminal stays active after applying the template" \
    "terminal" \
    "$(tmux_test list-windows -t '=ordinary' -F '#{?window_active,#{window_name},}' | sed '/^$/d')"
assert_equals \
    "templated sessions carry the standard marker" \
    "standard" \
    "$(tmux_test show-options -qv -t ordinary @dotfiles_tmux_template)"
sleep 0.1
assert_equals \
    "Codex and Neovim startup commands run in their windows" \
    $'sleep\nsleep' \
    "$(
        tmux_test list-panes -t '=ordinary:codex' -F '#{pane_current_command}'
        tmux_test list-panes -t '=ordinary:nvim' -F '#{pane_current_command}'
    )"

echo ""
echo "Testing safety guards..."
new_session -d -s command-session -c "$PROJECT_DIR" -n command "sleep 300"
assert_auto_succeeds command-session "command-session guard exits successfully"
assert_equals \
    "sessions created with a command are left alone" \
    "1:command|sleep|" \
    "$(
        printf '%s|' "$(session_windows command-session)"
        printf '%s|' "$(tmux_test list-panes -t '=command-session:' -F '#{pane_current_command}')"
        session_marker command-session
    )"

new_session -d -e DOTFILES_TMUX_TEMPLATE=skip -s opted-out -c "$PROJECT_DIR" -n opted
assert_auto_succeeds opted-out "explicit opt-out guard exits successfully"
assert_equals \
    "sessions can explicitly opt out" \
    "1:opted|" \
    "$(printf '%s|' "$(session_windows opted-out)"; session_marker opted-out)"

new_session -d -s hs-managed-elsewhere -c "$PROJECT_DIR" -n hyperspace
assert_auto_succeeds hs-managed-elsewhere "hs session guard exits successfully"
assert_equals \
    "hs-* orchestrated sessions are left alone" \
    "1:hyperspace|" \
    "$(printf '%s|' "$(session_windows hs-managed-elsewhere)"; session_marker hs-managed-elsewhere)"

new_session -d -e DOTFILES_TMUX_TEMPLATE=skip -s group-base -c "$PROJECT_DIR" -n keepme
new_session -d -t '=group-base' -s group-copy
tmux_test set-environment -u -t group-copy DOTFILES_TMUX_TEMPLATE >/dev/null 2>&1 || true
assert_auto_succeeds group-copy "grouped-session guard exits successfully"
assert_equals \
    "grouped sessions preserve their shared layout" \
    $'1:keepme\n1:keepme\n1|' \
    "$(
        session_windows group-base
        session_windows group-copy
        printf '%s|' "$(tmux_test display-message -p -t '=group-copy:' '#{session_grouped}')"
        session_marker group-copy
    )"

new_session -d -s "space name" -c "$PROJECT_DIR"
assert_equals \
    "hook quoting supports session names with spaces" \
    $'0:terminal\n1:codex\n2:nvim' \
    "$(session_windows "space name")"

echo ""
echo "Testing explicit reuse by scratchpads..."
new_session -d -e DOTFILES_TMUX_TEMPLATE=skip -s scratchpad -c "$PROJECT_DIR" -n terminal
TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" \
    "$TEMPLATE_HELPER" ensure scratchpad "$PROJECT_DIR"
TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" \
    "$TEMPLATE_HELPER" ensure scratchpad "$PROJECT_DIR"
assert_equals \
    "explicit ensure mode creates the shared layout idempotently" \
    $'0:terminal\n1:codex\n2:nvim' \
    "$(session_windows scratchpad)"
assert_equals \
    "explicit ensure mode does not duplicate windows" \
    "3" \
    "$(session_window_count scratchpad)"

new_session -d -e DOTFILES_TMUX_TEMPLATE=skip -s concurrent -c "$PROJECT_DIR" -n terminal
TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" \
    "$TEMPLATE_HELPER" ensure concurrent "$PROJECT_DIR" &
FIRST_ENSURE_PID=$!
TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" \
    "$TEMPLATE_HELPER" ensure concurrent "$PROJECT_DIR" &
SECOND_ENSURE_PID=$!
FIRST_ENSURE_STATUS=0
SECOND_ENSURE_STATUS=0
wait "$FIRST_ENSURE_PID" || FIRST_ENSURE_STATUS=$?
wait "$SECOND_ENSURE_PID" || SECOND_ENSURE_STATUS=$?
assert_equals \
    "concurrent ensure calls both succeed" \
    "0:0" \
    "$FIRST_ENSURE_STATUS:$SECOND_ENSURE_STATUS"
assert_equals \
    "concurrent ensure calls create one copy of each window" \
    $'0:terminal\n1:codex\n2:nvim' \
    "$(session_windows concurrent)"

echo ""
echo "Testing hook reload behavior..."
tmux_test source-file "$TMUX_CONFIG"
tmux_test source-file "$TMUX_CONFIG"
assert_equals \
    "the indexed hook is not duplicated by config reloads" \
    "1" \
    "$(tmux_test show-hooks -g after-new-session | grep -c 'after-new-session\[50\]')"

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

exit "$FAILED"
