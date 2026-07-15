#!/usr/bin/env bash

# Test suite for configuration files

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(dirname "$TEST_DIR")"
RENDER_HOME="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-config-render.XXXXXX")"

cleanup() {
    rm -rf "$RENDER_HOME"
}
trap cleanup EXIT

chezmoi \
    -S "$DOTFILES_DIR" \
    -D "$RENDER_HOME" \
    --persistent-state "$RENDER_HOME/state.db" \
    apply --exclude=scripts,externals --force >/dev/null

SKHDRC="$RENDER_HOME/.skhdrc"
YABAIRC="$RENDER_HOME/.yabairc"
KARABINER_CONFIG="$DOTFILES_DIR/home/dot_config/private_karabiner/karabiner.json"
HOTKEYS="$DOTFILES_DIR/modules/app-focus/bin/hotkeys"
FOCUS_APP="$DOTFILES_DIR/modules/app-focus/bin/focus_app.sh"
APP_MRU="$DOTFILES_DIR/modules/app-focus/bin/app-mru.sh"
APP_FOCUS_DEFAULTS="$DOTFILES_DIR/modules/app-focus/config/defaults.toml"
TMUX_CONFIG="$RENDER_HOME/.tmux.conf"
TMUX_BORDER_ACCENT="$DOTFILES_DIR/modules/appearance-pip/bin/tmux-border-accent"
TMUX_WORKSPACE="$DOTFILES_DIR/modules/tmux-sessions/bin/tmux-workspace"
TMUX_WHICH_KEY="$RENDER_HOME/.config/tmux/which-key.yaml"
SESH_CONFIG="$DOTFILES_DIR/modules/tmux-sessions/config/sesh.toml"
GHOSTTY_CONFIG="$RENDER_HOME/Library/Application Support/com.mitchellh.ghostty/config"
TMUX_YAZI_HELPER="$DOTFILES_DIR/modules/tmux-yazi/bin/tmux-yazi-pane"
TMUX_TEMPLATE_HELPER="$DOTFILES_DIR/modules/terminal-window-types/bin/tmux-session-template"
SCRATCHPADS="$DOTFILES_DIR/modules/scratchpads/bin/scratchpads"
QUICK_TERMINAL="$DOTFILES_DIR/modules/scratchpads/bin/toggle_ghostty_quick_terminal.sh"
CREATE_SPACE="$DOTFILES_DIR/modules/space-display/bin/create-space"
DISPLAY_MOVE="$DOTFILES_DIR/modules/space-display/bin/display-move"
SHORTCUT_LAUNCHER="$DOTFILES_DIR/modules/shortcut-guide/bin/show_keys.sh"
NVIM_INIT="$DOTFILES_DIR/nvim/init.lua"
RENDER_MARKDOWN_CONFIG="$DOTFILES_DIR/nvim/lua/custom/plugins/render-markdown.lua"
LINT_CONFIG="$DOTFILES_DIR/nvim/lua/kickstart/plugins/lint.lua"
MARKDOWNLINT_CONFIG="$DOTFILES_DIR/nvim/.markdownlint.json"

PASSED=0
FAILED=0

# Test helper functions
assert_file_exists() {
    local file="$1"
    local test_name="$2"

    if [ -f "$file" ]; then
        echo "  ✓ $test_name"
        ((PASSED++))
        return 0
    else
        echo "  ✗ $test_name"
        echo "    File does not exist: $file"
        ((FAILED++))
        return 1
    fi
}

assert_contains() {
    local file="$1"
    local pattern="$2"
    local test_name="$3"

    if grep -q "$pattern" "$file"; then
        echo "  ✓ $test_name"
        ((PASSED++))
        return 0
    else
        echo "  ✗ $test_name"
        echo "    Pattern not found: $pattern"
        ((FAILED++))
        return 1
    fi
}

assert_not_contains() {
    local file="$1"
    local pattern="$2"
    local test_name="$3"

    if ! grep -q "$pattern" "$file"; then
        echo "  ✓ $test_name"
        ((PASSED++))
        return 0
    else
        echo "  ✗ $test_name"
        echo "    Pattern should not exist: $pattern"
        ((FAILED++))
        return 1
    fi
}

assert_count() {
    local file="$1"
    local pattern="$2"
    local expected="$3"
    local test_name="$4"

    local count=$(grep -c "$pattern" "$file" || true)
    if [ "$count" -eq "$expected" ]; then
        echo "  ✓ $test_name"
        ((PASSED++))
        return 0
    else
        echo "  ✗ $test_name"
        echo "    Expected $expected occurrences, found $count"
        ((FAILED++))
        return 1
    fi
}

echo "================================"
echo "Configuration Files Tests"
echo "================================"

echo ""
echo "Testing config files exist..."
assert_file_exists "$SKHDRC" "skhdrc exists"
assert_file_exists "$YABAIRC" "yabairc exists"
assert_file_exists "$KARABINER_CONFIG" "Karabiner config exists"

echo ""
echo "Testing Karabiner configuration..."
if jq -e '
    .profiles[] | select(.selected == true) as $profile
    | [
        $profile.complex_modifications.rules[].manipulators[]
        | select(.from.key_code == "caps_lock")
      ] as $caps
    | ($caps | length == 1)
      and ($caps[0].type == "basic")
      and ($caps[0].to[0].key_code == "left_control")
      and ($caps[0].to[0].lazy == true)
      and ($caps[0].to[0].modifiers == ["left_option", "left_command"])
      and ($caps[0].to_if_alone[0].key_code == "escape")
      and ($caps[0] | has("conditions") | not)
' "$KARABINER_CONFIG" >/dev/null; then
    echo "  ✓ Caps Lock is unconditionally Hyper on hold and Escape on tap"
    ((PASSED++))
else
    echo "  ✗ unconditional Caps Lock Hyper mapping is missing or invalid"
    ((FAILED++))
fi

