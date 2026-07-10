#!/usr/bin/env bash

# Lifecycle tests for the React-like tmux workspace layouts.

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(dirname "$TEST_DIR")"
WORKSPACE="$DOTFILES_DIR/home/bin/executable_tmux-workspace"
BUN_BIN="$(command -v bun 2>/dev/null || true)"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-tmux-workspace-test.XXXXXX")"
TEMP_HOME="$TEMP_DIR/home"
CONFIG_ROOT="$TEMP_HOME/.config/tmux"
LAYOUT_DIR="$CONFIG_ROOT/layouts"
PROJECT_DIR="$TEMP_DIR/Project space's app"
FAKE_BIN="$TEMP_DIR/bin"
SOCKET_NAME="dotfiles-workspace-test-$$"

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

assert_contains_text() {
    local name="$1"
    local pattern="$2"
    local actual="$3"

    if grep -q -- "$pattern" <<<"$actual"; then
        pass "$name"
    else
        fail "$name" "text containing $pattern" "$actual"
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
        TMUX_WORKSPACE_STATE_HOME="$TEMP_DIR/state" \
        "$BUN_BIN" "$WORKSPACE" "$@"
}

session_id() {
    tmux_test list-sessions -F '#{session_id}|#{session_name}' \
        | awk -F '|' -v name="$1" '$2 == name { print $1; exit }'
}

window_rows() {
    tmux_test list-windows -t "$1" -F '#{window_index}:#{window_name}:#{@dotfiles_workspace_window_id}:#{@dotfiles_window_type}'
}

window_id() {
    tmux_test list-windows -t "$1" -F '#{window_id}|#{@dotfiles_workspace_window_id}' \
        | awk -F '|' -v id="$2" '$2 == id { print $1; exit }'
}

pane_ids() {
    tmux_test list-panes -t "$1" -F '#{@dotfiles_workspace_pane_id}' | sort
}

mkdir -p "$LAYOUT_DIR" "$PROJECT_DIR" "$FAKE_BIN"
cp "$DOTFILES_DIR/home/dot_config/tmux/layouts/project.tmux.tsx" "$LAYOUT_DIR/project.tmux.tsx"

cat > "$FAKE_BIN/codex" <<'EOF'
#!/usr/bin/env bash
exec sleep 300
EOF
cat > "$FAKE_BIN/nvim" <<'EOF'
#!/usr/bin/env bash
exec sleep 300
EOF
chmod +x "$FAKE_BIN/codex" "$FAKE_BIN/nvim"

cat > "$LAYOUT_DIR/command.tmux.tsx" <<'EOF'
const Shells = () => (
  <Window id="shells" name="shells">
    <Cols sizes="3fr 1fr">
      <Pane id="left" run={`printf run >> "${process.env.COMMAND_LOG}"; exec sleep 300`} focus />
      <Pane id="right" />
    </Cols>
  </Window>
)

export default <Session root="$PROJECT_ROOT"><Shells /></Session>
EOF

cat > "$LAYOUT_DIR/invalid.tmux.tsx" <<'EOF'
export default <Session><Window id="broken"><Grid><Pane /><Pane /></Grid></Window></Session>
EOF

echo "================================"
echo "Tmux Workspace Tests"
echo "================================"

if [[ -n "$BUN_BIN" ]]; then
    pass "Bun is installed"
else
    fail "Bun is installed" "bun on PATH" "not found"
fi

if [[ -x "$WORKSPACE" ]]; then
    pass "tmux-workspace helper is executable"
else
    fail "tmux-workspace helper is executable" "executable" "not executable"
fi

echo ""
echo "Testing JSX validation and planning..."
assert_equals "managed layouts are discoverable" $'command\ninvalid\nproject' "$(workspace list)"

PLAN=$(workspace plan project --root "$PROJECT_DIR" --session plan-test --json 2>&1)
PLAN_STATUS=$?
assert_equals "project layout plans without tmux mutations" "0" "$PLAN_STATUS"
assert_equals \
    "plan preserves nested reusable components, ratios, and focus" \
    'plan-test|4|cols|nvim' \
    "$(jq -r '[.session, (.windows | length), .windows[3].panes.kind, (.windows[] | select(.focus).id)] | join("|")' <<<"$PLAN")"
