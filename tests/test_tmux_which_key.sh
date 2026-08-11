#!/usr/bin/env bash

# Tests for the Telescope tmux command palette and its curated action catalog.

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(dirname "$TEST_DIR")"
PLUGIN_DIR="${HOME}/.tmux/plugins/tmux-which-key"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-tmux-which-key-test.XXXXXX")"
RENDER_HOME="$TEMP_DIR/home"
mkdir -p "$RENDER_HOME"
chezmoi \
    -S "$DOTFILES_DIR" \
    -D "$RENDER_HOME" \
    --persistent-state "$TEMP_DIR/state.db" \
    apply --exclude=scripts,externals --force >/dev/null
CONFIG="$RENDER_HOME/.config/tmux/which-key.yaml"
TMUX_CONFIG="$RENDER_HOME/.tmux.conf"
PALETTE="$RENDER_HOME/bin/tmux-command-palette"
PALETTE_LUA="$DOTFILES_DIR/nvim/lua/custom/tmux_commands.lua"
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

assert_not_contains() {
    local name="$1"
    local pattern="$2"
    local actual="$3"

    if grep -q -- "$pattern" <<<"$actual"; then
        fail "$name" "text without $pattern" "$actual"
    else
        pass "$name"
    fi
}

echo "================================"
echo "Tmux Telescope Command Palette Tests"
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

# Ghostty/skhd send F16-F20, which xterm-compatible terminal protocols expose
# to tmux as Shift+F4 through Shift+F8. Parse the actual bridge declarations so
# unsupported tmux key names fail this suite instead of failing only at reload.
LAYER_SOURCE_OUTPUT=$(
    grep -E '^bind-key -n -N .*S-F[4-8]' "$TMUX_CONFIG" \
        | tmux -L "$SOCKET_NAME" source-file - 2>&1
)
LAYER_SOURCE_STATUS=$?
if [[ "$LAYER_SOURCE_STATUS" -eq 0 ]]; then
    pass "Right Command terminal bridge loads in tmux"
else
    fail "Right Command terminal bridge loads in tmux" "source exit 0" "$LAYER_SOURCE_OUTPUT"
fi

PALETTE_SOURCE_OUTPUT=$(
    grep -E '^bind-key -N .* Space display-popup' "$TMUX_CONFIG" \
        | tmux -L "$SOCKET_NAME" source-file - 2>&1
)
PALETTE_SOURCE_STATUS=$?
if [[ "$PALETTE_SOURCE_STATUS" -eq 0 ]]; then
    pass "Ctrl-a Space Telescope binding loads in tmux"
else
    fail "Ctrl-a Space Telescope binding loads in tmux" "source exit 0" "$PALETTE_SOURCE_OUTPUT"
fi

PREFIX_BINDING=$(tmux -L "$SOCKET_NAME" list-keys -T prefix Space 2>/dev/null || true)
assert_contains "Ctrl-a Space opens the Telescope palette" "display-popup" "$PREFIX_BINDING"
assert_contains "Ctrl-a Space launches the managed palette" "tmux-command-palette" "$PREFIX_BINDING"

LEGACY_BINDING=$(tmux -L "$SOCKET_NAME" list-keys -T prefix F12 2>/dev/null || true)
assert_contains "legacy display-menu stays off Space" "display-menu" "$LEGACY_BINDING"

if [[ -x "$PALETTE" ]]; then
    pass "Telescope palette launcher is installed"
else
    fail "Telescope palette launcher is installed" "executable $PALETTE" "missing"
fi

SELF_TEST_OUTPUT=$(TMUX_COMMAND_PALETTE_NVIM_CONFIG="$DOTFILES_DIR/nvim" "$PALETTE" --self-test 2>&1)
if [[ "$SELF_TEST_OUTPUT" == "tmux command palette self-test: 8 passed" ]]; then
    pass "Telescope palette parser self-test passes"
else
    fail "Telescope palette parser self-test passes" "8 passed" "$SELF_TEST_OUTPUT"
fi

assert_contains "palette uses the real Telescope picker" "require 'telescope.pickers'" "$(cat "$PALETTE_LUA")"
assert_contains "palette search includes actual command text" "item.command" "$(cat "$PALETTE_LUA")"
assert_contains "palette previews the selected tmux command" "Actual tmux command" "$(cat "$PALETTE_LUA")"
assert_contains "palette explicitly focuses Telescope's prompt" "focus_palette_prompt" "$(cat "$PALETTE_LUA")"
assert_contains "palette handles terminal Enter and Escape process-wide" "vim.on_key" "$(cat "$PALETTE_LUA")"
assert_contains "palette exits its dedicated Neovim process" "qa!" "$(cat "$PALETTE_LUA")"

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
assert_contains "session menu opens the centralized hub" "tmux-hub open" "$SESSIONS"
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
assert_not_contains "window menu omits Awrit cycling" "[Aa]writ" "$WINDOWS"
assert_not_contains "window menu omits Awrit creation" "[Aa]writ" "$NEW_WINDOWS"
assert_contains "window menu duplicates the current typed window" "tmux-session-template duplicate" "$WINDOWS"
assert_contains "window menu renames windows" "rename-window" "$WINDOWS"
assert_contains "window close is confirmed" "Close window" "$WINDOWS"

PANES=$(tmux -L "$SOCKET_NAME" show-options -gv @wk_menu_panes 2>/dev/null || true)
assert_contains "pane menu preserves cwd when splitting" "pane_current_path" "$PANES"
assert_contains "pane menu includes navigation" "select-pane -L" "$PANES"
assert_contains "pane menu includes resizing" "@wk_menu_resize" "$PANES"
assert_contains "pane menu includes Yazi" "tmux-yazi-pane" "$PANES"
assert_contains "session menu exposes agent timers" "Agent timers and durable sessions" "$SESSIONS"
assert_contains "session timer action opens sesh-backed manager" "agent-timer manage" "$SESSIONS"
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
    "dependency data pins the tested command-center revision" \
    "85fb9756447b989f3b94e515d1e6ee7fec76cba2" \
    "$(cat "$DOTFILES_DIR/home/.chezmoidata.toml")"
assert_contains \
    "tmux config keeps stock-macOS-compatible command-center ownership" \
    "install.sh links the repo-owned" \
    "$(cat "$TMUX_CONFIG")"

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

exit "$FAILED"
