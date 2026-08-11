#!/usr/bin/env bash

# Lifecycle tests for the default tmux session template.

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$TEST_DIR")"
DOTFILES_DIR="$(cd "$MODULE_DIR/../.." && pwd)"
TEMPLATE_HELPER="$MODULE_DIR/bin/tmux-session-template"
TODO_FIXTURE="$TEST_DIR/fixtures/todo"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-tmux-template-test.XXXXXX")"
SOCKET_NAME="dotfiles-template-test-$$"
FAKE_BIN="$TEMP_DIR/bin"
PROJECT_DIR="$TEMP_DIR/project"
TYPE_DIR="$PROJECT_DIR/current-pane"
TMUX_CONFIG="$TEMP_DIR/tmux.conf"
TUXEDO_CALLS_FILE="$TEMP_DIR/tuxedo-calls"

PASSED=0
FAILED=0

export DOTFILES_LIB_DIR="$DOTFILES_DIR/home/dot_local/lib/dotfiles"

cleanup() {
    local attempt
    tmux -L "$SOCKET_NAME" kill-server >/dev/null 2>&1 || true
    for attempt in {1..20}; do
        rm -rf "$TEMP_DIR" 2>/dev/null || true
        [[ -e "$TEMP_DIR" ]] || return 0
        sleep 0.02
    done
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

window_id_at_index() {
    local session="$1"
    local target_index="$2"

    tmux_test list-windows -t "=$session" -F '#{window_index} #{window_id}' \
        | awk -v target_index="$target_index" '$1 == target_index { print $2; exit }'
}

window_type() {
    tmux_test show-options -wqv -t "$1" @dotfiles_window_type 2>/dev/null || true
}

active_window_id() {
    tmux_test list-windows -t "=$1" -F '#{?window_active,#{window_id},}' | sed '/^$/d'
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

wait_for_tuxedo_calls() {
    local expected="$1"
    local attempt

    for attempt in {1..100}; do
        if [[ -f "$TUXEDO_CALLS_FILE" ]] \
            && [[ "$(wc -l < "$TUXEDO_CALLS_FILE" | tr -d '[:space:]')" -ge "$expected" ]]; then
            return 0
        fi
        sleep 0.02
    done
    return 1
}

mkdir -p "$FAKE_BIN" "$PROJECT_DIR" "$TYPE_DIR"

cat > "$FAKE_BIN/codex" <<'EOF'
#!/usr/bin/env bash
exec sleep 300
EOF
cat > "$FAKE_BIN/nvim" <<'EOF'
#!/usr/bin/env bash
exec sleep 300
EOF
TUXEDO_CALLS_FILE_QUOTED=$(printf '%q' "$TUXEDO_CALLS_FILE")
cp "$TODO_FIXTURE" "$FAKE_BIN/todo"
cat > "$FAKE_BIN/tuxedo" <<EOF
#!/usr/bin/env bash
printf '%s|%s|%s|%s\n' "\$PWD" "\$TODO_DIR" "\$TODO_FILE" "\$DONE_FILE" >> $TUXEDO_CALLS_FILE_QUOTED
exec sleep 300
EOF
chmod +x "$FAKE_BIN/codex" "$FAKE_BIN/nvim" "$FAKE_BIN/todo" "$FAKE_BIN/tuxedo"

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
mkdir -p "$TEMP_DIR/home"
HOME="$TEMP_DIR/home" \
    PATH="$FAKE_BIN:$PATH" \
    TODO_DIR="$TEMP_DIR/wrong" \
    TODO_FILE="$TEMP_DIR/wrong/todo.txt" \
    DONE_FILE="$TEMP_DIR/wrong/done.txt" \
    tmux -L "$SOCKET_NAME" -f "$TMUX_CONFIG" \
    new-session -d -s bootstrap "sleep 300"
tmux_test set-environment -g PATH "$FAKE_BIN:$PATH"

echo ""
echo "Testing the automatic template..."
new_session -d -s ordinary -c "$PROJECT_DIR"
assert_equals \
    "ordinary sessions get terminal/codex/nvim/tuxedo at 0/1/2/3" \
    $'0:terminal\n1:codex\n2:nvim\n3:tuxedo' \
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
assert_equals \
    "template windows carry stable terminal/codex/nvim/tuxedo type metadata" \
    $'terminal\ncodex\nnvim\ntuxedo' \
    "$(
        window_type "$(window_id_at_index ordinary 0)"
        window_type "$(window_id_at_index ordinary 1)"
        window_type "$(window_id_at_index ordinary 2)"
        window_type "$(window_id_at_index ordinary 3)"
    )"
sleep 0.1
wait_for_tuxedo_calls 1 || true
assert_equals \
    "automatic Tuxedo keeps the session directory while opening the global task store" \
    "$CANONICAL_PROJECT_DIR|$TEMP_DIR/home/.agents/tasks|$TEMP_DIR/home/.agents/tasks/todo.txt|$TEMP_DIR/home/.agents/tasks/done.txt" \
    "$(head -n 1 "$TUXEDO_CALLS_FILE" 2>/dev/null || true)"
assert_equals \
    "Codex, Neovim, and the todo wrapper run in their windows" \
    $'sleep\nsleep\nsleep' \
    "$(
        tmux_test list-panes -t '=ordinary:codex' -F '#{pane_current_command}'
        tmux_test list-panes -t '=ordinary:nvim' -F '#{pane_current_command}'
        tmux_test list-panes -t '=ordinary:tuxedo' -F '#{pane_current_command}'
    )"