assert_not_contains "$KARABINER_CONFIG" "nvim_caps_lock_control" "Karabiner has no Neovim-specific Caps Lock mode"
assert_not_contains "$NVIM_INIT" "nvim_caps_lock_control" "Neovim does not toggle a Caps Lock mode"
assert_not_contains "$NVIM_INIT" "karabiner_cli" "Neovim does not mutate Karabiner state"
assert_contains "$NVIM_INIT" "vim.keymap.set('n', 'd', '\"_d'" "Delete uses Lua keymap to avoid yanking"
assert_contains "$NVIM_INIT" "vim.keymap.set('n', '<leader>d', '\"d'" "Leader delete uses default register"
assert_not_contains "$NVIM_INIT" "^[[:space:]]*nnoremap " "Neovim Lua config does not contain raw nnoremap commands"
assert_not_contains "$NVIM_INIT" "^[[:space:]]*vnoremap " "Neovim Lua config does not contain raw vnoremap commands"
assert_contains "$NVIM_INIT" "marksman = {}" "Marksman LSP is configured for Markdown"
assert_contains "$NVIM_INIT" "'markdownlint'" "markdownlint is installed through Mason"
assert_contains "$NVIM_INIT" "markdown_inline" "Markdown inline treesitter parser is installed"
assert_contains "$NVIM_INIT" "yaml" "YAML treesitter parser is installed for Markdown frontmatter"
assert_contains "$RENDER_MARKDOWN_CONFIG" "MeanderingProgrammer/render-markdown.nvim" "render-markdown.nvim is installed"
assert_contains "$RENDER_MARKDOWN_CONFIG" "completions = { lsp = { enabled = true } }" "render-markdown LSP completions are enabled"
assert_contains "$RENDER_MARKDOWN_CONFIG" "file_types = { 'markdown' }" "render-markdown is scoped to Markdown"
assert_contains "$LINT_CONFIG" "vim.fn.executable 'markdownlint'" "Markdown linting waits for markdownlint executable"
assert_contains "$LINT_CONFIG" ".markdownlint.json" "markdownlint uses the checked-in rule config"
assert_contains "$MARKDOWNLINT_CONFIG" '"default": false' "markdownlint default rules are disabled"

echo ""
echo "Testing skhdrc configuration..."

# Test window management shortcuts
assert_contains "$SKHDRC" "ctrl + alt - h.*snap_window.sh left" "Snap left (h) works"
assert_contains "$SKHDRC" "ctrl + alt - k.*snap_window.sh right" "Snap right (k) works"
assert_contains "$SKHDRC" "ctrl + alt + shift - h.*swap west" "Swap left (h) works"
assert_contains "$SKHDRC" "ctrl + alt + shift - k.*swap east" "Swap right (k) works"

# Test window cycling shortcuts
assert_contains "$SKHDRC" "alt - tab.*focus" "Alt+tab cycles windows forward"
assert_contains "$SKHDRC" "shift + alt - tab.*focus" "Shift+alt+tab cycles windows backward"

