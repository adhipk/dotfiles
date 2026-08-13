#!/usr/bin/env bash

# Integration tests for routing Yazi files into a session-local Neovim window.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$TEST_DIR")"
DOTFILES_DIR="$(cd "$MODULE_DIR/../.." && pwd)"
export DOTFILES_LIB_DIR="$DOTFILES_DIR/home/dot_local/lib/dotfiles"
HELPER="$MODULE_DIR/bin/tmux-yazi-open"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-tmux-yazi-open.XXXXXX")"
SOCKET_NAME="dotfiles-yazi-open-$$"
FAKE_BIN="$TEMP_DIR/bin"
PROJECT_DIR="$TEMP_DIR/project's folder"
NVIM_INIT="$TEMP_DIR/nvim-init.lua"
OPEN_LOG="$TEMP_DIR/opened-file.log"
TEMPLATE_LOG="$TEMP_DIR/template.log"
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
    echo "  ✗ $1"
    echo "    Expected: $2"
    echo "    Actual:   $3"
    ((FAILED++))
}

assert_equals() {
    if [[ "$2" == "$3" ]]; then
        pass "$1"
    else
        fail "$1" "$2" "$3"
    fi
}

wait_for_value() {
    local file="$1"
    local expected="$2"
    local attempt

    for attempt in {1..80}; do
        if [[ -f "$file" && "$(tail -n 1 "$file")" == "$expected" ]]; then
            return 0
        fi
        sleep 0.05
    done
    return 1
}

tmux_test() {
    tmux -L "$SOCKET_NAME" "$@"
}

run_open() {
    local source_pane="$1"
    shift

    PATH="$FAKE_BIN:$PATH" \
        TMUX_PANE="$source_pane" \
        TMUX_YAZI_OPEN_SOCKET="$SOCKET_NAME" \
        TMUX_SESSION_TEMPLATE_BIN="$FAKE_BIN/tmux-session-template" \
        TMUX_YAZI_TEST_NVIM_INIT="$NVIM_INIT" \
        TMUX_YAZI_TEST_NVIM_LOG="$OPEN_LOG" \
        TMUX_YAZI_TEST_PROJECT_DIR="$PROJECT_DIR" \
        TMUX_YAZI_TEST_TEMPLATE_LOG="$TEMPLATE_LOG" \
        "$HELPER" "$@"
}

mkdir -p "$FAKE_BIN" "$PROJECT_DIR"

cat > "$NVIM_INIT" <<'EOF'
vim.api.nvim_create_autocmd('BufEnter', {
  callback = function(event)
    local name = vim.api.nvim_buf_get_name(event.buf)
    local log = vim.env.TMUX_YAZI_TEST_NVIM_LOG
    if name ~= '' and log and log ~= '' then vim.fn.writefile({ name }, log) end
  end,
})
EOF

cat > "$FAKE_BIN/tmux-session-template" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s|%s|%s|%s\n' "$1" "$2" "$3" "$4" > "$TMUX_YAZI_TEST_TEMPLATE_LOG"
window_id=$(
  tmux -L "$DOTFILES_TMUX_SOCKET_NAME" new-window -d -P -F '#{window_id}' \
    -t "$2:" -n nvim -c "$TMUX_YAZI_TEST_PROJECT_DIR" \
    env TMUX_YAZI_TEST_NVIM_LOG="$TMUX_YAZI_TEST_NVIM_LOG" \
      nvim --clean -u "$TMUX_YAZI_TEST_NVIM_INIT"
)
tmux -L "$DOTFILES_TMUX_SOCKET_NAME" set-option -wq -t "$window_id" @dotfiles_window_type nvim
tmux -L "$DOTFILES_TMUX_SOCKET_NAME" select-window -t "$window_id"
EOF
chmod +x "$FAKE_BIN/tmux-session-template"

cat > "$TMUX_CONFIG" <<'EOF'
set -g default-shell /bin/bash
set -g status off
EOF

echo "================================"
echo "Tmux Yazi Neovim Opener Tests"
echo "================================"

if [[ -x "$HELPER" ]]; then
    pass "tmux-yazi-open helper is executable"
else
    fail "tmux-yazi-open helper is executable" "executable" "not executable"
fi