echo ""
echo "Testing typed window creation and cycling..."
tmux_test set-environment -t ordinary PATH "$FAKE_BIN:$PATH"
tmux_test set-environment -t ordinary HOME "$TEMP_DIR/home"
tmux_test set-option -t ordinary default-command \
    "env PATH=$FAKE_BIN:$PATH HOME=$TEMP_DIR/home /bin/bash --noprofile --norc"
TERMINAL_PANE=$(tmux_test list-panes -t '=ordinary:0' -F '#{pane_id}' | head -n 1)
tmux_test send-keys -l -t "$TERMINAL_PANE" "cd -- '$TYPE_DIR'"
tmux_test send-keys -t "$TERMINAL_PANE" C-m
sleep 0.1
CANONICAL_TYPE_DIR=$(cd "$TYPE_DIR" && pwd -P)
CANONICAL_CODEX_ID=$(window_id_at_index ordinary 1)
CANONICAL_NVIM_ID=$(window_id_at_index ordinary 2)
CANONICAL_TUXEDO_ID=$(window_id_at_index ordinary 3)
TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" \
    "$TEMPLATE_HELPER" new ordinary codex "$TERMINAL_PANE"
NEW_CODEX_ID=$(active_window_id ordinary)
assert_equals \
    "new Codex creates and selects one duplicate in the source pane directory" \
    "5|codex|codex|$CANONICAL_TYPE_DIR|$NEW_CODEX_ID" \
    "$(
        printf '%s|' "$(session_window_count ordinary)"
        printf '%s|' "$(window_type "$NEW_CODEX_ID")"
        printf '%s|' "$(tmux_test display-message -p -t "$NEW_CODEX_ID" '#{window_name}')"
        printf '%s|' "$(tmux_test display-message -p -t "$NEW_CODEX_ID" '#{pane_current_path}')"
        active_window_id ordinary
    )"
sleep 0.1
assert_equals \
    "new Codex starts only in the captured duplicate window" \
    $'sleep\nsleep' \
    "$(
        tmux_test display-message -p -t "$CANONICAL_CODEX_ID" '#{pane_current_command}'
        tmux_test display-message -p -t "$NEW_CODEX_ID" '#{pane_current_command}'
    )"

tmux_test select-pane -t "$NEW_CODEX_ID" -T codex-pane-title
tmux_test rename-window -t "$NEW_CODEX_ID" feature-auth
assert_equals \
    "renaming a duplicate preserves its Codex type" \
    "codex" \
    "$(window_type "$NEW_CODEX_ID")"
assert_equals \
    "renamed Codex windows still seed renames from the pane title" \
    "codex-pane-title" \
    "$(tmux_test display-message -p -t "$NEW_CODEX_ID" '#{?#{||:#{==:#{@dotfiles_window_type},codex},#{==:#W,codex}},#T,#W}')"
TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" \
    "$TEMPLATE_HELPER" cycle ordinary codex "$NEW_CODEX_ID"
assert_equals \
    "cycling from the last Codex wraps to the canonical Codex" \
    "$CANONICAL_CODEX_ID" \
    "$(active_window_id ordinary)"
TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" \
    "$TEMPLATE_HELPER" cycle ordinary codex "$CANONICAL_CODEX_ID"
assert_equals \
    "cycling reaches a renamed Codex duplicate by type metadata" \
    "$NEW_CODEX_ID" \
    "$(active_window_id ordinary)"
