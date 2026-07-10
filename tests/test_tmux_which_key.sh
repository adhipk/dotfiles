#!/usr/bin/env bash

# Tests for the repo-owned tmux-which-key command center.

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(dirname "$TEST_DIR")"
CONFIG="$DOTFILES_DIR/home/dot_config/tmux/which-key.yaml"
TMUX_CONFIG="$DOTFILES_DIR/home/dot_tmux.conf"
PLUGIN_DIR="${HOME}/.tmux/plugins/tmux-which-key"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-tmux-which-key-test.XXXXXX")"
GENERATED="$TEMP_DIR/init.tmux"
SOCKET_NAME="dotfiles-which-key-test-$$"

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

assert_contains() {
    local name="$1"
    local pattern="$2"
    local actual="$3"

    if grep -q -- "$pattern" <<<"$actual"; then
        pass "$name"
    else
        fail "$name" "text containing $pattern" "$actual"
    fi
}

echo "================================"
echo "Tmux Command Center Tests"
echo "================================"

if [[ -f "$CONFIG" ]]; then
    pass "repo-owned tmux command-center YAML exists"
else
    fail "repo-owned tmux command-center YAML exists" "$CONFIG" "missing"
fi

if yq eval '.' "$CONFIG" >/dev/null 2>&1; then
    pass "command-center YAML parses"
else
    fail "command-center YAML parses" "valid YAML" "parse error"
fi

if [[ -x "$PLUGIN_DIR/plugin/build.py" ]]; then
    pass "tmux-which-key builder is installed"
else
    fail "tmux-which-key builder is installed" "$PLUGIN_DIR/plugin/build.py" "missing"
fi

if python3 "$PLUGIN_DIR/plugin/build.py" "$CONFIG" "$GENERATED" >/dev/null 2>&1; then
    pass "upstream plugin builds the managed YAML"
else
    fail "upstream plugin builds the managed YAML" "generated init.tmux" "build failed"
fi

tmux -L "$SOCKET_NAME" -f /dev/null new-session -d -s command-center
SOURCE_OUTPUT=$(tmux -L "$SOCKET_NAME" source-file "$GENERATED" 2>&1)
SOURCE_STATUS=$?
if [[ "$SOURCE_STATUS" -eq 0 ]]; then
    pass "generated command center loads in tmux"
else
    fail "generated command center loads in tmux" "source exit 0" "$SOURCE_OUTPUT"
fi

# Ghostty/skhd send F16-F19, which xterm-compatible terminal protocols expose
# to tmux as Shift+F4 through Shift+F7. Parse the actual bridge declarations so
# unsupported tmux key names fail this suite instead of failing only at reload.
LAYER_SOURCE_OUTPUT=$(
    grep -E '^bind-key -n -N .*S-F[4-7]' "$TMUX_CONFIG" \
        | tmux -L "$SOCKET_NAME" source-file - 2>&1
)
LAYER_SOURCE_STATUS=$?
if [[ "$LAYER_SOURCE_STATUS" -eq 0 ]]; then
    pass "Right Command terminal bridge loads in tmux"
else
    fail "Right Command terminal bridge loads in tmux" "source exit 0" "$LAYER_SOURCE_OUTPUT"
fi

PREFIX_BINDING=$(tmux -L "$SOCKET_NAME" list-keys -T prefix Space 2>/dev/null || true)
assert_contains "Ctrl-a Space opens the command center" "display-menu" "$PREFIX_BINDING"

# Loading generated tmux source only validates the stored strings. Drive the
# actual key sequence through a pseudo-terminal so deferred submenu commands
# are expanded and parsed exactly as they are for an interactive client.
MENU_RUNTIME_LOG="$TEMP_DIR/menu-runtime.log"
if WK_SOCKET_NAME="$SOCKET_NAME" /usr/bin/expect >"$MENU_RUNTIME_LOG" 2>&1 <<'EOF'
log_user 0
set timeout 5
set env(TMUX) ""
set env(TERM) "xterm-256color"

spawn tmux -L $env(WK_SOCKET_NAME) attach-session -t command-center
after 300
send -- "\002"
after 100
send -- " "
expect {
    -re {Syntax error|[Nn]ot enough arguments} {
        puts "root menu failed to parse"
        exit 2
    }
    -re {Sessions} {}
    timeout {
        puts "root menu did not open"
        exit 3
    }
}

after 100
send -- "s"
expect {
    -re {Syntax error|[Nn]ot enough arguments} {
        puts "Sessions submenu failed to parse"
        exit 4
    }
    -re {New named session} {}
    timeout {
        puts "Sessions submenu did not open"
        exit 5
    }
}
exit 0
EOF
then
    pass "Sessions submenu parses when displayed"
else
    fail \
        "Sessions submenu parses when displayed" \
        "interactive menu opens without a parser error" \
        "$(cat "$MENU_RUNTIME_LOG")"
fi

PROBE="$TEMP_DIR/tmux-workspace-probe"
PROBE_ARGS="$TEMP_DIR/probe-args"
cat > "$PROBE" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$TMUX_WORKSPACE_PROBE_FILE"
EOF
chmod +x "$PROBE"
tmux -L "$SOCKET_NAME" set-environment -g TMUX_WORKSPACE_PROBE_FILE "$PROBE_ARGS"
tmux -L "$SOCKET_NAME" run-shell "$PROBE apply --session-id #{q:session_id}"
if [[ "$(cat "$PROBE_ARGS" 2>/dev/null || true)" == 'apply --session-id $0' ]]; then
    pass "quoted tmux session ids survive the command-center shell"