if bash -n "$HELPER"; then
    pass "tmux-yazi-open has valid shell syntax"
else
    fail "tmux-yazi-open has valid shell syntax" "valid bash" "syntax error"
fi

PATH="$FAKE_BIN:$PATH" tmux -L "$SOCKET_NAME" -f "$TMUX_CONFIG" \
    new-session -d -s bootstrap "sleep 300"
tmux_test set-environment -g PATH "$FAKE_BIN:$PATH"
tmux_test set-environment -g TMUX_YAZI_TEST_NVIM_INIT "$NVIM_INIT"
tmux_test set-environment -g TMUX_YAZI_TEST_NVIM_LOG "$OPEN_LOG"
tmux_test set-environment -g TMUX_YAZI_TEST_PROJECT_DIR "$PROJECT_DIR"
tmux_test set-environment -g TMUX_YAZI_TEST_TEMPLATE_LOG "$TEMPLATE_LOG"

echo ""
echo "Testing an existing typed Neovim window..."
tmux_test new-session -d -s existing -n main -c "$PROJECT_DIR" "sleep 300"
MAIN_PANE=$(tmux_test list-panes -t '=existing:main' -F '#{pane_id}')
NVIM_WINDOW=$(
    tmux_test new-window -d -P -F '#{window_id}' -t '=existing:' -n editor -c "$PROJECT_DIR" \
        env TMUX_YAZI_TEST_NVIM_LOG="$OPEN_LOG" nvim --clean -u "$NVIM_INIT"
)
tmux_test set-option -wq -t "$NVIM_WINDOW" @dotfiles_window_type nvim

QUOTED_FILE="$PROJECT_DIR/hidden file's name.txt"
touch "$QUOTED_FILE"
run_open "$MAIN_PANE" "$QUOTED_FILE"
QUOTED_FILE_CANONICAL="$(cd "$(dirname "$QUOTED_FILE")" && pwd -P)/$(basename "$QUOTED_FILE")"
if wait_for_value "$OPEN_LOG" "$QUOTED_FILE_CANONICAL"; then
    pass "a quoted path opens in the existing Neovim window"
else
    fail "a quoted path opens in the existing Neovim window" "$QUOTED_FILE_CANONICAL" "$(cat "$OPEN_LOG" 2>/dev/null || true)"
fi
assert_equals "the existing Neovim window is selected" "$NVIM_WINDOW" "$(tmux_test display-message -p -t '=existing:' '#{window_id}')"
if [[ ! -e "$TEMPLATE_LOG" ]]; then
    pass "an existing Neovim does not create another typed window"
else
    fail "an existing Neovim does not create another typed window" "no template call" "$(cat "$TEMPLATE_LOG")"
fi

echo ""
echo "Testing creation when Neovim is absent..."
rm -f "$OPEN_LOG" "$TEMPLATE_LOG"
tmux_test new-session -d -s absent -n main -c "$PROJECT_DIR" "sleep 300"
ABSENT_MAIN_PANE=$(tmux_test list-panes -t '=absent:main' -F '#{pane_id}')
SECOND_FILE="$PROJECT_DIR/.hidden-config"
touch "$SECOND_FILE"
SECOND_FILE_CANONICAL="$(cd "$(dirname "$SECOND_FILE")" && pwd -P)/$(basename "$SECOND_FILE")"
ABSENT_SESSION_ID=$(tmux_test display-message -p -t "$ABSENT_MAIN_PANE" '#{session_id}')
run_open "$ABSENT_MAIN_PANE" "$SECOND_FILE"
assert_equals \
    "missing Neovim is created through the typed-window helper" \
    "new|$ABSENT_SESSION_ID|nvim|$ABSENT_MAIN_PANE" \
    "$(cat "$TEMPLATE_LOG")"
if wait_for_value "$OPEN_LOG" "$SECOND_FILE_CANONICAL"; then
    pass "the file opens after the Neovim window is created"
else
    fail "the file opens after the Neovim window is created" "$SECOND_FILE_CANONICAL" "$(cat "$OPEN_LOG" 2>/dev/null || true)"
fi
assert_equals \
    "the created window retains typed Neovim metadata" \
    "nvim" \
    "$(tmux_test show-options -wqv -t '=absent:' @dotfiles_window_type)"

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

exit "$FAILED"