tmux_test select-window -t "$CANONICAL_NVIM_ID"
TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" \
    "$TEMPLATE_HELPER" cycle ordinary codex "$CANONICAL_NVIM_ID"
assert_equals \
    "cycling from another type selects the first Codex" \
    "$CANONICAL_CODEX_ID" \
    "$(active_window_id ordinary)"

TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" \
    "$TEMPLATE_HELPER" ensure ordinary "$PROJECT_DIR"
assert_equals \
    "ensure remains idempotent after a renamed typed duplicate" \
    $'5\nterminal\ncodex\nnvim\ntuxedo\ncodex' \
    "$(
        printf '%s\n' "$(session_window_count ordinary)"
        window_type "$(window_id_at_index ordinary 0)"
        window_type "$(window_id_at_index ordinary 1)"
        window_type "$(window_id_at_index ordinary 2)"
        window_type "$(window_id_at_index ordinary 3)"
        window_type "$NEW_CODEX_ID"
    )"

TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" \
    "$TEMPLATE_HELPER" new ordinary terminal "$TERMINAL_PANE"
NEW_TERMINAL_ID=$(active_window_id ordinary)
assert_equals \
    "new terminal creates a typed shell and selects it" \
    "terminal|terminal|bash|$NEW_TERMINAL_ID" \
    "$(
        printf '%s|' "$(window_type "$NEW_TERMINAL_ID")"
        printf '%s|' "$(tmux_test display-message -p -t "$NEW_TERMINAL_ID" '#{window_name}')"
        printf '%s|' "$(tmux_test display-message -p -t "$NEW_TERMINAL_ID" '#{pane_current_command}')"
        active_window_id ordinary
    )"
TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" \
    "$TEMPLATE_HELPER" cycle ordinary terminal "$NEW_TERMINAL_ID"
assert_equals \
    "terminal cycling wraps to the canonical terminal" \
    "$(window_id_at_index ordinary 0)" \
    "$(active_window_id ordinary)"

TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" \
    "$TEMPLATE_HELPER" new ordinary nvim "$TERMINAL_PANE"
NEW_NVIM_ID=$(active_window_id ordinary)
sleep 0.1
assert_equals \
    "new Neovim creates a typed editor and selects it" \
    "nvim|nvim|sleep|$NEW_NVIM_ID" \
    "$(
        printf '%s|' "$(window_type "$NEW_NVIM_ID")"
        printf '%s|' "$(tmux_test display-message -p -t "$NEW_NVIM_ID" '#{window_name}')"
        printf '%s|' "$(tmux_test display-message -p -t "$NEW_NVIM_ID" '#{pane_current_command}')"
        active_window_id ordinary
    )"
TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" \
    "$TEMPLATE_HELPER" cycle ordinary nvim "$NEW_NVIM_ID"
assert_equals \
    "Neovim cycling wraps to the canonical Neovim" \
    "$CANONICAL_NVIM_ID" \
    "$(active_window_id ordinary)"

TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" \
    "$TEMPLATE_HELPER" new ordinary tuxedo "$TERMINAL_PANE"
NEW_TUXEDO_ID=$(active_window_id ordinary)
sleep 0.1
assert_equals \
    "new Tuxedo creates a typed task window through the todo wrapper" \
    "tuxedo|tuxedo|$CANONICAL_TYPE_DIR|sleep|$NEW_TUXEDO_ID" \
    "$(
        printf '%s|' "$(window_type "$NEW_TUXEDO_ID")"
        printf '%s|' "$(tmux_test display-message -p -t "$NEW_TUXEDO_ID" '#{window_name}')"
        printf '%s|' "$(tmux_test display-message -p -t "$NEW_TUXEDO_ID" '#{pane_current_path}')"
        printf '%s|' "$(tmux_test display-message -p -t "$NEW_TUXEDO_ID" '#{pane_current_command}')"
        active_window_id ordinary
    )"
TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" \
    "$TEMPLATE_HELPER" cycle ordinary tuxedo "$NEW_TUXEDO_ID"
assert_equals \
    "Tuxedo cycling wraps to the canonical Tuxedo" \
    "$CANONICAL_TUXEDO_ID" \
    "$(active_window_id ordinary)"

WINDOW_COUNT_BEFORE_REMOVED_TYPE=$(session_window_count ordinary)
REMOVED_TYPE_STATUS=0
TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" \
    "$TEMPLATE_HELPER" new ordinary awrit "$TERMINAL_PANE" >/dev/null 2>&1 \
    || REMOVED_TYPE_STATUS=$?