# Test space management shortcuts
assert_contains "$SKHDRC" "ctrl + alt - f.*float-prefs toggle" "Float toggle remembers preferences"
assert_contains "$SKHDRC" "alt - k.*close_empty_spaces.sh" "Alt+k closes empty spaces"
assert_contains "$SKHDRC" "alt + shift - h.*window --resize left" "Option+Shift+H resizes the focused window left"
assert_contains "$SKHDRC" "alt + shift - j.*window --resize bottom" "Option+Shift+J resizes the focused window down"
assert_contains "$SKHDRC" "alt + shift - k.*window --resize right" "Option+Shift+K resizes the focused window right"
assert_contains "$SKHDRC" "alt + shift - u.*window --resize top" "Option+Shift+U resizes the focused window up"
assert_contains "$SKHDRC" "alt + shift - 0x21" "Option+Shift+Left-Bracket owns previous-display movement"
assert_contains "$SKHDRC" "alt + shift - 0x1E" "Option+Shift+Right-Bracket owns next-display movement"
assert_contains "$SKHDRC" "display-move prev" "Previous-display movement uses the stable helper"
assert_contains "$SKHDRC" "display-move next" "Next-display movement uses the stable helper"
assert_contains "$DISPLAY_MOVE" 'window --display "$direction"' "Display helper moves the focused window"
assert_contains "$DISPLAY_MOVE" 'display --focus "$direction"' "Display helper follows the moved window"
assert_not_contains "$SKHDRC" "\.config/yabai/projects " "Project-context commands are dormant"
assert_not_contains "$SKHDRC" "^ctrl + alt + cmd" "Hyper has no active global bindings"
assert_not_contains "$SKHDRC" "ctrl + alt + shift - 1.*window --space 1" "Mission Control index moves removed"
assert_contains "$SKHDRC" "alt - n.*create-space auto" "Alt+n creates a new space and conditionally moves a focused non-scratchpad window"
assert_contains "$SKHDRC" "ctrl + alt - n.*create-space move-window" "Ctrl+Alt+n moves the focused window to a new space"
assert_contains "$CREATE_SPACE" "before_uuids" "create-space snapshots spaces before creation"
assert_contains "$CREATE_SPACE" "space --focus.*new_index" "create-space focuses the newly created space"
assert_contains "$CREATE_SPACE" "scratchpad_label" "create-space ignores focused scratchpad windows in auto mode"
assert_contains "$CREATE_SPACE" "movable_windows.*-gt 1" "create-space auto mode keeps the only normal window on its current space"
assert_contains "$CREATE_SPACE" "capture_focused_window_for_move true" "create-space auto mode requires another normal window before moving"
assert_contains "$CREATE_SPACE" "capture_focused_window_for_move false" "create-space move-window mode can still force a focused window move"
assert_contains "$CREATE_SPACE" "move_focused_window=true" "create-space can mark a focused regular window for moving"
assert_not_contains "$CREATE_SPACE" "YABAI_SPACE_WALLPAPER" "create-space has no wallpaper assignment controls"
assert_not_contains "$CREATE_SPACE" "set picture of current desktop" "create-space does not apply wallpapers"
assert_contains "$SKHDRC" "alt - 1.*hotkeys app-focus 1.*@browser" "Alt+1 browser focus goes through hotkeys"
assert_contains "$SKHDRC" "alt - 2.*hotkeys app-focus 2.*@editor" "Alt+2 editor focus goes through hotkeys"
assert_contains "$SKHDRC" "alt - 3.*hotkeys app-focus 3.*Microsoft Teams" "Alt+3 Teams focus goes through zen gate"
assert_contains "$SKHDRC" "alt - 4.*hotkeys app-focus 4.*Slack" "Alt+4 Slack focus goes through zen gate"
assert_not_contains "$SKHDRC" "^alt - 5" "Alt+5 remains unbound"
assert_contains "$SKHDRC" "fn - 0x2B.*scratchpads open codex" "Fn+Comma opens the Codex dotfiles scratchpad"
assert_contains "$SKHDRC" "fn - 1.*scratchpads open projects" "Fn+1 opens the projects tmux scratchpad"
assert_not_contains "$SKHDRC" "alt - 0x2B.*scratchpads open codex" "Alt+Comma no longer opens the Codex dotfiles scratchpad"
assert_not_contains "$SKHDRC" "alt - l.*scratchpads open projects" "Alt+L no longer opens the projects tmux scratchpad"
assert_contains "$SKHDRC" "alt + shift - 0x2A.*hotkeys zen toggle" "Alt+Shift+Backslash toggles zen mode"
assert_contains "$SKHDRC" "alt + shift - 0x32.*hotkeys terminal new" "Alt+Shift+Backtick creates a terminal"
assert_contains "$SKHDRC" "alt - 0x2C :.*show_keys.sh" "Alt+Slash toggles the shortcut guide directly"
assert_contains "$SKHDRC" 'rcmd - d \[' "Right Command+D enters the Ghostty management layer"
assert_contains "$SKHDRC" '"Ghostty" : skhd -k "f16"' "Right Command+D emits synthetic F16 in Ghostty"
assert_contains "$SKHDRC" 'rcmd - r \[' "Right Command+R enters the Ghostty management layer"
assert_contains "$SKHDRC" '"Ghostty" : skhd -k "f17"' "Right Command+R emits synthetic F17 in Ghostty"
assert_contains "$SKHDRC" 'rcmd - s \[' "Right Command+S enters the Ghostty management layer"
assert_contains "$SKHDRC" '"Ghostty" : skhd -k "f18"' "Right Command+S emits synthetic F18 in Ghostty"
assert_contains "$SKHDRC" 'rcmd - space \[' "Right Command+Space enters the Ghostty management layer"
assert_contains "$SKHDRC" '"Ghostty" : skhd -k "f19"' "Right Command+Space emits synthetic F19 in Ghostty"
assert_count "$SKHDRC" '^rcmd -' 4 "Right Command owns only the four Ghostty management actions"
assert_count "$SKHDRC" '^[[:space:]]*\* ~$' 4 "Every right-Command management chord passes through outside Ghostty"
assert_not_contains "$SKHDRC" '^lcmd -' "Left Command remains application-local"
assert_contains "$SHORTCUT_LAUNCHER" 'app="$HOME/.config/skhd/whichkey"' "Shortcut guide launcher keeps the stable live path"
assert_contains "$SHORTCUT_LAUNCHER" 'source_file=.*WhichKey.swift' "Shortcut guide launcher lazily rebuilds stale source"
assert_contains "$SHORTCUT_LAUNCHER" 'action="${1:-toggle}"' "Shortcut guide launcher separates open, close, and toggle actions"
assert_contains "$SHORTCUT_LAUNCHER" 'whichkey-launch.lock' "Shortcut guide launcher prevents duplicate app races"
assert_count "$SKHDRC" "^fn -" 2 "Fn is reserved for the two scratchpads"
assert_not_contains "$SKHDRC" '^fn - [234]' "Fn no longer duplicates native screenshot shortcuts"

assert_contains "$HOTKEYS" "ZEN_MODE_FILE=.*zen_mode" "hotkeys stores zen mode state"
assert_contains "$APP_FOCUS_DEFAULTS" "zen_blocked_slots = \[3, 4, 5\]" "app-focus defaults disable slots 3-5 in zen mode"
assert_contains "$HOTKEYS" "before_json=.*query --windows" "terminal opener snapshots existing app windows before launch"
assert_contains "$HOTKEYS" "stale_lock_after_s=10" "terminal opener clears stale launch locks"
assert_contains "$HOTKEYS" "display --focus.*current_display" "terminal opener restores the originating display before focus"
assert_contains "$HOTKEYS" "window.*--space.*current_space" "terminal opener moves new windows to the originating space"
assert_contains "$FOCUS_APP" 'hotkeys terminal new' "Ghostty app focus creates a normal terminal when no eligible window exists"
assert_contains "$QUICK_TERMINAL" "background-opacity=1" "quick terminal scratchpad keeps Ghostty opaque"
assert_file_exists "$TMUX_TEMPLATE_HELPER" "terminal-window-types module owns the tmux session template helper"
assert_file_exists "$TMUX_WORKSPACE" "declarative tmux workspace helper exists"
assert_file_exists "$TMUX_WHICH_KEY" "repo-owned tmux command-center config exists"
assert_file_exists "$SESH_CONFIG" "repo-owned sesh config exists"
assert_file_exists "$DOTFILES_DIR/modules/tmux-sessions/layouts/project.tmux.tsx" "React-like project layout exists"
assert_contains "$TMUX_CONFIG" "after-new-session\[50\].*tmux-session-template auto.*session_name" "ordinary new tmux sessions use the standard template"
assert_contains "$TMUX_CONFIG" '^set-option -g detach-on-destroy off$' "tmux stays attached when a selected session disappears"
assert_contains "$GHOSTTY_CONFIG" "keybind = cmd+backquote=csi:48;5u" "Cmd+Backtick cycles terminal windows through Ctrl+0"
assert_contains "$GHOSTTY_CONFIG" "keybind = cmd+digit_1=csi:49;5u" "Cmd+1 cycles Codex windows through Ctrl+1"
assert_contains "$GHOSTTY_CONFIG" "keybind = cmd+1=csi:49;5u" "Cmd+1 has a Ghostty key-name fallback"
assert_contains "$GHOSTTY_CONFIG" "keybind = cmd+digit_2=csi:50;5u" "Cmd+2 cycles Neovim windows through Ctrl+2"
assert_contains "$GHOSTTY_CONFIG" "keybind = cmd+2=csi:50;5u" "Cmd+2 has a Ghostty key-name fallback"
assert_contains "$GHOSTTY_CONFIG" "keybind = cmd+digit_3=csi:51;5u" "Cmd+3 cycles Tuxedo windows through Ctrl+3"
assert_contains "$GHOSTTY_CONFIG" "keybind = cmd+3=csi:51;5u" "Cmd+3 has a Ghostty key-name fallback"
assert_contains "$GHOSTTY_CONFIG" "keybind = cmd+b=text:\\\\x01\\\\x62" "Cmd+B toggles the Yazi side pane"
assert_contains "$GHOSTTY_CONFIG" "keybind = cmd+shift+b=text:\\\\x01\\\\x42" "Cmd+Shift+B opens the Yazi window"
assert_not_contains "$GHOSTTY_CONFIG" "^keybind = ctrl+alt+cmd" "Hyper has no active Ghostty bindings"
assert_not_contains "$GHOSTTY_CONFIG" "cmd+backquote=text:\\\\x01" "Cmd+Backtick does not select a fixed tmux index"
if command -v ghostty >/dev/null 2>&1; then
    if ghostty +validate-config --config-file="$GHOSTTY_CONFIG" >/dev/null 2>&1; then
        echo "  ✓ Ghostty accepts the managed config"
        ((PASSED++))
    else
        echo "  ✗ Ghostty rejects the managed config"
        ((FAILED++))
    fi