else
    fail \
        "quoted tmux session ids survive the command-center shell" \
        'apply --session-id $0' \
        "$(cat "$PROBE_ARGS" 2>/dev/null || true)"
fi

SESSIONS=$(tmux -L "$SOCKET_NAME" show-options -gv @wk_menu_sessions 2>/dev/null || true)
assert_contains "session menu opens the sesh picker" "tmux-sessionizer-zoxide" "$SESSIONS"
assert_contains "session menu uses client-local tmux history" "switch-client -l" "$SESSIONS"
assert_contains "session menu navigates previous sessions" "switch-client -p" "$SESSIONS"
assert_contains "session menu navigates next sessions" "switch-client -n" "$SESSIONS"
assert_contains "session menu creates named sessions" "New named session" "$SESSIONS"
assert_contains "session menu renames sessions" "rename-session" "$SESSIONS"
assert_contains "session rename shows active folder context" "pane_current_path" "$SESSIONS"
assert_contains "numeric sessions receive a contextual suggestion" "m/r:" "$SESSIONS"
assert_contains "session rename accepts literal punctuation" "command-prompt -l" "$SESSIONS"
assert_contains "session rename preserves the full prompted name" "%%%" "$SESSIONS"
assert_contains "session close is confirmed" "Close session" "$SESSIONS"
assert_contains "session menu exposes server-wide persistence" "Save all state" "$SESSIONS"
assert_contains "session menu cleans detached managed layouts" "tmux-workspace clean" "$SESSIONS"

WINDOWS=$(tmux -L "$SOCKET_NAME" show-options -gv @wk_menu_windows 2>/dev/null || true)
NEW_WINDOWS=$(tmux -L "$SOCKET_NAME" show-options -gv @wk_menu_new 2>/dev/null || true)
assert_contains "window menu uses typed cycling" "tmux-session-template cycle" "$WINDOWS"
assert_contains "window menu creates typed windows" "tmux-session-template new" "$NEW_WINDOWS"
assert_contains "window menu cycles Tuxedo windows" "cycle #{session_id} tuxedo" "$WINDOWS"
assert_contains "window menu creates Tuxedo windows" "new #{session_id} tuxedo" "$NEW_WINDOWS"
assert_contains "window menu duplicates the current typed window" "tmux-session-template duplicate" "$WINDOWS"
assert_contains "window menu renames windows" "rename-window" "$WINDOWS"
assert_contains "window close is confirmed" "Close window" "$WINDOWS"

PANES=$(tmux -L "$SOCKET_NAME" show-options -gv @wk_menu_panes 2>/dev/null || true)
assert_contains "pane menu preserves cwd when splitting" "pane_current_path" "$PANES"
assert_contains "pane menu includes navigation" "select-pane -L" "$PANES"
assert_contains "pane menu includes resizing" "@wk_menu_resize" "$PANES"
assert_contains "pane menu includes Yazi" "tmux-yazi-pane" "$PANES"
assert_contains "pane close is confirmed" "Close pane" "$PANES"

LAYOUTS=$(tmux -L "$SOCKET_NAME" show-options -gv @wk_menu_layouts 2>/dev/null || true)
assert_contains "layout menu opens the JSX picker" "tmux-workspace pick" "$LAYOUTS"
assert_contains "layout takeover is an explicit adopt action" "--adopt" "$LAYOUTS"
assert_contains "layout menu applies the active workspace" "tmux-workspace apply" "$LAYOUTS"
assert_contains "layout repair is explicit" "tmux-workspace repair" "$LAYOUTS"
assert_contains "layout actions pass safe pane identifiers" "--pane #{pane_id}" "$LAYOUTS"
assert_contains "layout actions shell-quote safe session identifiers" "--session-id #{q:session_id}" "$LAYOUTS"
assert_contains "layout popup remains visible on errors" "display-popup -EE" "$LAYOUTS"
if ! grep -q 'pane_current_path\|#S' <<<"$LAYOUTS"; then
    pass "layout actions never interpolate shell-sensitive names or paths"
else
    fail "layout actions never interpolate shell-sensitive names or paths" "no raw path or name formats" "$LAYOUTS"
fi

COPY_MENU=$(tmux -L "$SOCKET_NAME" show-options -gv @wk_menu_copy 2>/dev/null || true)
assert_contains "copy menu exposes forward search" "search-forward" "$COPY_MENU"
assert_contains "copy menu exposes backward search" "search-backward" "$COPY_MENU"

assert_contains \
    "tmux config includes meaningful persistent session identity" \
    "▌ #{?#{m/r:" \
    "$(grep 'status-left ' "$TMUX_CONFIG")"
assert_contains \
    "tmux config declares automatic persistence" \
    "@continuum-restore" \
    "$(cat "$TMUX_CONFIG")"
assert_contains \
    "tmux config rehydrates layout metadata after restore" \
    "tmux-workspace snapshot restore" \
    "$(cat "$TMUX_CONFIG")"
assert_contains \
    "tmux config restores Codex, Tuxedo, and Yazi processes" \
    "@resurrect-processes 'codex tuxedo yazi'" \
    "$(cat "$TMUX_CONFIG")"
assert_contains \
    "tmux persistence plugin is version-pinned" \
    "tmux-resurrect#v4.0.0" \
    "$(cat "$TMUX_CONFIG")"
assert_contains \
    "installer pins the tested command-center revision" \
    "85fb9756447b989f3b94e515d1e6ee7fec76cba2" \
    "$(cat "$DOTFILES_DIR/install.sh")"
assert_contains \
    "tmux config keeps stock-macOS-compatible command-center ownership" \
    "install.sh links the repo-owned" \
    "$(cat "$TMUX_CONFIG")"

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

exit "$FAILED"