assert_equals \
    "the removed Awrit type is rejected without creating a window" \
    "2|$WINDOW_COUNT_BEFORE_REMOVED_TYPE" \
    "$REMOVED_TYPE_STATUS|$(session_window_count ordinary)"

echo ""
echo "Testing typed window duplication..."
NEW_CODEX_PANE=$(tmux_test list-panes -t "$NEW_CODEX_ID" -F '#{pane_id}' | head -n 1)
TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" \
    "$TEMPLATE_HELPER" duplicate ordinary "$NEW_CODEX_PANE"
DUPLICATE_CODEX_ID=$(active_window_id ordinary)
sleep 0.1
assert_equals \
    "duplicate Codex creates and selects a uniquely named typed window" \
    "codex-2|codex|$CANONICAL_TYPE_DIR|sleep|$DUPLICATE_CODEX_ID" \
    "$(
        printf '%s|' "$(tmux_test display-message -p -t "$DUPLICATE_CODEX_ID" '#{window_name}')"
        printf '%s|' "$(window_type "$DUPLICATE_CODEX_ID")"
        printf '%s|' "$(tmux_test display-message -p -t "$DUPLICATE_CODEX_ID" '#{pane_current_path}')"
        printf '%s|' "$(tmux_test display-message -p -t "$DUPLICATE_CODEX_ID" '#{pane_current_command}')"
        active_window_id ordinary
    )"

DUPLICATE_CODEX_PANE=$(tmux_test list-panes -t "$DUPLICATE_CODEX_ID" -F '#{pane_id}' | head -n 1)
TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" \
    "$TEMPLATE_HELPER" duplicate ordinary "$DUPLICATE_CODEX_PANE"
DUPLICATE_CODEX_THREE_ID=$(active_window_id ordinary)
sleep 0.1
assert_equals \
    "duplicating a Codex duplicate advances the visible suffix" \
    "codex-3|codex|sleep|$DUPLICATE_CODEX_THREE_ID" \
    "$(
        printf '%s|' "$(tmux_test display-message -p -t "$DUPLICATE_CODEX_THREE_ID" '#{window_name}')"
        printf '%s|' "$(window_type "$DUPLICATE_CODEX_THREE_ID")"
        printf '%s|' "$(tmux_test display-message -p -t "$DUPLICATE_CODEX_THREE_ID" '#{pane_current_command}')"
        active_window_id ordinary
    )"
TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" \
    "$TEMPLATE_HELPER" cycle ordinary codex "$DUPLICATE_CODEX_ID"
assert_equals \
    "typed cycling includes duplicated Codex windows" \
    "$DUPLICATE_CODEX_THREE_ID" \
    "$(active_window_id ordinary)"

TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" \
    "$TEMPLATE_HELPER" duplicate ordinary "$TERMINAL_PANE"
DUPLICATE_TERMINAL_ID=$(active_window_id ordinary)
assert_equals \
    "duplicate terminal starts a shell in the source pane directory" \
    "terminal-2|terminal|$CANONICAL_TYPE_DIR|bash|$DUPLICATE_TERMINAL_ID" \
    "$(
        printf '%s|' "$(tmux_test display-message -p -t "$DUPLICATE_TERMINAL_ID" '#{window_name}')"
        printf '%s|' "$(window_type "$DUPLICATE_TERMINAL_ID")"
        printf '%s|' "$(tmux_test display-message -p -t "$DUPLICATE_TERMINAL_ID" '#{pane_current_path}')"
        printf '%s|' "$(tmux_test display-message -p -t "$DUPLICATE_TERMINAL_ID" '#{pane_current_command}')"
        active_window_id ordinary
    )"

# Older duplicate windows predate the stable type option. Recover their type
# from the helper-owned numeric suffix so cycling repairs the live metadata.
tmux_test set-option -wqu -t "$DUPLICATE_TERMINAL_ID" @dotfiles_window_type
tmux_test select-window -t "$NEW_TERMINAL_ID"
TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" \
    "$TEMPLATE_HELPER" cycle ordinary terminal "$NEW_TERMINAL_ID"
assert_equals \
    "terminal cycling repairs and reaches an untagged terminal-2 window" \
    "$DUPLICATE_TERMINAL_ID|terminal" \
    "$(active_window_id ordinary)|$(window_type "$DUPLICATE_TERMINAL_ID")"