fi
assert_contains "$TMUX_CONFIG" 'bind-key -N "Open sesh session picker" s display-popup.*tmux-sessionizer-zoxide' "tmux opens the built-in sesh picker in a popup"
assert_contains "$TMUX_CONFIG" 'bind-key -N "Switch to client-local last session" L switch-client -l' "tmux keeps last-session history local to each client"
assert_contains "$TMUX_WHICH_KEY" 'display-popup.*tmux-sessionizer-zoxide' "tmux command center opens the built-in sesh picker"
assert_contains "$TMUX_WHICH_KEY" 'command: switch-client -l' "tmux command center keeps last-session history local to each client"
assert_contains "$DOTFILES_DIR/modules/tmux-sessions/bin/tmux-session-picker" 'exec sesh picker --icons --hide-duplicates --separator-aware --tmux' "session-only helper uses the built-in sesh picker"
assert_contains "$DOTFILES_DIR/modules/tmux-sessions/bin/tmux-sessionizer" 'exec sesh picker --icons --hide-duplicates --separator-aware' "sessionizer uses the built-in sesh picker"
assert_contains "$DOTFILES_DIR/modules/tmux-sessions/bin/tmux-sessionizer-zoxide" 'exec sesh picker --icons --hide-duplicates --separator-aware' "zoxide sessionizer uses the built-in sesh picker"
assert_not_contains "$DOTFILES_DIR/modules/tmux-sessions/bin/tmux-session-picker" 'fzf --' "session-only helper does not rebuild sesh's picker with fzf"
assert_not_contains "$DOTFILES_DIR/modules/tmux-sessions/bin/tmux-sessionizer" 'fzf --' "sessionizer does not rebuild sesh's picker with fzf"
assert_not_contains "$DOTFILES_DIR/modules/tmux-sessions/bin/tmux-sessionizer-zoxide" 'fzf --' "zoxide sessionizer does not rebuild sesh's picker with fzf"
assert_contains "$SESH_CONFIG" '^\[tui\]$' "sesh config owns built-in picker presentation"
assert_contains "$SESH_CONFIG" '^show_icons = true$' "sesh picker shows source icons"
assert_contains "$SESH_CONFIG" '^strict_mode = true$' "sesh rejects unknown configuration fields"
assert_not_contains "$SESH_CONFIG" '^\[default_session\]$' "sesh config does not inject default layouts"
assert_not_contains "$SESH_CONFIG" '^\[\[window\]\]$' "sesh config does not define mutable window templates"
assert_not_contains "$SESH_CONFIG" '^\[\[session\]\]$' "sesh config does not define sessions that can mutate the caller"
if command -v sesh >/dev/null 2>&1; then
    if sesh -C "$SESH_CONFIG" list -c >/dev/null 2>&1; then
        echo "  ✓ sesh accepts the managed picker config"
        ((PASSED++))
    else
        echo "  ✗ sesh rejects the managed picker config"
        ((FAILED++))
    fi
