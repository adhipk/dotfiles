#!/usr/bin/env bash

# Test suite for configuration files

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(dirname "$TEST_DIR")"
SKHDRC="$DOTFILES_DIR/home/dot_skhdrc"
YABAIRC="$DOTFILES_DIR/home/dot_yabairc"
KARABINER_CONFIG="$DOTFILES_DIR/home/dot_config/private_karabiner/karabiner.json"
HOTKEYS="$DOTFILES_DIR/home/bin/executable_hotkeys"
TMUX_CONFIG="$DOTFILES_DIR/home/dot_tmux.conf"
TMUX_BORDER_ACCENT="$DOTFILES_DIR/home/bin/executable_tmux-border-accent"
TMUX_WORKSPACE="$DOTFILES_DIR/home/bin/executable_tmux-workspace"
TMUX_WHICH_KEY="$DOTFILES_DIR/home/dot_config/tmux/which-key.yaml"
GHOSTTY_CONFIG="$DOTFILES_DIR/home/Library/Application Support/com.mitchellh.ghostty/config"
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
    | (
        [
          $profile.complex_modifications.rules[].manipulators[]
          | select(
              .type == "basic"
              and .from.key_code == "caps_lock"
              and .to[0].key_code == "left_control"
              and .to[0].lazy == true
              and (.to[0] | has("modifiers") | not)
              and .to_if_alone[0].key_code == "escape"
              and any(.conditions[]?; .type == "variable_if" and .name == "nvim_caps_lock_control" and .value == true)
          )
        ] | length == 1
      )
      and (
        [
          $profile.complex_modifications.rules[].manipulators[]
          | select(
              .type == "basic"
              and .from.key_code == "caps_lock"
              and .to[0].key_code == "left_control"
              and .to[0].lazy == true
              and .to[0].modifiers == ["left_option", "left_command"]
              and .to_if_alone[0].key_code == "escape"
              and any(.conditions[]?; .type == "variable_unless" and .name == "nvim_caps_lock_control" and .value == true)
          )
        ] | length == 1
      )
' "$KARABINER_CONFIG" >/dev/null; then
    echo "  ✓ Caps Lock is Hyper by default and Control while Neovim is focused"
    ((PASSED++))
else
    echo "  ✗ Caps Lock Hyper/Neovim-Control mapping is missing or invalid"
    ((FAILED++))
fi