NEW_NVIM_PANE=$(tmux_test list-panes -t "$NEW_NVIM_ID" -F '#{pane_id}' | head -n 1)
TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" \
    "$TEMPLATE_HELPER" duplicate ordinary "$NEW_NVIM_PANE"
DUPLICATE_NVIM_ID=$(active_window_id ordinary)
sleep 0.1
assert_equals \
    "duplicate Neovim starts the same type in the source pane directory" \
    "nvim-2|nvim|$CANONICAL_TYPE_DIR|sleep|$DUPLICATE_NVIM_ID" \
    "$(
        printf '%s|' "$(tmux_test display-message -p -t "$DUPLICATE_NVIM_ID" '#{window_name}')"
        printf '%s|' "$(window_type "$DUPLICATE_NVIM_ID")"
        printf '%s|' "$(tmux_test display-message -p -t "$DUPLICATE_NVIM_ID" '#{pane_current_path}')"
        printf '%s|' "$(tmux_test display-message -p -t "$DUPLICATE_NVIM_ID" '#{pane_current_command}')"
        active_window_id ordinary
    )"

NEW_TUXEDO_PANE=$(tmux_test list-panes -t "$NEW_TUXEDO_ID" -F '#{pane_id}' | head -n 1)
TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" \
    "$TEMPLATE_HELPER" duplicate ordinary "$NEW_TUXEDO_PANE"
DUPLICATE_TUXEDO_ID=$(active_window_id ordinary)
sleep 0.1
assert_equals \
    "duplicate Tuxedo starts the todo wrapper in the source pane directory" \
    "tuxedo-2|tuxedo|$CANONICAL_TYPE_DIR|sleep|$DUPLICATE_TUXEDO_ID" \
    "$(
        printf '%s|' "$(tmux_test display-message -p -t "$DUPLICATE_TUXEDO_ID" '#{window_name}')"
        printf '%s|' "$(window_type "$DUPLICATE_TUXEDO_ID")"
        printf '%s|' "$(tmux_test display-message -p -t "$DUPLICATE_TUXEDO_ID" '#{pane_current_path}')"
        printf '%s|' "$(tmux_test display-message -p -t "$DUPLICATE_TUXEDO_ID" '#{pane_current_command}')"
        active_window_id ordinary
    )"

tmux_test new-window -d -t '=ordinary:' -n untyped -c "$PROJECT_DIR" "sleep 300"
UNTYPED_ID=$(tmux_test list-windows -t '=ordinary' -F '#{window_id}|#{window_name}' \
    | awk -F '|' '$2 == "untyped" { print $1; exit }')
UNTYPED_PANE=$(tmux_test list-panes -t "$UNTYPED_ID" -F '#{pane_id}' | head -n 1)
WINDOW_COUNT_BEFORE_REJECTED_DUPLICATE=$(session_window_count ordinary)
UNTYPED_DUPLICATE_STATUS=0
TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" \
    "$TEMPLATE_HELPER" duplicate ordinary "$UNTYPED_PANE" >/dev/null 2>&1 \
    || UNTYPED_DUPLICATE_STATUS=$?
assert_equals \
    "duplicate rejects untyped windows without creating anything" \
    "2|$WINDOW_COUNT_BEFORE_REJECTED_DUPLICATE" \
    "$UNTYPED_DUPLICATE_STATUS|$(session_window_count ordinary)"

echo ""
echo "Testing upgrade safety for the new typed slots..."
new_session -d -e DOTFILES_TMUX_TEMPLATE=skip -s pre-tuxedo -c "$PROJECT_DIR" -n terminal
tmux_test move-window -s '=pre-tuxedo:1' -t '=pre-tuxedo:0'
tmux_test set-option -wq -t '=pre-tuxedo:0' @dotfiles_window_type terminal
tmux_test new-window -d -t '=pre-tuxedo:1' -n codex -c "$PROJECT_DIR" "sleep 300"
tmux_test set-option -wq -t '=pre-tuxedo:1' @dotfiles_window_type codex
tmux_test new-window -d -t '=pre-tuxedo:2' -n nvim -c "$PROJECT_DIR" "sleep 300"
tmux_test set-option -wq -t '=pre-tuxedo:2' @dotfiles_window_type nvim
tmux_test new-window -d -t '=pre-tuxedo:3' -n notes -c "$PROJECT_DIR" "sleep 300"
tmux_test set-option -q -t '=pre-tuxedo' @dotfiles_tmux_template standard
PREEXISTING_INDEX_THREE_ID=$(window_id_at_index pre-tuxedo 3)
tmux_test select-window -t "$PREEXISTING_INDEX_THREE_ID"
TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" \
    "$TEMPLATE_HELPER" cycle pre-tuxedo tuxedo "$PREEXISTING_INDEX_THREE_ID"
