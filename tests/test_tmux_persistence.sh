#!/usr/bin/env bash

# Real Resurrect round-trip for tmux-workspace metadata.

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(dirname "$TEST_DIR")"
WORKSPACE="$DOTFILES_DIR/home/bin/executable_tmux-workspace"
BUN_BIN="$(command -v bun 2>/dev/null || true)"
RESURRECT_PLUGIN="$HOME/.tmux/plugins/tmux-resurrect"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-tmux-persistence-test.XXXXXX")"
TEMP_HOME="$TEMP_DIR/home"
CONFIG_ROOT="$TEMP_HOME/.config/tmux"
PROJECT_DIR="$TEMP_DIR/project"
FAKE_BIN="$TEMP_DIR/bin"
STATE_DIR="$TEMP_DIR/state"
RESURRECT_DIR="$TEMP_DIR/resurrect"
SOCKET_NAME="dotfiles-persistence-test-$$"

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

workspace() {
    HOME="$TEMP_HOME" \
        PATH="$FAKE_BIN:$PATH" \
        TMUX_WORKSPACE_CONFIG_HOME="$CONFIG_ROOT" \
        TMUX_WORKSPACE_TMUX_SOCKET="$SOCKET_NAME" \
        TMUX_WORKSPACE_STATE_HOME="$STATE_DIR" \
        "$BUN_BIN" "$WORKSPACE" "$@"
}

mkdir -p "$CONFIG_ROOT/layouts" "$PROJECT_DIR" "$FAKE_BIN" "$RESURRECT_DIR"
cp "$DOTFILES_DIR/home/dot_config/tmux/layouts/project.tmux.tsx" "$CONFIG_ROOT/layouts/project.tmux.tsx"

cat > "$FAKE_BIN/codex" <<'EOF'
#!/usr/bin/env bash
exec sleep 300
EOF
cat > "$FAKE_BIN/nvim" <<'EOF'
#!/usr/bin/env bash
exec sleep 300
EOF
chmod +x "$FAKE_BIN/codex" "$FAKE_BIN/nvim"

echo "================================"
echo "Tmux Persistence Tests"
echo "================================"

if [[ -x "$RESURRECT_PLUGIN/scripts/save.sh" && -x "$RESURRECT_PLUGIN/scripts/restore.sh" ]]; then
    pass "pinned tmux-resurrect scripts are installed"
else
    fail "pinned tmux-resurrect scripts are installed" "$RESURRECT_PLUGIN" "missing"
fi

workspace apply project --root "$PROJECT_DIR" --session persist-test >/dev/null
SESSION_ID=$(tmux_test list-sessions -F '#{session_id}|#{session_name}' \
    | awk -F '|' '$2 == "persist-test" { print $1; exit }')
tmux_test set-option -gq @resurrect-dir "$RESURRECT_DIR"
tmux_test set-option -gq @resurrect-processes false
tmux_test set-option -gq @resurrect-hook-post-save-all \
    "env TMUX_WORKSPACE_STATE_HOME=$STATE_DIR $BUN_BIN $WORKSPACE snapshot save"

SAVE_OUTPUT=$(tmux_test run-shell "$RESURRECT_PLUGIN/scripts/save.sh" 2>&1)
SAVE_STATUS=$?
assert_equals "Resurrect saves the isolated workspace" "0" "$SAVE_STATUS"
if [[ -L "$RESURRECT_DIR/last" ]]; then
    pass "Resurrect writes its state snapshot"
else
    fail "Resurrect writes its state snapshot" "$RESURRECT_DIR/last symlink" "$SAVE_OUTPUT"
fi
if [[ -f "$STATE_DIR/resurrect.json" ]]; then
    pass "post-save hook writes workspace identity sidecar"
else
    fail "post-save hook writes workspace identity sidecar" "$STATE_DIR/resurrect.json" "missing"
fi

tmux_test kill-server
HOME="$TEMP_HOME" PATH="$FAKE_BIN:$PATH" tmux -L "$SOCKET_NAME" -f /dev/null new-session -d -s bootstrap
tmux_test set-option -gq @resurrect-dir "$RESURRECT_DIR"
tmux_test set-option -gq @resurrect-processes false
tmux_test set-option -gq @resurrect-hook-pre-restore-pane-processes \
    "env TMUX_WORKSPACE_STATE_HOME=$STATE_DIR $BUN_BIN $WORKSPACE snapshot restore"

RESTORE_OUTPUT=$(tmux_test run-shell "$RESURRECT_PLUGIN/scripts/restore.sh" 2>&1)
RESTORE_STATUS=$?
assert_equals "Resurrect restores the isolated workspace" "0" "$RESTORE_STATUS"
RESTORED_SESSION_ID=$(tmux_test list-sessions -F '#{session_id}|#{session_name}' \
    | awk -F '|' '$2 == "persist-test" { print $1; exit }')
if [[ -n "$RESTORED_SESSION_ID" ]]; then
    pass "workspace session returns after server restart"
else
    fail "workspace session returns after server restart" "persist-test session" "$(tmux_test list-sessions -F '#{session_name}' 2>/dev/null || true) $RESTORE_OUTPUT"
fi

assert_equals \
    "pre-process hook restores session and window identity" \
    $'project\nterminal\ncodex\nnvim\nruntime' \
    "$(tmux_test show-options -qv -t "$RESTORED_SESSION_ID" @dotfiles_workspace; tmux_test list-windows -t "$RESTORED_SESSION_ID" -F '#{@dotfiles_workspace_window_id}')"
assert_equals \
    "pre-process hook restores every pane id" \
    $'main\nmain\nmain\nserver\ntests\nshell' \
    "$(tmux_test list-panes -s -t "$RESTORED_SESSION_ID" -F '#{@dotfiles_workspace_pane_id}')"

APPLY_OUTPUT=$(workspace apply --session-id "$RESTORED_SESSION_ID" 2>&1)
APPLY_STATUS=$?
assert_equals "restored session remains idempotently applicable" "0" "$APPLY_STATUS"

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

exit "$FAILED"