fi
assert_contains "$TMUX_CONFIG" 'bind-key -N "New named session" N command-prompt.*new-session -A -s' "tmux exposes direct named-session creation"
assert_contains "$TMUX_CONFIG" "bind-key -N \"Rename session contextually\" '[$]' command-prompt.*rename-session" "tmux exposes direct session renaming"
assert_contains "$TMUX_CONFIG" 'Rename #S · #{b:pane_current_path}' "tmux rename prompt shows the active folder context"
assert_contains "$TMUX_CONFIG" '#{?#{m/r:' "tmux rename prompt conditionally replaces generated names"
assert_contains "$TMUX_CONFIG" 'command-prompt -F -l' "tmux rename prompt supports punctuation as literal input"
assert_contains "$TMUX_CONFIG" 'rename-session -t "#{session_id}" -- "%%%"' "tmux safely passes the full prompted session name"
assert_contains "$TMUX_WHICH_KEY" 'name: Rename contextually' "tmux command center advertises contextual session renaming"
assert_contains "$TMUX_CONFIG" 'bind-key -N "Close session" X confirm-before.*kill-session' "tmux confirms direct session closure"
assert_contains "$TMUX_CONFIG" 'bind-key -N "New terminal window" c run-shell.*tmux-session-template new' "tmux exposes direct terminal-window creation"
assert_contains "$TMUX_CONFIG" 'bind-key -N "Previous window" p previous-window' "tmux exposes direct previous-window selection"
assert_contains "$TMUX_CONFIG" 'bind-key -N "Next window" n next-window' "tmux exposes direct next-window selection"
assert_contains "$TMUX_CONFIG" 'bind-key -N "Close window".*&.*confirm-before.*kill-window' "tmux confirms direct window closure"
assert_contains "$TMUX_CONFIG" 'bind-key -N "Toggle pane zoom" z resize-pane -Z' "tmux exposes direct pane zoom"
assert_contains "$TMUX_CONFIG" 'bind-key -N "Toggle Yazi side pane" b run-shell.*tmux-yazi-pane toggle.*pane_id' "tmux toggles Yazi through the idempotent side-pane helper"
assert_contains "$TMUX_CONFIG" 'bind-key -N "Open Yazi full window" B new-window -S -n yazi -c.*pane_current_path.*yazi' "tmux opens or selects a dedicated Yazi window"
assert_file_exists "$TMUX_YAZI_HELPER" "tmux Yazi module owns the pane helper"
assert_contains "$TMUX_YAZI_HELPER" '@dotfiles_yazi_side' "tmux Yazi pane helper marks its managed pane"
assert_contains "$TMUX_YAZI_HELPER" 'dotfiles_tmux_wait_lock_acquire' "tmux Yazi pane helper serializes rapid toggles through the standard library"
assert_contains "$TMUX_YAZI_HELPER" 'yazi "$directory"' "tmux Yazi pane helper passes the current folder explicitly"
assert_contains "$TMUX_CONFIG" '@catppuccin_status_background "none"' "tmux status bar blends into the terminal background"
assert_contains "$TMUX_CONFIG" '@catppuccin_window_status_style "none"' "tmux disables Catppuccin window pills"
assert_not_contains "$TMUX_CONFIG" '.config/tmux/plugins/catppuccin' "tmux does not source the stale Catppuccin path"
assert_contains "$TMUX_CONFIG" '@dotfiles_status_accent.*session_name},dotfiles.*@thm_mauve' "tmux gives the dotfiles bar a stable mauve accent"
assert_contains "$TMUX_CONFIG" '@dotfiles_status_accent.*session_name},projects.*@thm_sapphire' "tmux gives the projects bar a stable sapphire accent"
assert_contains "$TMUX_CONFIG" '@dotfiles_status_accent.*session_id.*@thm_green.*@thm_sky' "tmux rotates other session accents through the Catppuccin palette"
assert_contains "$TMUX_CONFIG" 'client-focus-in\[60\].*tmux-border-accent update' "tmux updates the focused border when a client gains focus"
assert_contains "$TMUX_CONFIG" 'client-focus-out\[60\].*tmux-border-accent update' "tmux resets the focused border when a client loses focus"
assert_contains "$TMUX_CONFIG" 'client-detached\[60\].*tmux-border-accent update' "tmux resets the focused border when a client detaches"
assert_contains "$TMUX_CONFIG" 'client-session-changed\[60\].*tmux-border-accent update' "tmux updates the border when a client changes sessions"
assert_contains "$TMUX_CONFIG" "status-position bottom" "tmux keeps the status bar at the bottom"
assert_contains "$TMUX_CONFIG" "status-justify absolute-centre" "tmux centers window labels across the terminal"
assert_contains "$TMUX_CONFIG" "status-style default" "tmux uses the terminal background for the status bar"
assert_contains "$TMUX_CONFIG" "status-left.*pane_current_path" "tmux shows the active folder name at left"
assert_contains "$TMUX_CONFIG" "status-left.*#S" "tmux keeps the current session name visible"
assert_contains "$TMUX_CONFIG" 'status-left.*==:#S,#{b:pane_current_path}' "tmux suppresses a folder label that merely repeats the session name"
assert_contains "$TMUX_CONFIG" 'status-left.*m/r:\^\[0-9\].*pane_current_path.*#S' "tmux replaces generated numeric session labels with the active folder"
assert_contains "$TMUX_CONFIG" 'status-left.*E:@dotfiles_status_accent.*▌' "tmux draws the session accent as a strong left rail"
assert_contains "$TMUX_CONFIG" "status-right ''" "tmux omits status telemetry modules"
assert_contains "$TMUX_CONFIG" "window-status-activity-style default" "tmux keeps activity alerts pill-free"
assert_contains "$TMUX_CONFIG" "window-status-bell-style default" "tmux keeps bell alerts pill-free"
assert_contains "$TMUX_CONFIG" "window-status-format.*terminal.*~.*#W" "tmux renders stable app labels and shortens terminal to tilde"
assert_contains "$TMUX_CONFIG" "window-status-current-format.*terminal.*~.*#W" "tmux highlights the current stable app label"
assert_contains "$TMUX_CONFIG" 'window-status-separator.*@thm_surface_1.*·' "tmux separates window labels with a quiet centered dot"
assert_contains "$TMUX_CONFIG" 'window-status-current-format.*fg=#{E:@dotfiles_status_accent},bold.*#W.*default' "tmux colors the active app label without a background block"
assert_not_contains "$TMUX_CONFIG" 'window-status-current-format.*bg=#{E:@dotfiles_status_accent}' "tmux avoids a full-height active-window capsule"
assert_not_contains "$TMUX_CONFIG" 'window-status-format.*•' "tmux does not prefix every inactive label with a floating bullet"
assert_contains "$TMUX_CONFIG" "bind-key , command-prompt.*dotfiles_window_type.*codex.*#T,#W.*rename-window" "tmux seeds typed Codex renames from the Codex pane title"
assert_file_exists "$TMUX_BORDER_ACCENT" "tmux border accent helper exists"
assert_contains "$TMUX_BORDER_ACCENT" 'list-clients' "tmux border accent reads focused client state"
assert_contains "$TMUX_BORDER_ACCENT" 'E:@dotfiles_status_accent' "tmux border accent reuses the status bar color"
assert_contains "$TMUX_BORDER_ACCENT" 'active_color=' "tmux border accent updates JankyBorders at runtime"
assert_contains "$TMUX_BORDER_ACCENT" 'apply-to=' "tmux border accent can suppress one exact scratchpad window"
assert_contains "$TMUX_BORDER_ACCENT" 'scratchpad_window_ids' "tmux border accent discovers yabai scratchpad windows"
assert_contains "$TMUX_BORDER_ACCENT" 'active_color=\$TRANSPARENT_COLOR' "tmux border accent makes scratchpad borders transparent"
assert_contains "$TMUX_BORDER_ACCENT" 'SUPPRESS_ATTEMPTS' "tmux border accent retries scratchpad overrides during JankyBorders startup"
assert_contains "$TMUX_CONFIG" "C-0.*tmux-session-template cycle.*terminal" "Ctrl+0 cycles terminal windows by type"
assert_contains "$TMUX_CONFIG" "C-1.*tmux-session-template cycle.*codex" "Ctrl+1 cycles Codex windows by type"
assert_contains "$TMUX_CONFIG" "C-2.*tmux-session-template cycle.*nvim" "Ctrl+2 cycles Neovim windows by type"
assert_contains "$TMUX_CONFIG" "C-3.*tmux-session-template cycle.*tuxedo" "Ctrl+3 cycles Tuxedo windows by type"
assert_contains "$TMUX_CONFIG" "C-S-0.*tmux-session-template new.*terminal" "Ctrl+Shift+0 creates a terminal window"
assert_contains "$TMUX_CONFIG" "C-S-1.*tmux-session-template new.*codex" "Ctrl+Shift+1 creates a Codex window"
assert_contains "$TMUX_CONFIG" "C-S-2.*tmux-session-template new.*nvim" "Ctrl+Shift+2 creates a Neovim window"
assert_contains "$TMUX_CONFIG" "C-S-3.*tmux-session-template new.*tuxedo" "Ctrl+Shift+3 creates a Tuxedo window"
assert_contains "$TMUX_CONFIG" 'S-F4.*tmux-session-template duplicate.*session_id.*pane_id' "terminal F16 duplicates the current tmux window for Right Command"
assert_contains "$TMUX_CONFIG" 'S-F5.*command-prompt.*Rename window' "terminal F17 renames the current tmux window for Right Command"
assert_contains "$TMUX_CONFIG" 'S-F6.*tmux-sessionizer-zoxide' "terminal F18 opens the sesh picker for Right Command"
assert_contains "$TMUX_CONFIG" 'S-F7.*show-wk-menu-root' "terminal F19 opens the tmux command center for Right Command"
assert_contains "$TMUX_CONFIG" "bind-key '|'.*split-window -h.*pane_current_path" "tmux directly splits a cwd-preserving pane to the right"
assert_contains "$TMUX_CONFIG" "bind-key '-'.*split-window -v.*pane_current_path" "tmux directly splits a cwd-preserving pane below"
assert_contains "$TMUX_CONFIG" "tmux-plugins/tmux-resurrect" "tmux declares session persistence"
assert_contains "$TMUX_CONFIG" "@continuum-restore" "tmux restores persisted sessions on cold start"
assert_contains "$TMUX_CONFIG" "@resurrect-processes 'codex tuxedo yazi'" "tmux restores the Tuxedo process"
assert_contains "$TMUX_WHICH_KEY" "tmux-workspace pick" "tmux command center opens declarative layouts"
assert_contains "$TMUX_WHICH_KEY" "kill-session" "tmux command center can close sessions"
assert_contains "$TMUX_WHICH_KEY" "tmux-session-template new" "tmux command center creates typed windows"
assert_contains "$TMUX_WHICH_KEY" "cycle.*tuxedo" "tmux command center cycles Tuxedo windows"
assert_contains "$TMUX_WHICH_KEY" "new.*tuxedo" "tmux command center creates Tuxedo windows"
assert_not_contains "$TMUX_WHICH_KEY" "[Aa]writ" "tmux command center omits Awrit actions"
assert_contains "$TMUX_WHICH_KEY" "tmux-session-template duplicate" "tmux command center duplicates the current window"
assert_not_contains "$TMUX_CONFIG" "C-[0123] select-window" "Ctrl+0/1/2/3 no longer target fixed indices"
assert_contains "$TMUX_CONFIG" "C-4 select-window -t :4" "Ctrl+4 keeps direct index switching"
assert_contains "$GHOSTTY_CONFIG" "ctrl+shift+digit_0=csi:48;6u" "Ghostty emits distinct Ctrl+Shift+0 input for tmux"
assert_contains "$GHOSTTY_CONFIG" "ctrl+shift+digit_1=csi:49;6u" "Ghostty emits distinct Ctrl+Shift+1 input for tmux"
assert_contains "$GHOSTTY_CONFIG" "ctrl+shift+digit_2=csi:50;6u" "Ghostty emits distinct Ctrl+Shift+2 input for tmux"
assert_contains "$GHOSTTY_CONFIG" "ctrl+shift+digit_3=csi:51;6u" "Ghostty emits distinct Ctrl+Shift+3 input for tmux"
assert_contains "$TMUX_TEMPLATE_HELPER" "pane_start_command" "tmux template leaves command sessions alone"
assert_contains "$TMUX_TEMPLATE_HELPER" "DOTFILES_TMUX_TEMPLATE" "tmux template supports explicit opt-out"
assert_contains "$TMUX_TEMPLATE_HELPER" 'session.*!= hs-\*' "tmux template leaves hs sessions alone"
assert_contains "$TMUX_TEMPLATE_HELPER" "dotfiles_tmux_wait_lock_acquire" "tmux template serializes concurrent layout creation through the standard library"
assert_contains "$TMUX_TEMPLATE_HELPER" "WINDOW_TYPE_OPTION=.*dotfiles_window_type" "tmux windows carry stable type metadata"
assert_contains "$TMUX_TEMPLATE_HELPER" "new-window -d -P" "tmux captures duplicate window IDs before launching commands"
assert_contains "$TMUX_TEMPLATE_HELPER" "allows_legacy_index_migration" "tmux protects the new Tuxedo slot during template upgrades"
assert_contains "$SCRATCHPADS" "open:codex" "scratchpads supports Codex dotfiles scratchpad"
assert_contains "$SCRATCHPADS" "open:projects" "scratchpads supports projects tmux scratchpad"
assert_contains "$SCRATCHPADS" "SCRATCHPAD_TERMINAL_LABEL" "scratchpads uses one terminal scratchpad window"
assert_contains "$SCRATCHPADS" "SCRATCHPAD_DOTFILES_TMUX_SESSION" "scratchpads declares the dotfiles tmux session"
assert_contains "$SCRATCHPADS" "SCRATCHPAD_PROJECTS_TMUX_SESSION" "scratchpads declares the projects tmux session"
assert_not_contains "$SCRATCHPADS" "SCRATCHPAD_TMUX_SESSION=" "scratchpads does not use one shared tmux session"
assert_contains "$SCRATCHPADS" "scratchpad_codex_dotfiles" "scratchpads removes the stale Codex scratchpad rule"
assert_contains "$SCRATCHPADS" "scratchpad_projects_tmux" "scratchpads removes the stale projects scratchpad rule"
assert_contains "$SCRATCHPADS" "open_terminal_tmux_scratchpad.*dotfiles" "Codex hotkey opens the terminal scratchpad on dotfiles"
assert_contains "$SCRATCHPADS" "open_terminal_tmux_scratchpad.*projects" "Projects hotkey opens the terminal scratchpad on projects"
assert_contains "$SCRATCHPADS" "switch_terminal_scratchpad_client" "scratchpads switches the existing tmux client"
assert_contains "$SCRATCHPADS" "SCRATCHPAD_TMUX_CLIENT_OPTION" "scratchpads records the terminal tmux client"
assert_contains "$SCRATCHPADS" "infer_terminal_scratchpad_client" "scratchpads recovers a stale terminal tmux client"
assert_contains "$SCRATCHPADS" "client_session" "scratchpads infers the terminal client from scratchpad sessions"
assert_contains "$SCRATCHPADS" "attach_dotfiles_tmux_session" "Codex scratchpad attaches to the dotfiles tmux session"
assert_contains "$SCRATCHPADS" "attach_projects_tmux_session.*nvim" "Projects scratchpad can attach to the nvim tmux window"
assert_contains "$SCRATCHPADS" "close_scratchpads_except_label" "scratchpads closes other scratchpad windows before opening"
assert_contains "$SCRATCHPADS" "close_duplicate_scratchpads_for_label" "scratchpads closes duplicate scratchpad windows"
assert_contains "$SCRATCHPADS" "close_duplicate_scratchpad_title_windows" "scratchpads removes same-title unlabeled launch-race windows"
assert_contains "$SCRATCHPADS" "acquire_scratchpad_open_lock" "scratchpads serialize concurrent hotkey launches"
assert_contains "$SCRATCHPADS" 'visible_ids=$(scratchpad_visible_ids' "visible same-target scratchpads toggle closed even after focus moves"
assert_contains "$SCRATCHPADS" "SCRATCHPAD_PROJECTS_DIR" "scratchpads roots the projects tmux session in ~/projects"
assert_contains "$SCRATCHPADS" "background=#000000" "scratchpads use a black Ghostty background"
assert_contains "$SCRATCHPADS" "background-opacity=1" "scratchpads keep Ghostty opaque"
assert_contains "$SCRATCHPADS" "background-blur=false" "scratchpads disable Ghostty blur"
assert_contains "$SCRATCHPADS" "window-padding-x=12" "scratchpads add horizontal breathing room"
assert_contains "$SCRATCHPADS" "window-padding-y=10" "scratchpads add vertical breathing room"
assert_contains "$SCRATCHPADS" "window-padding-balance=true" "scratchpads keep terminal padding balanced"
assert_contains "$SCRATCHPADS" "resize-overlay=never" "scratchpads hide resize telemetry"
assert_contains "$SCRATCHPADS" "window-save-state=never" "scratchpads leave geometry ownership to yabai"
assert_contains "$SCRATCHPADS" "quit-after-last-window-closed=true" "scratchpad Ghostty processes quit with their window"
assert_contains "$SCRATCHPADS" 'env -u ZDOTDIR -u TMUX -u TMUX_PANE' "scratchpads do not inherit a stale tmux client environment"
assert_contains "$SCRATCHPADS" "suppress-scratchpads" "scratchpads remove only their exact JankyBorders window"
assert_contains "$SCRATCHPADS" 'has-shadow' "scratchpads inspect their native shadow state"
assert_contains "$SCRATCHPADS" 'toggle shadow' "scratchpads enable a native shadow for visual separation"
assert_contains "$SCRATCHPADS" "new-session -d -e DOTFILES_TMUX_TEMPLATE=skip.*-n terminal" "scratchpads opt out of the automatic hook while creating their raw terminal"
assert_contains "$SCRATCHPADS" "ensure_standard_scratchpad_tmux_windows" "scratchpads keeps standard windows in each tmux session"
assert_contains "$SCRATCHPADS" "tmux-session-template.*ensure" "scratchpads reuse the default tmux template"
assert_contains "$TMUX_TEMPLATE_HELPER" "ensure_standard_tmux_window.*terminal 0" "tmux template keeps terminal at window 0"
assert_contains "$TMUX_TEMPLATE_HELPER" "ensure_standard_tmux_window.*codex 1 codex" "tmux template starts Codex at window 1"
assert_contains "$TMUX_TEMPLATE_HELPER" "ensure_standard_tmux_window.*nvim 2 nvim" "tmux template starts Neovim at window 2"
assert_contains "$TMUX_TEMPLATE_HELPER" "ensure_standard_tmux_window.*tuxedo 3 todo" "tmux template starts Tuxedo through the canonical todo wrapper at window 3"
assert_not_contains "$TMUX_TEMPLATE_HELPER" "[Aa]writ" "tmux template omits the Awrit window type"
assert_contains "$SCRATCHPADS" "hide_scratchpad_and_restore_focus" "scratchpads toggles Codex visibility without closing"
assert_contains "$SCRATCHPADS" "restore_origin_focus" "scratchpads restore the originating display and space"