assert_equals \
    "plan expands roots containing spaces and apostrophes without shell evaluation" \
    "$(cd "$PROJECT_DIR" && pwd -P)" \
    "$(jq -r '.root' <<<"$PLAN")"

INVALID_OUTPUT=$(workspace validate invalid --root "$PROJECT_DIR" 2>&1)
INVALID_STATUS=$?
if [[ "$INVALID_STATUS" -ne 0 ]]; then
    pass "unknown JSX layout elements are rejected"
else
    fail "unknown JSX layout elements are rejected" "nonzero exit" "$INVALID_STATUS"
fi
assert_contains_text "validation identifies the invalid element" "Grid is not defined" "$INVALID_OUTPUT"

COMMAND_LOG="$TEMP_DIR/command.log"
export COMMAND_LOG
workspace plan command --root "$PROJECT_DIR" --session command-plan >/dev/null
assert_equals "planning never runs pane commands" "missing" "$([[ -e "$COMMAND_LOG" ]] && echo present || echo missing)"

echo ""
echo "Testing fresh application and idempotency..."
APPLY_OUTPUT=$(workspace apply project --root "$PROJECT_DIR" --session jsx-test 2>&1)
APPLY_STATUS=$?
assert_equals "project layout applies to an isolated tmux server" "0" "$APPLY_STATUS"
assert_contains_text "apply reports the managed layout" "applied project to jsx-test" "$APPLY_OUTPUT"

SESSION_ID=$(session_id jsx-test)
assert_equals \
    "layout creates typed windows at stable indices" \
    $'0:terminal:terminal:terminal\n1:codex:codex:codex\n2:nvim:nvim:nvim\n3:runtime:runtime:' \
    "$(window_rows "$SESSION_ID")"
assert_equals \
    "layout session records its source and skips the automatic template" \
    $'workspace\nskip\nproject' \
    "$(
        tmux_test show-options -qv -t "$SESSION_ID" @dotfiles_tmux_template
        tmux_test show-environment -t "$SESSION_ID" DOTFILES_TMUX_TEMPLATE | sed 's/^[^=]*=//'
        tmux_test show-options -qv -t "$SESSION_ID" @dotfiles_workspace
    )"

RUNTIME_ID=$(window_id "$SESSION_ID" runtime)
assert_equals \
    "nested runtime layout creates three stable panes" \
    $'server\nshell\ntests' \
    "$(pane_ids "$RUNTIME_ID")"
assert_equals \
    "focused JSX window becomes active" \
    "nvim" \
    "$(tmux_test list-windows -t "$SESSION_ID" -F '#{?window_active,#{@dotfiles_workspace_window_id},}' | sed '/^$/d')"

WINDOW_IDS_BEFORE=$(tmux_test list-windows -t "$SESSION_ID" -F '#{window_id}:#{@dotfiles_workspace_window_id}' | sort)
PANE_IDS_BEFORE=$(tmux_test list-panes -s -t "$SESSION_ID" -F '#{pane_id}:#{@dotfiles_workspace_pane_id}' | sort)
workspace apply --session-id "$SESSION_ID" >/dev/null
assert_equals \
    "repeated apply preserves every managed window" \
    "$WINDOW_IDS_BEFORE" \
    "$(tmux_test list-windows -t "$SESSION_ID" -F '#{window_id}:#{@dotfiles_workspace_window_id}' | sort)"
assert_equals \
    "repeated apply preserves every running pane" \
    "$PANE_IDS_BEFORE" \
    "$(tmux_test list-panes -s -t "$SESSION_ID" -F '#{pane_id}:#{@dotfiles_workspace_pane_id}' | sort)"

echo ""
echo "Testing ownership, tree drift, and persistence metadata..."
tmux_test new-session -d -s collision-test -c "$PROJECT_DIR" -n existing
COLLISION_OUTPUT=$(workspace apply project --root "$PROJECT_DIR" --session collision-test 2>&1)
COLLISION_STATUS=$?
if [[ "$COLLISION_STATUS" -ne 0 ]]; then
    pass "same-name unmanaged sessions are never taken over silently"
else
    fail "same-name unmanaged sessions are never taken over silently" "nonzero exit" "$COLLISION_STATUS"