assert_equals \
    "Tuxedo cycling does not claim an existing untyped index-three window" \
    "$PREEXISTING_INDEX_THREE_ID||notes" \
    "$(
        printf '%s|' "$(active_window_id pre-tuxedo)"
        printf '%s|' "$(window_type "$PREEXISTING_INDEX_THREE_ID")"
        tmux_test display-message -p -t "$PREEXISTING_INDEX_THREE_ID" '#{window_name}'
    )"
TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" \
    "$TEMPLATE_HELPER" ensure pre-tuxedo "$PROJECT_DIR"
sleep 0.1
assert_equals \
    "ensure preserves an existing index-three window while adding Tuxedo" \
    "$PREEXISTING_INDEX_THREE_ID|4|notes||tuxedo|tuxedo" \
    "$(
        printf '%s|' "$PREEXISTING_INDEX_THREE_ID"
        printf '%s|' "$(tmux_test display-message -p -t "$PREEXISTING_INDEX_THREE_ID" '#{window_index}')"
        printf '%s|' "$(tmux_test display-message -p -t "$PREEXISTING_INDEX_THREE_ID" '#{window_name}')"
        printf '%s|' "$(window_type "$PREEXISTING_INDEX_THREE_ID")"
        printf '%s|' "$(tmux_test display-message -p -t '=pre-tuxedo:3' '#{window_name}')"
        window_type "$(window_id_at_index pre-tuxedo 3)"
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
    $'0:terminal\n1:codex\n2:nvim\n3:tuxedo' \
    "$(session_windows "space name")"

DOLLAR_SESSION='$named-session'
new_session -d -e DOTFILES_TMUX_TEMPLATE=skip -s "$DOLLAR_SESSION" -c "$PROJECT_DIR" -n terminal
TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" \
    "$TEMPLATE_HELPER" ensure "$DOLLAR_SESSION" "$PROJECT_DIR"
DOLLAR_SESSION_ID=$(tmux_test list-sessions -F '#{session_id}|#{session_name}' \
    | awk -F '|' -v name="$DOLLAR_SESSION" '$2 == name { print $1; exit }')
assert_equals \
    "literal dollar-prefixed session names are not mistaken for tmux IDs" \
    $'0:terminal\n1:codex\n2:nvim\n3:tuxedo' \
    "$(tmux_test list-windows -t "$DOLLAR_SESSION_ID" -F '#{window_index}:#{window_name}')"

echo ""
echo "Testing explicit reuse by scratchpads..."
: > "$TUXEDO_CALLS_FILE"
new_session -d -e DOTFILES_TMUX_TEMPLATE=skip -s scratchpad -c "$PROJECT_DIR" -n terminal
tmux_test set-environment -t scratchpad PATH "$FAKE_BIN:$PATH"
tmux_test set-option -t scratchpad default-command \
    "env PATH=$FAKE_BIN:$PATH HOME=$TEMP_DIR/home /bin/bash --noprofile --norc"
TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" \
    "$TEMPLATE_HELPER" ensure scratchpad "$PROJECT_DIR"
TMUX_SESSION_TEMPLATE_SOCKET="$SOCKET_NAME" \
    "$TEMPLATE_HELPER" ensure scratchpad "$PROJECT_DIR"
wait_for_tuxedo_calls 1 || true
assert_equals \
    "explicit ensure keeps the requested session directory while opening the global task store" \
    "$TEMP_DIR/project|$TEMP_DIR/home/.agents/tasks|$TEMP_DIR/home/.agents/tasks/todo.txt|$TEMP_DIR/home/.agents/tasks/done.txt" \
    "$(head -n 1 "$TUXEDO_CALLS_FILE" 2>/dev/null || true)"
assert_equals \
    "explicit ensure mode creates the shared layout idempotently" \
    $'0:terminal\n1:codex\n2:nvim\n3:tuxedo' \
    "$(session_windows scratchpad)"
assert_equals \
    "explicit ensure mode does not duplicate windows" \
    "4" \
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
    $'0:terminal\n1:codex\n2:nvim\n3:tuxedo' \
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