echo ""
echo "Testing app MRU behavior..."
APP_MRU_TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/app-mru-test.XXXXXX")"
APP_MRU_FAKE_BIN="$APP_MRU_TEST_DIR/bin"
mkdir -p "$APP_MRU_FAKE_BIN" "$APP_MRU_TEST_DIR/state"
cat > "$APP_MRU_FAKE_BIN/yabai" <<'FAKE_YABAI'
#!/usr/bin/env bash
if [ "$1" = "-m" ] && [ "$2" = "query" ] && [ "$3" = "--windows" ]; then
  cat <<'JSON'
[
  {"id":100,"app":"Ghostty","is-minimized":false,"is-hidden":false,"scratchpad":"","title":"normal-a"},
  {"id":200,"app":"Ghostty","is-minimized":false,"is-hidden":false,"scratchpad":"terminal","title":"scratchpad:terminal"},
  {"id":300,"app":"Ghostty","is-minimized":false,"is-hidden":false,"scratchpad":null,"title":"normal-b"}
]
JSON
  exit 0
fi
exit 1
FAKE_YABAI
chmod +x "$APP_MRU_FAKE_BIN/yabai"
printf '200\n100\n999\n' > "$APP_MRU_TEST_DIR/state/Ghostty.ids"
APP_MRU_OUTPUT=$(
    APP_MRU_DIR="$APP_MRU_TEST_DIR/state" \
    PATH="$APP_MRU_FAKE_BIN:$PATH" \
    APP_FOCUS_CONFIG_FILE="$APP_FOCUS_DEFAULTS" \
    bash -c 'source "$1"; app_mru_list Ghostty' _ "$APP_MRU"
)
rm -rf "$APP_MRU_TEST_DIR"
if [ "$APP_MRU_OUTPUT" = $'100\n300' ]; then
    echo "  ✓ App MRU prunes scratchpad windows from saved stacks"
    ((PASSED++))