fi
assert_contains_text "collision error requires explicit adoption" "rerun with --adopt" "$COLLISION_OUTPUT"
assert_equals \
    "refused collision leaves the existing session untouched" \
    '1|' \
    "$(printf '%s|' "$(tmux_test list-windows -t '=collision-test' -F '#{window_id}' | wc -l | tr -d '[:space:]')"; tmux_test show-options -qv -t '=collision-test' @dotfiles_workspace)"

tmux_test select-layout -t "$RUNTIME_ID" even-horizontal >/dev/null
GEOMETRY_OUTPUT=$(workspace apply --session-id "$SESSION_ID" 2>&1)
GEOMETRY_STATUS=$?
if [[ "$GEOMETRY_STATUS" -ne 0 ]]; then
    pass "apply detects changed pane orientation and ratios"
else
    fail "apply detects changed pane orientation and ratios" "nonzero exit" "$GEOMETRY_STATUS"
fi
assert_contains_text "geometry drift identifies the affected window" "layout drift in runtime" "$GEOMETRY_OUTPUT"
workspace repair --session-id "$SESSION_ID" --yes >/dev/null
RUNTIME_ID=$(window_id "$SESSION_ID" runtime)
workspace apply --session-id "$SESSION_ID" >/dev/null
pass "repair restores a tree that passes structural validation"

workspace snapshot save >/dev/null
tmux_test set-option -qu -t "$SESSION_ID" @dotfiles_workspace
tmux_test set-option -qu -t "$SESSION_ID" @dotfiles_workspace_path
tmux_test set-option -qu -t "$SESSION_ID" @dotfiles_workspace_root
tmux_test set-option -qu -t "$SESSION_ID" @dotfiles_tmux_template
tmux_test set-environment -u -t "$SESSION_ID" DOTFILES_TMUX_TEMPLATE
while IFS= read -r window; do
    tmux_test set-option -wqu -t "$window" @dotfiles_workspace_window_id
    tmux_test set-option -wqu -t "$window" @dotfiles_workspace_spec_hash
    tmux_test set-option -wqu -t "$window" @dotfiles_window_type
done < <(tmux_test list-windows -t "$SESSION_ID" -F '#{window_id}')
while IFS= read -r pane; do
    tmux_test set-option -pqu -t "$pane" @dotfiles_workspace_pane_id
done < <(tmux_test list-panes -s -t "$SESSION_ID" -F '#{pane_id}')
workspace snapshot restore >/dev/null
assert_equals \
    "persistence sidecar restores session and typed-window identity" \
    $'project\nterminal\ncodex\nnvim\nruntime' \
    "$(tmux_test show-options -qv -t "$SESSION_ID" @dotfiles_workspace; tmux_test list-windows -t "$SESSION_ID" -F '#{@dotfiles_workspace_window_id}')"
assert_equals \
    "persistence sidecar restores stable pane identity" \
    $'main\nmain\nmain\nserver\ntests\nshell' \
    "$(tmux_test list-panes -s -t "$SESSION_ID" -F '#{@dotfiles_workspace_pane_id}')"
workspace apply --session-id "$SESSION_ID" >/dev/null
pass "restored metadata supports layout-free apply"

echo ""
echo "Testing command-once behavior and safe repair..."
workspace apply command --root "$PROJECT_DIR" --session command-test >/dev/null
sleep 0.1
assert_equals "pane commands run when first created" "run" "$(cat "$COMMAND_LOG" 2>/dev/null || true)"
workspace apply command --root "$PROJECT_DIR" --session command-test >/dev/null
sleep 0.1
assert_equals "repeated apply does not rerun commands" "run" "$(cat "$COMMAND_LOG" 2>/dev/null || true)"

TERMINAL_ID_BEFORE=$(window_id "$SESSION_ID" terminal)
CODEX_ID_BEFORE=$(window_id "$SESSION_ID" codex)
NVIM_ID_BEFORE=$(window_id "$SESSION_ID" nvim)
TESTS_PANE=$(tmux_test list-panes -t "$RUNTIME_ID" -F '#{pane_id}|#{@dotfiles_workspace_pane_id}' \
    | awk -F '|' '$2 == "tests" { print $1; exit }')
tmux_test kill-pane -t "$TESTS_PANE"

DRIFT_OUTPUT=$(workspace apply project --root "$PROJECT_DIR" --session jsx-test 2>&1)
DRIFT_STATUS=$?
if [[ "$DRIFT_STATUS" -ne 0 ]]; then
    pass "apply reports structural drift without destroying the window"