assert_contains "$NVIM_INIT" "nvim_caps_lock_control" "Neovim toggles Caps Lock Karabiner variable"
assert_contains "$NVIM_INIT" "karabiner_cli" "Neovim uses karabiner_cli for Caps Lock mode"
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
assert_contains "$SKHDRC" "space_slot_mode @.*Space Shortcut" "Space shortcut mode shows entry notification"
assert_contains "$SKHDRC" "space_slot_mode < 1.*projects set-space-slot 1" "Alt+Shift+= sets space shortcut 1"
assert_contains "$SKHDRC" "alt + shift - 1.*projects focus-space 1" "Alt+Shift+1 focuses project space slot 1"
assert_contains "$SKHDRC" "alt + shift - h.*projects cycle prev" "Alt+Shift+h cycles project spaces"
assert_contains "$SKHDRC" "alt + shift - k.*projects cycle next" "Alt+Shift+k cycles project spaces"
assert_contains "$SKHDRC" "ctrl + alt + cmd - p.*projects pick" "Hyper+p opens project hub"
assert_contains "$SKHDRC" "ctrl + alt + cmd - n.*projects new" "Hyper+n quick-creates project"
assert_contains "$SKHDRC" "ctrl + alt + cmd - e.*projects pick" "Hyper+e opens project hub"
assert_contains "$SKHDRC" "ctrl + alt + cmd - 1.*projects focus-project 1" "Hyper+1 focuses project slot 1"
assert_contains "$SKHDRC" "ctrl + alt + cmd + shift - 1.*projects adopt --project-slot 1" "Hyper+Shift+1 adopts into project slot 1"
assert_contains "$SKHDRC" "ctrl + alt + cmd + shift - 0x33.*projects detach" "Hyper+Shift+Backspace detaches current space"
assert_not_contains "$SKHDRC" "ctrl + alt + shift - 1.*window --space 1" "Mission Control index moves removed"
assert_contains "$SKHDRC" "alt - n.*create-space auto" "Alt+n creates a new space and conditionally moves a focused non-scratchpad window"
assert_contains "$SKHDRC" "ctrl + alt - n.*create-space move-window" "Ctrl+Alt+n moves the focused window to a new space"
assert_contains "$DOTFILES_DIR/home/dot_config/yabai/executable_create-space" "before_uuids" "create-space snapshots spaces before creation"
assert_contains "$DOTFILES_DIR/home/dot_config/yabai/executable_create-space" "space --focus.*new_index" "create-space focuses the newly created space"
assert_contains "$DOTFILES_DIR/home/dot_config/yabai/executable_create-space" "scratchpad_label" "create-space ignores focused scratchpad windows in auto mode"
assert_contains "$DOTFILES_DIR/home/dot_config/yabai/executable_create-space" "movable_windows.*-gt 1" "create-space auto mode keeps the only normal window on its current space"
assert_contains "$DOTFILES_DIR/home/dot_config/yabai/executable_create-space" "capture_focused_window_for_move true" "create-space auto mode requires another normal window before moving"
assert_contains "$DOTFILES_DIR/home/dot_config/yabai/executable_create-space" "capture_focused_window_for_move false" "create-space move-window mode can still force a focused window move"
assert_contains "$DOTFILES_DIR/home/dot_config/yabai/executable_create-space" "move_focused_window=true" "create-space can mark a focused regular window for moving"
assert_not_contains "$DOTFILES_DIR/home/dot_config/yabai/executable_create-space" "YABAI_SPACE_WALLPAPER" "create-space has no wallpaper assignment controls"
assert_not_contains "$DOTFILES_DIR/home/dot_config/yabai/executable_create-space" "set picture of current desktop" "create-space does not apply wallpapers"
assert_contains "$SKHDRC" "alt - 1.*hotkeys app-focus 1.*@browser" "Alt+1 browser focus goes through hotkeys"
assert_contains "$SKHDRC" "alt - 2.*hotkeys app-focus 2.*Codex" "Alt+2 Codex focus goes through hotkeys"
assert_contains "$SKHDRC" "alt - 3.*hotkeys app-focus 3.*@editor" "Alt+3 editor focus goes through zen gate"
assert_contains "$SKHDRC" "alt - 4.*hotkeys app-focus 4.*Microsoft Teams" "Alt+4 Teams focus goes through zen gate"
assert_contains "$SKHDRC" "alt - 5.*hotkeys app-focus 5.*Slack" "Alt+5 Slack focus goes through zen gate"
assert_contains "$SKHDRC" "fn - 0x2B.*scratchpads open codex" "Fn+Comma opens the Codex dotfiles scratchpad"
assert_contains "$SKHDRC" "fn - 1.*scratchpads open projects" "Fn+1 opens the projects tmux scratchpad"
assert_not_contains "$SKHDRC" "alt - 0x2B.*scratchpads open codex" "Alt+Comma no longer opens the Codex dotfiles scratchpad"
assert_not_contains "$SKHDRC" "alt - l.*scratchpads open projects" "Alt+L no longer opens the projects tmux scratchpad"
assert_contains "$SKHDRC" "alt + shift - 0x2A.*hotkeys zen toggle" "Alt+Shift+Backslash toggles zen mode"
assert_contains "$SKHDRC" "alt + shift - 0x32.*hotkeys terminal new" "Alt+Shift+Backtick creates a terminal"
assert_contains "$SKHDRC" "alt - 0x2C :.*show_keys.sh" "Alt+Slash toggles the shortcut guide directly"
assert_contains "$DOTFILES_DIR/home/dot_config/skhd/executable_show_keys.sh" 'app="$HOME/.config/skhd/whichkey"' "Shortcut guide launcher keeps the stable live path"
assert_contains "$DOTFILES_DIR/home/dot_config/skhd/executable_show_keys.sh" 'source_file=.*WhichKey.swift' "Shortcut guide launcher lazily rebuilds stale source"
assert_contains "$DOTFILES_DIR/home/dot_config/skhd/executable_show_keys.sh" 'action="${1:-toggle}"' "Shortcut guide launcher separates open, close, and toggle actions"
assert_contains "$DOTFILES_DIR/home/dot_config/skhd/executable_show_keys.sh" 'whichkey-launch.lock' "Shortcut guide launcher prevents duplicate app races"
assert_contains "$SKHDRC" 'fn - 2.*skhd -k "ctrl + cmd + shift - 3"' "Fn+2 copies a full-screen screenshot through macOS"
assert_contains "$SKHDRC" 'fn - 3.*skhd -k "cmd + shift - 4"' "Fn+3 saves an interactive screenshot through macOS"
assert_contains "$SKHDRC" 'fn - 4.*skhd -k "ctrl + cmd + shift - 4"' "Fn+4 copies an interactive screenshot through macOS"