else
    echo "  ✗ App MRU prunes scratchpad windows from saved stacks"
    echo "    Expected: 100, 300"
    echo "    Actual: $APP_MRU_OUTPUT"
    ((FAILED++))
fi

# Test reload shortcut
assert_contains "$SKHDRC" "alt - r.*restart-service" "Reload shortcut exists"

# Border shortcuts should be removed
assert_not_contains "$SKHDRC" "mark_window.sh" "No border keybindings remain"

echo ""
echo "Testing yabairc configuration..."

# Test yabai loads scripting addition
assert_contains "$YABAIRC" "yabai --load-sa" "Loads scripting addition"

# Test layout is BSP
assert_contains "$YABAIRC" "layout.*bsp" "Uses BSP layout"

# Removed in yabai 7.1.17
assert_not_contains "$YABAIRC" "window_topmost" "Removed window_topmost option is not configured"

# Test padding is configured
assert_contains "$YABAIRC" "top_padding" "Top padding configured"
assert_contains "$YABAIRC" "bottom_padding" "Bottom padding configured"
assert_contains "$YABAIRC" "left_padding" "Left padding configured"
assert_contains "$YABAIRC" "right_padding" "Right padding configured"
assert_contains "$YABAIRC" "BORDER_WIDTH=4.0" "JankyBorders uses an obvious four-point border"
assert_contains "$YABAIRC" "BORDER_RESERVE=2" "yabai reserves half the border width around tiles"
assert_contains "$YABAIRC" "BORDER_COLOR=0xff000000" "inactive JankyBorders lines stay black"
assert_contains "$YABAIRC" 'tmux-border-accent.*start.*BORDER_WIDTH.*BORDER_COLOR' "yabairc starts the session-aware border helper"
assert_not_contains "$YABAIRC" "background_color" "JankyBorders background fill is unset"
assert_not_contains "$YABAIRC" "0xff1e1e2e" "JankyBorders does not use Catppuccin base"