else
    fail "apply reports structural drift without destroying the window" "nonzero exit" "$DRIFT_STATUS"
fi
assert_contains_text "drift output explains the repair command" "layout drift in runtime" "$DRIFT_OUTPUT"
assert_equals "drifted window remains in place until explicit repair" "$RUNTIME_ID" "$(window_id "$SESSION_ID" runtime)"

REPAIR_OUTPUT=$(workspace repair --session jsx-test --yes 2>&1)
REPAIR_STATUS=$?
assert_equals "explicit repair succeeds" "0" "$REPAIR_STATUS"
assert_contains_text "repair reports completion" "repaired project in jsx-test" "$REPAIR_OUTPUT"
RUNTIME_ID_AFTER=$(window_id "$SESSION_ID" runtime)
if [[ "$RUNTIME_ID_AFTER" != "$RUNTIME_ID" ]]; then
    pass "repair transactionally replaces only the drifted window"
else
    fail "repair transactionally replaces only the drifted window" "new window id" "$RUNTIME_ID_AFTER"
fi
assert_equals \
    "repair preserves healthy typed windows" \
    "$TERMINAL_ID_BEFORE|$CODEX_ID_BEFORE|$NVIM_ID_BEFORE" \
    "$(window_id "$SESSION_ID" terminal)|$(window_id "$SESSION_ID" codex)|$(window_id "$SESSION_ID" nvim)"
assert_equals "repair restores the declared pane tree" $'server\nshell\ntests' "$(pane_ids "$RUNTIME_ID_AFTER")"

echo ""
echo "Testing adoption of an existing typed session..."
tmux_test set-environment -g PATH "$FAKE_BIN:$PATH"
tmux_test new-session -d -s adopt-test -c "$PROJECT_DIR" -n terminal
tmux_test set-option -wq -t '=adopt-test:terminal' @dotfiles_window_type terminal
tmux_test new-window -d -t '=adopt-test:' -c "$PROJECT_DIR" -n codex "$FAKE_BIN/codex"
tmux_test set-option -wq -t '=adopt-test:codex' @dotfiles_window_type codex
tmux_test new-window -d -t '=adopt-test:' -c "$PROJECT_DIR" -n nvim "$FAKE_BIN/nvim"
tmux_test set-option -wq -t '=adopt-test:nvim' @dotfiles_window_type nvim
ADOPT_SESSION_ID=$(session_id adopt-test)
ADOPT_IDS_BEFORE=$(tmux_test list-windows -t "$ADOPT_SESSION_ID" -F '#{window_id}' | sort)
workspace apply project --root "$PROJECT_DIR" --session adopt-test --adopt >/dev/null
assert_equals \
    "workspace adopts existing typed windows instead of duplicating them" \
    "4" \
    "$(tmux_test list-windows -t "$ADOPT_SESSION_ID" -F '#{window_id}' | wc -l | tr -d '[:space:]')"
assert_equals \
    "adoption preserves every pre-existing typed window id" \
    "$ADOPT_IDS_BEFORE" \
    "$(tmux_test list-windows -t "$ADOPT_SESSION_ID" -F '#{window_id}:#{@dotfiles_workspace_window_id}' \
        | awk -F ':' '$2 == "terminal" || $2 == "codex" || $2 == "nvim" { print $1 }' | sort)"
assert_equals \
    "adopted windows receive workspace metadata" \
    $'terminal\ncodex\nnvim\nruntime' \
    "$(tmux_test list-windows -t "$ADOPT_SESSION_ID" -F '#{@dotfiles_workspace_window_id}')"
assert_equals \
    "adoption preserves the already-running typed processes" \
    $'sleep\nsleep' \
    "$(tmux_test display-message -p -t '=adopt-test:codex' '#{pane_current_command}'; tmux_test display-message -p -t '=adopt-test:nvim' '#{pane_current_command}')"

echo ""
echo "Testing detached managed-session cleanup..."
CLEAN_PREVIEW=$(workspace clean)
assert_contains_text "cleanup preview lists detached managed layouts" "jsx-test" "$CLEAN_PREVIEW"
workspace clean --yes >/dev/null
assert_equals \
    "confirmed cleanup removes only managed detached layouts" \
    "collision-test" \
    "$(tmux_test list-sessions -F '#{session_name}')"

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

exit "$FAILED"