assert_contains "$HOTKEYS" "ZEN_MODE_FILE=.*zen_mode" "hotkeys stores zen mode state"
assert_contains "$HOTKEYS" "3|4|5)" "hotkeys disables app slots 3-5 in zen mode"
assert_contains "$HOTKEYS" "before_json=.*query --windows" "terminal opener snapshots existing app windows before launch"
assert_contains "$HOTKEYS" "stale_lock_after_s=10" "terminal opener clears stale launch locks"
assert_contains "$HOTKEYS" "display --focus.*current_display" "terminal opener restores the originating display before focus"
assert_contains "$HOTKEYS" "window.*--space.*current_space" "terminal opener moves new windows to the originating space"
assert_contains "$DOTFILES_DIR/home/dot_config/skhd/executable_focus_app.sh" 'hotkeys terminal new' "Ghostty app focus creates a normal terminal when no eligible window exists"
assert_contains "$DOTFILES_DIR/home/dot_config/skhd/executable_toggle_ghostty_quick_terminal.sh" "background-opacity=1" "quick terminal scratchpad keeps Ghostty opaque"
assert_file_exists "$DOTFILES_DIR/home/bin/executable_tmux-session-template" "tmux session template helper exists"
assert_file_exists "$TMUX_WORKSPACE" "declarative tmux workspace helper exists"
assert_file_exists "$TMUX_WHICH_KEY" "repo-owned tmux command-center config exists"
assert_file_exists "$DOTFILES_DIR/home/dot_config/tmux/layouts/project.tmux.tsx" "React-like project layout exists"
assert_contains "$TMUX_CONFIG" "after-new-session\[50\].*tmux-session-template auto.*session_name" "ordinary new tmux sessions use the standard template"
assert_contains "$GHOSTTY_CONFIG" "keybind = cmd+b=text:\\\\x01\\\\x62" "Cmd+B sends tmux prefix plus b for the Yazi side pane"
assert_contains "$GHOSTTY_CONFIG" "keybind = cmd+shift+b=text:\\\\x01\\\\x42" "Cmd+Shift+B sends tmux prefix plus B for the full Yazi window"
assert_not_contains "$GHOSTTY_CONFIG" "keybind = cmd+b=text:\\\\x01\\\\x7a" "Cmd+B no longer sends the tmux zoom binding"
assert_contains "$TMUX_CONFIG" 'bind-key -N "Toggle Yazi side pane" b run-shell.*tmux-yazi-pane toggle.*pane_id' "tmux toggles Yazi through the idempotent side-pane helper"
assert_contains "$TMUX_CONFIG" 'bind-key -N "Open Yazi full window" B new-window -S -n yazi -c.*pane_current_path.*yazi' "tmux opens or selects a dedicated Yazi window"
assert_file_exists "$DOTFILES_DIR/home/bin/executable_tmux-yazi-pane" "tmux Yazi pane helper exists"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-yazi-pane" '@dotfiles_yazi_side' "tmux Yazi pane helper marks its managed pane"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-yazi-pane" 'wait-for -L' "tmux Yazi pane helper serializes rapid toggles"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-yazi-pane" 'yazi "$directory"' "tmux Yazi pane helper passes the current folder explicitly"
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
assert_contains "$TMUX_CONFIG" 'status-left.*E:@dotfiles_status_accent.*▌' "tmux draws the session accent as a strong left rail"
assert_contains "$TMUX_CONFIG" "status-right ''" "tmux omits status telemetry modules"
assert_contains "$TMUX_CONFIG" "window-status-activity-style default" "tmux keeps activity alerts pill-free"
assert_contains "$TMUX_CONFIG" "window-status-bell-style default" "tmux keeps bell alerts pill-free"
assert_contains "$TMUX_CONFIG" "window-status-format.*terminal.*~.*#W" "tmux renders stable app labels and shortens terminal to tilde"
assert_contains "$TMUX_CONFIG" "window-status-current-format.*terminal.*~.*#W" "tmux highlights the current stable app label"
assert_contains "$TMUX_CONFIG" 'window-status-current-format.*@thm_crust.*bg=#{E:@dotfiles_status_accent}.*#W.*default' "tmux renders the active app as a compact session-colored capsule"
assert_contains "$TMUX_CONFIG" "bind-key , command-prompt.*dotfiles_window_type.*codex.*#T,#W.*rename-window" "tmux seeds typed Codex renames from the Codex pane title"
assert_file_exists "$TMUX_BORDER_ACCENT" "tmux border accent helper exists"
assert_contains "$TMUX_BORDER_ACCENT" 'list-clients' "tmux border accent reads focused client state"
assert_contains "$TMUX_BORDER_ACCENT" 'E:@dotfiles_status_accent' "tmux border accent reuses the status bar color"
assert_contains "$TMUX_BORDER_ACCENT" 'active_color=' "tmux border accent updates JankyBorders at runtime"
assert_contains "$TMUX_CONFIG" "C-0.*tmux-session-template cycle.*terminal" "Ctrl+0 cycles terminal windows by type"
assert_contains "$TMUX_CONFIG" "C-1.*tmux-session-template cycle.*codex" "Ctrl+1 cycles Codex windows by type"
assert_contains "$TMUX_CONFIG" "C-2.*tmux-session-template cycle.*nvim" "Ctrl+2 cycles Neovim windows by type"
assert_contains "$TMUX_CONFIG" "C-S-0.*tmux-session-template new.*terminal" "Ctrl+Shift+0 creates a terminal window"
assert_contains "$TMUX_CONFIG" "C-S-1.*tmux-session-template new.*codex" "Ctrl+Shift+1 creates a Codex window"
assert_contains "$TMUX_CONFIG" "C-S-2.*tmux-session-template new.*nvim" "Ctrl+Shift+2 creates a Neovim window"
assert_contains "$TMUX_CONFIG" "bind-key '|'.*split-window -h.*pane_current_path" "tmux directly splits a cwd-preserving pane to the right"
assert_contains "$TMUX_CONFIG" "bind-key '-'.*split-window -v.*pane_current_path" "tmux directly splits a cwd-preserving pane below"
assert_contains "$TMUX_CONFIG" "tmux-plugins/tmux-resurrect" "tmux declares session persistence"
assert_contains "$TMUX_CONFIG" "@continuum-restore" "tmux restores persisted sessions on cold start"
assert_contains "$TMUX_WHICH_KEY" "tmux-workspace pick" "tmux command center opens declarative layouts"
assert_contains "$TMUX_WHICH_KEY" "kill-session" "tmux command center can close sessions"
assert_contains "$TMUX_WHICH_KEY" "tmux-session-template new" "tmux command center creates typed windows"
assert_not_contains "$TMUX_CONFIG" "C-[012] select-window" "Ctrl+0/1/2 no longer target fixed indices"
assert_contains "$TMUX_CONFIG" "C-3 select-window -t :3" "Ctrl+3 keeps direct index switching"
assert_contains "$GHOSTTY_CONFIG" "ctrl+shift+digit_0=csi:48;6u" "Ghostty emits distinct Ctrl+Shift+0 input for tmux"
assert_contains "$GHOSTTY_CONFIG" "ctrl+shift+digit_1=csi:49;6u" "Ghostty emits distinct Ctrl+Shift+1 input for tmux"
assert_contains "$GHOSTTY_CONFIG" "ctrl+shift+digit_2=csi:50;6u" "Ghostty emits distinct Ctrl+Shift+2 input for tmux"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template" "pane_start_command" "tmux template leaves command sessions alone"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template" "DOTFILES_TMUX_TEMPLATE" "tmux template supports explicit opt-out"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template" 'session.*!= hs-\*' "tmux template leaves hs sessions alone"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template" "wait-for -L" "tmux template serializes concurrent layout creation"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template" "WINDOW_TYPE_OPTION=.*dotfiles_window_type" "tmux windows carry stable type metadata"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template" "new-window -d -P" "tmux captures duplicate window IDs before launching commands"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "open:codex" "scratchpads supports Codex dotfiles scratchpad"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "open:projects" "scratchpads supports projects tmux scratchpad"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "SCRATCHPAD_TERMINAL_LABEL" "scratchpads uses one terminal scratchpad window"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "SCRATCHPAD_DOTFILES_TMUX_SESSION" "scratchpads declares the dotfiles tmux session"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "SCRATCHPAD_PROJECTS_TMUX_SESSION" "scratchpads declares the projects tmux session"
assert_not_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "SCRATCHPAD_TMUX_SESSION=" "scratchpads does not use one shared tmux session"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "scratchpad_codex_dotfiles" "scratchpads removes the stale Codex scratchpad rule"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "scratchpad_projects_tmux" "scratchpads removes the stale projects scratchpad rule"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "open_terminal_tmux_scratchpad.*dotfiles" "Codex hotkey opens the terminal scratchpad on dotfiles"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "open_terminal_tmux_scratchpad.*projects" "Projects hotkey opens the terminal scratchpad on projects"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "switch_terminal_scratchpad_client" "scratchpads switches the existing tmux client"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "SCRATCHPAD_TMUX_CLIENT_OPTION" "scratchpads records the terminal tmux client"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "infer_terminal_scratchpad_client" "scratchpads recovers a stale terminal tmux client"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "client_session" "scratchpads infers the terminal client from scratchpad sessions"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "attach_dotfiles_tmux_session" "Codex scratchpad attaches to the dotfiles tmux session"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "attach_projects_tmux_session.*nvim" "Projects scratchpad can attach to the nvim tmux window"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "close_scratchpads_except_label" "scratchpads closes other scratchpad windows before opening"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "close_duplicate_scratchpads_for_label" "scratchpads closes duplicate scratchpad windows"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "SCRATCHPAD_PROJECTS_DIR" "scratchpads roots the projects tmux session in ~/projects"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "background=#000000" "scratchpads use a black Ghostty background"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "background-opacity=1" "scratchpads keep Ghostty opaque"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "background-blur=false" "scratchpads disable Ghostty blur"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "new-session -d -e DOTFILES_TMUX_TEMPLATE=skip.*-n terminal" "scratchpads opt out of the automatic hook while creating their raw terminal"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "ensure_standard_scratchpad_tmux_windows" "scratchpads keeps standard windows in each tmux session"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "tmux-session-template.*ensure" "scratchpads reuse the default tmux template"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template" "ensure_standard_tmux_window.*terminal 0" "tmux template keeps terminal at window 0"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template" "ensure_standard_tmux_window.*codex 1 codex" "tmux template starts Codex at window 1"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template" "ensure_standard_tmux_window.*nvim 2 nvim" "tmux template starts Neovim at window 2"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "hide_scratchpad_and_restore_focus" "scratchpads toggles Codex visibility without closing"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "restore_origin_focus" "scratchpads restore the originating display and space"

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
    bash -c 'source "$1"; app_mru_list Ghostty' _ "$DOTFILES_DIR/home/dot_config/skhd/executable_app-mru.sh"
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
assert_contains "$YABAIRC" 'projects record-focus' "yabairc tracks project last_space on focus"
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