# Border signals should be removed
assert_not_contains "$YABAIRC" "update_border.sh" "No border signals remain"
assert_not_contains "$YABAIRC" "auto_mark.sh" "No auto mark signal remains"
assert_not_contains "$YABAIRC" "cleanup_marks.sh" "No cleanup mark signal remains"

# Floating window preferences are replayed on startup.
assert_contains "$YABAIRC" 'float-prefs" apply-rules' "yabairc restores floating window preferences"
assert_contains "$YABAIRC" 'signal --remove "projects_record_focus"' "yabairc removes the dormant project focus signal"
assert_not_contains "$YABAIRC" 'signal --add label=projects_record_focus' "yabairc does not track dormant project contexts"
assert_contains "$YABAIRC" 'app-mru.sh update' "yabairc tracks app MRU stacks on focus"
assert_contains "$YABAIRC" 'tile_pip_on_create.*window_created.*tile-pip-window' "yabairc tiles PiP windows when created"
assert_contains "$YABAIRC" 'tile_pip_on_title_change.*window_title_changed.*tile-pip-window' "yabairc tiles windows that become PiP"
assert_contains "$YABAIRC" 'tile_pip_windows.*manage=on.*sticky=off.*sub-layer=auto' "yabairc manages PiP windows"
assert_not_contains "$YABAIRC" 'float-prefs apply-window' "yabairc does not use float signal handlers"

# Test common window rules exist
assert_contains "$YABAIRC" "System Settings.*manage=off" "System Settings rule exists"
assert_contains "$YABAIRC" "Calculator.*manage=off" "Calculator rule exists"

echo ""
echo "Testing configuration consistency..."

# Ensure no border references remain
assert_not_contains "$SKHDRC" "fn - [0-9].*mark_window.sh" "No fn border mappings remain"
assert_not_contains "$YABAIRC" "config/borders" "No borders path in yabairc"

echo ""
echo "Testing no syntax errors..."

# Test skhdrc can be parsed (basic check)
if bash -n "$SKHDRC" 2>/dev/null; then
    echo "  ✓ skhdrc has no bash syntax errors"
    ((PASSED++))
else
    echo "  ✗ skhdrc has bash syntax errors"
    ((FAILED++))
fi

# Test yabairc can be parsed
if bash -n "$YABAIRC" 2>/dev/null; then
    echo "  ✓ yabairc has no bash syntax errors"
    ((PASSED++))
else
    echo "  ✗ yabairc has bash syntax errors"
    ((FAILED++))
fi

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

exit $FAILED
