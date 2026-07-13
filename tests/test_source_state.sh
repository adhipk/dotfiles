#!/usr/bin/env bash

# Test suite for chezmoi source-state layout

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(dirname "$TEST_DIR")"
TEMP_HOME="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-source-state-test.XXXXXX")"
SPACE_DISPLAY_MODULE="$DOTFILES_DIR/modules/space-display"
SETUP_YABAI_SA_COMMAND="$SPACE_DISPLAY_MODULE/bin/setup-yabai-sa"
CREATE_SPACE_COMMAND="$SPACE_DISPLAY_MODULE/bin/create-space"
SETUP_YABAI_SA_BRIDGE="$DOTFILES_DIR/home/bin/executable_setup-yabai-sa.tmpl"
CREATE_SPACE_BRIDGE="$DOTFILES_DIR/home/dot_config/yabai/executable_create-space.tmpl"
APPEARANCE_PIP_MODULE="$DOTFILES_DIR/modules/appearance-pip"
TMUX_BORDER_ACCENT_COMMAND="$APPEARANCE_PIP_MODULE/bin/tmux-border-accent"
TILE_PIP_WINDOW_COMMAND="$APPEARANCE_PIP_MODULE/bin/tile-pip-window"
TMUX_BORDER_ACCENT_BRIDGE="$DOTFILES_DIR/home/bin/executable_tmux-border-accent.tmpl"
TILE_PIP_WINDOW_BRIDGE="$DOTFILES_DIR/home/dot_config/yabai/executable_tile-pip-window.tmpl"

PASSED=0
FAILED=0

cleanup() {
    rm -rf "$TEMP_HOME"
}
trap cleanup EXIT

assert_file_exists() {
    local file="$1"
    local test_name="$2"

    if [ -f "$file" ]; then
        echo "  ✓ $test_name"
        ((PASSED++))
    else
        echo "  ✗ $test_name"
        echo "    Missing file: $file"
        ((FAILED++))
    fi
}

assert_file_missing() {
    local file="$1"
    local test_name="$2"

    if [ ! -e "$file" ]; then
        echo "  ✓ $test_name"
        ((PASSED++))
    else
        echo "  ✗ $test_name"
        echo "    Unexpected file: $file"
        ((FAILED++))
    fi
}

assert_contains() {
    local file="$1"
    local pattern="$2"
    local test_name="$3"

    if grep -q "$pattern" "$file"; then
        echo "  ✓ $test_name"
        ((PASSED++))
    else
        echo "  ✗ $test_name"
        echo "    Pattern not found: $pattern"
        ((FAILED++))
    fi
}

assert_not_contains() {
    local file="$1"
    local pattern="$2"
    local test_name="$3"

    if grep -q "$pattern" "$file"; then
        echo "  ✗ $test_name"
        echo "    Unexpected pattern found: $pattern"
        ((FAILED++))
    else
        echo "  ✓ $test_name"
        ((PASSED++))
    fi
}

assert_line_order() {
    local file="$1"
    local first_pattern="$2"
    local second_pattern="$3"
    local test_name="$4"
    local first_line
    local second_line

    first_line=$(grep -n "$first_pattern" "$file" | head -n 1 | cut -d: -f1)
    second_line=$(grep -n "$second_pattern" "$file" | head -n 1 | cut -d: -f1)

    if [ -n "$first_line" ] && [ -n "$second_line" ] && [ "$first_line" -lt "$second_line" ]; then
        echo "  ✓ $test_name"
        ((PASSED++))
    else
        echo "  ✗ $test_name"
        echo "    Expected '$first_pattern' before '$second_pattern'"
        ((FAILED++))
    fi
}

echo "================================"
echo "Chezmoi Source-State Tests"
echo "================================"

echo ""
echo "Testing source root..."
assert_contains "$DOTFILES_DIR/.chezmoiroot" "^home$" ".chezmoiroot selects home/"

echo ""
echo "Testing managed configs..."
for file in \
    dot_zshrc \
    dot_skhdrc.tmpl \
    dot_yabairc.tmpl \
    dot_tmux.conf.tmpl \
    dot_config/private_karabiner/karabiner.json \
    dot_config/zsh/zshrc.commands \
    dot_config/zsh/acli-completions \
    dot_config/starship.toml \
    dot_config/yazi/init.lua \
    dot_config/yazi/keymap.toml \
    dot_config/yazi/package.toml \
    dot_config/symlink_nvim.tmpl; do
    assert_file_exists "$DOTFILES_DIR/home/$file" "$file is declared"
done
assert_file_exists "$DOTFILES_DIR/home/dot_agents/AGENTS.md.tmpl" "shared agent guidance is declared"
assert_file_exists "$DOTFILES_DIR/home/dot_codex/symlink_AGENTS.md.tmpl" "Codex global guidance link is declared"
assert_file_exists "$DOTFILES_DIR/home/dot_claude/symlink_CLAUDE.md.tmpl" "Claude global guidance link is declared"
assert_file_exists "$DOTFILES_DIR/home/dot_config/opencode/symlink_AGENTS.md.tmpl" "OpenCode global guidance link is declared"
assert_file_exists "$DOTFILES_DIR/home/dot_config/opencode/opencode.json" "OpenCode agent configuration is declared"
assert_contains "$DOTFILES_DIR/home/dot_agents/AGENTS.md.tmpl" '## Canonical Task Tracking' "shared agent guidance declares canonical task tracking"
assert_contains "$DOTFILES_DIR/home/dot_agents/AGENTS.md.tmpl" 'todo ls --json' "shared agent guidance requires canonical task inspection"
assert_contains "$DOTFILES_DIR/home/dot_agents/AGENTS.md.tmpl" 'current project or tmux session working directory' "shared agent guidance keeps tasks beside the active work"
assert_contains "$DOTFILES_DIR/home/dot_agents/AGENTS.md.tmpl" 'same working directory as the session' "shared agent guidance keeps tmux apps in the session cwd"
assert_contains "$DOTFILES_DIR/home/dot_codex/symlink_AGENTS.md.tmpl" '\.chezmoi\.homeDir }}/\.agents/AGENTS\.md' "Codex reads the shared agent guidance"
assert_contains "$DOTFILES_DIR/home/dot_claude/symlink_CLAUDE.md.tmpl" '\.chezmoi\.homeDir }}/\.agents/AGENTS\.md' "Claude reads the shared agent guidance"
assert_contains "$DOTFILES_DIR/home/dot_config/opencode/symlink_AGENTS.md.tmpl" '\.chezmoi\.homeDir }}/\.agents/AGENTS\.md' "OpenCode reads the shared agent guidance"
assert_contains "$DOTFILES_DIR/home/dot_config/opencode/opencode.json" "active project's todo\\.txt" "OpenCode personal agent uses the active project's task store"
assert_not_contains "$DOTFILES_DIR/home/dot_config/opencode/opencode.json" 'Todoist' "OpenCode no longer directs agents to Todoist"
if jq -e . "$DOTFILES_DIR/home/dot_config/opencode/opencode.json" >/dev/null; then
    echo "  ✓ OpenCode agent configuration parses"
    ((PASSED++))
else
    echo "  ✗ OpenCode agent configuration is invalid JSON"
    ((FAILED++))
fi
assert_contains "$DOTFILES_DIR/home/dot_config/symlink_nvim.tmpl" '\.chezmoi\.sourceDir }}/../nvim' "Neovim config links to the repository checkout"
assert_file_exists "$DOTFILES_DIR/nvim/init.lua" "Neovim config is stored in the repository"
assert_contains "$DOTFILES_DIR/home/dot_config/private_karabiner/karabiner.json" 'Caps Lock: Hyper on hold, Escape on tap' "Karabiner declares one global Caps Lock behavior"
assert_not_contains "$DOTFILES_DIR/home/dot_config/private_karabiner/karabiner.json" 'nvim_caps_lock_control' "Karabiner has no Neovim-specific Caps Lock state"
assert_not_contains "$DOTFILES_DIR/nvim/init.lua" 'nvim_caps_lock_control' "Neovim does not own Caps Lock state"
assert_not_contains "$DOTFILES_DIR/nvim/init.lua" 'karabiner_cli' "Neovim does not reconfigure Karabiner"
assert_contains "$DOTFILES_DIR/Brewfile" 'brew "clipboard"' "Clipboard CLI is declared in Brewfile"
assert_contains "$DOTFILES_DIR/Brewfile" 'tap "FelixKratz/formulae"' "JankyBorders Homebrew tap is declared"
assert_contains "$DOTFILES_DIR/Brewfile" 'brew "borders"' "JankyBorders is declared in Brewfile"
assert_contains "$DOTFILES_DIR/Brewfile" 'brew "bun"' "Bun is declared for React-like tmux layouts"
assert_contains "$DOTFILES_DIR/Brewfile" 'cask "codex"' "Codex CLI is declared in Brewfile"
assert_contains "$DOTFILES_DIR/Brewfile" 'cask "codex-app"' "Codex desktop app is declared in Brewfile"
assert_contains "$DOTFILES_DIR/Brewfile" 'cask "google-chrome"' "Chrome is declared for the managed browser extension"
assert_contains "$DOTFILES_DIR/Brewfile" 'brew "gh"' "GitHub CLI is declared in Brewfile"
assert_contains "$DOTFILES_DIR/Brewfile" 'brew "marksman"' "Marksman Markdown LSP is declared in Brewfile"
assert_contains "$DOTFILES_DIR/Brewfile" 'brew "node"' "Node and npm are declared for external project setup"
assert_contains "$DOTFILES_DIR/Brewfile" 'brew "pnpm"' "pnpm is declared for Chrome extension builds"
assert_contains "$DOTFILES_DIR/Brewfile" 'brew "python"' "Python is declared for tmux-which-key menu generation"
assert_contains "$DOTFILES_DIR/Brewfile" 'brew "tree-sitter"' "Tree-sitter CLI is declared in Brewfile"
assert_contains "$DOTFILES_DIR/Brewfile" 'brew "tuxedo"' "Tuxedo is declared for canonical todo.txt management"
assert_contains "$DOTFILES_DIR/Brewfile" 'brew "uv"' "uv is declared for the kit text-to-speech command"
assert_contains "$DOTFILES_DIR/Brewfile" 'brew "yazi"' "Yazi is declared in Brewfile"
assert_contains "$DOTFILES_DIR/Brewfile" 'brew "yq"' "yq is declared in Brewfile"
assert_contains "$DOTFILES_DIR/Brewfile" 'cask "vscodium"' "VSCodium is declared in Brewfile"
assert_contains "$DOTFILES_DIR/Brewfile" 'cask "microsoft-teams"' "Teams is declared for its app-focus shortcut"
assert_contains "$DOTFILES_DIR/Brewfile" 'cask "raycast"' "Raycast is declared for the managed extension project"
assert_contains "$DOTFILES_DIR/Brewfile" 'cask "slack"' "Slack is declared for its app-focus shortcut"
assert_contains "$DOTFILES_DIR/Brewfile" 'brew "starship"' "Starship prompt is declared in Brewfile"
assert_contains "$DOTFILES_DIR/home/dot_config/yazi/package.toml" "orhnk/system-clipboard" "Yazi system clipboard plugin is declared"
assert_contains "$DOTFILES_DIR/home/dot_config/yazi/keymap.toml" "plugin system-clipboard" "Yazi system clipboard keymap is declared"
assert_contains "$DOTFILES_DIR/home/dot_config/zsh/zshrc.commands" "svg-png()" "svg-png shell helper is declared"
assert_contains "$DOTFILES_DIR/home/.chezmoiexternal.toml.tmpl" 'tmux/plugins/tpm' "TPM is declared as a chezmoi external"
assert_contains "$DOTFILES_DIR/install.sh" 'install_tmux_plugins' "installer provisions TPM-managed tmux plugins"
assert_contains "$DOTFILES_DIR/install.sh" 'TMUX_PLUGIN_MANAGER_PATH' "installer uses the destination tmux plugin path"
assert_contains "$DOTFILES_DIR/install.sh" 'install_tmux_command_center' "installer links the managed tmux command center"
assert_contains "$DOTFILES_DIR/home/.chezmoidata.toml" 'revision = "85fb9756447b989f3b94e515d1e6ee7fec76cba2"' "standard ChezMoi data pins the tested tmux-which-key revision"
assert_contains "$DOTFILES_DIR/install.sh" 'pins apply --manager tpm' "installer delegates immutable TPM checkout enforcement to the dependency module"
assert_contains "$DOTFILES_DIR/install.sh" 'ln -sfn.*managed_config.*plugin_dir/config.yaml' "installer avoids tmux-which-key's GNU-only XDG path"
assert_contains "$DOTFILES_DIR/install.sh" 'mkdir -p.*projects' "installer creates the projects scratchpad root"
assert_contains "$DOTFILES_DIR/bootstrap.sh" 'start_desktop_service yabai' "bootstrap starts the yabai launch service"
assert_contains "$DOTFILES_DIR/bootstrap.sh" 'start_desktop_service skhd' "bootstrap starts the skhd launch service"
assert_contains "$DOTFILES_DIR/bootstrap.sh" 'setup-yabai-sa' "bootstrap documents the required yabai scripting-addition step"
assert_contains "$DOTFILES_DIR/bootstrap.sh" 'DriverKit extension and Input Monitoring' "bootstrap documents Karabiner's first-run approvals"
assert_contains "$SETUP_YABAI_SA_COMMAND" 'sha256:.*--load-sa' "yabai setup scopes sudoers access to the installed binary checksum"
assert_contains "$SETUP_YABAI_SA_COMMAND" 'VISUDO_BIN.*-cf' "yabai setup validates its sudoers file"
assert_contains "$DOTFILES_DIR/modules/projects/install/build-projectdeck.sh" 'command -v swiftc' "ProjectDeck build reports a missing Swift toolchain clearly"

echo ""
echo "Testing zsh prompt and theme setup..."
assert_contains "$DOTFILES_DIR/home/dot_zshrc" "typeset -U path fpath" "zsh deduplicates path and fpath"
assert_contains "$DOTFILES_DIR/home/dot_zshrc" "Some tools assign PATH directly" "zsh deduplicates path after tool initialization"
assert_contains "$DOTFILES_DIR/home/dot_zshrc" '\[ -r "$HOME/.config/zsh/zshrc.commands" \]' "zsh guards command helper sourcing"
assert_contains "$DOTFILES_DIR/home/dot_zshrc" "ANTIGEN_ZSH" "zsh resolves Antigen before sourcing it"
assert_line_order "$DOTFILES_DIR/home/dot_zshrc" "antigen bundle zsh-users/zsh-autosuggestions" "antigen bundle zsh-users/zsh-syntax-highlighting" "zsh-syntax-highlighting loads after autosuggestions"
assert_line_order "$DOTFILES_DIR/home/dot_zshrc" "antigen bundle zsh-users/zsh-completions" "antigen bundle zsh-users/zsh-syntax-highlighting" "zsh-syntax-highlighting loads after completions"
assert_line_order "$DOTFILES_DIR/home/dot_zshrc" "antigen bundle zsh-users/zsh-history-substring-search" "antigen bundle zsh-users/zsh-syntax-highlighting" "zsh-syntax-highlighting loads after history substring search"
assert_not_contains "$DOTFILES_DIR/home/dot_zshrc" "^source zsh-syntax-highlighting.zsh" "zsh does not manually source syntax highlighting after Antigen"
assert_not_contains "$DOTFILES_DIR/home/dot_zshrc" "^source zsh-history-substring-search.zsh" "zsh does not manually source history substring search after Antigen"
assert_contains "$DOTFILES_DIR/home/dot_zshrc" "STARSHIP_CONFIG" "zsh sets a Starship config"
assert_contains "$DOTFILES_DIR/home/dot_zshrc" "starship init zsh" "zsh initializes Starship"
assert_contains "$DOTFILES_DIR/home/dot_zshrc" "command -v starship" "zsh guards Starship initialization"
assert_contains "$DOTFILES_DIR/home/dot_config/starship.toml" "config-schema.json" "Starship config declares its schema"
assert_contains "$DOTFILES_DIR/home/dot_zshrc" "command -v mise" "zsh guards mise initialization"
assert_contains "$DOTFILES_DIR/home/dot_zshrc" "command -v zoxide" "zsh guards zoxide initialization"
assert_contains "$DOTFILES_DIR/home/dot_zshrc" '\[ -x /opt/homebrew/bin/terraform \]' "zsh guards Terraform completion"
assert_not_contains "$DOTFILES_DIR/home/dot_zshrc" "_zoxide_z_complete" "zsh uses zoxide's default completion"
assert_contains "$DOTFILES_DIR/home/dot_zshrc" "bindkey '\\\\ef' forward-word" "Option+Right preserves forward-word"
assert_contains "$DOTFILES_DIR/home/dot_zshrc" "bindkey '\\\\eb' backward-word" "Option+Left preserves backward-word"
assert_contains "$DOTFILES_DIR/home/dot_zshrc" "bindkey '\\\\e\\[1;3C' forward-word" "Option+Right CSI sequence is bound"
assert_contains "$DOTFILES_DIR/home/dot_zshrc" "bindkey '\\\\e\\[1;3D' backward-word" "Option+Left CSI sequence is bound"
assert_not_contains "$DOTFILES_DIR/home/dot_zshrc" "bindkey -s '\\\\ef'" "Alt+F does not override Option+Right"
assert_not_contains "$DOTFILES_DIR/home/dot_zshrc" "catppuccin" "zsh does not reference Catppuccin"
assert_not_contains "$DOTFILES_DIR/home/dot_zshrc" "colorschemes" "zsh does not source shared colorschemes"

echo ""
echo "Testing Ghostty theme setup..."
GHOSTTY_CONFIG="$DOTFILES_DIR/home/Library/Application Support/com.mitchellh.ghostty/config.tmpl"
TMUX_CONFIG_SOURCE="$DOTFILES_DIR/home/dot_tmux.conf.tmpl"
TMUX_WHICH_KEY_SOURCE="$DOTFILES_DIR/home/dot_config/tmux/which-key.yaml.tmpl"
TMUX_YAZI_MODULE="$DOTFILES_DIR/modules/tmux-yazi"
SKHD_CONFIG_SOURCE="$DOTFILES_DIR/home/dot_skhdrc.tmpl"
YABAI_CONFIG_SOURCE="$DOTFILES_DIR/home/dot_yabairc.tmpl"
TERMINAL_WINDOW_TYPES_MODULE="$DOTFILES_DIR/modules/terminal-window-types"
TERMINAL_WINDOW_TYPES_COMMAND="$TERMINAL_WINDOW_TYPES_MODULE/bin/tmux-session-template"
TERMINAL_WINDOW_TYPES_GHOSTTY="$TERMINAL_WINDOW_TYPES_MODULE/targets/ghostty.conf.tmpl"
TERMINAL_WINDOW_TYPES_TMUX="$TERMINAL_WINDOW_TYPES_MODULE/targets/tmux.conf.tmpl"
TERMINAL_WINDOW_TYPES_WHICH_KEY_CYCLE="$TERMINAL_WINDOW_TYPES_MODULE/targets/tmux-which-key-cycle.yaml.tmpl"
TERMINAL_WINDOW_TYPES_WHICH_KEY_NEW="$TERMINAL_WINDOW_TYPES_MODULE/targets/tmux-which-key-new.yaml.tmpl"
TERMINAL_WINDOW_TYPES_WHICH_KEY_DUPLICATE="$TERMINAL_WINDOW_TYPES_MODULE/targets/tmux-which-key-duplicate.yaml.tmpl"
APP_FOCUS_MODULE="$DOTFILES_DIR/modules/app-focus"
PROJECTS_MODULE="$DOTFILES_DIR/modules/projects"
HYPERSPACE_MODULE="$DOTFILES_DIR/modules/hyperspace"
SCRATCHPADS_MODULE="$DOTFILES_DIR/modules/scratchpads"
SCRATCHPADS_COMMAND="$SCRATCHPADS_MODULE/bin/scratchpads"
SCRATCHPADS_QUICK_TERMINAL="$SCRATCHPADS_MODULE/bin/toggle_ghostty_quick_terminal.sh"
TMUX_SESSIONS_MODULE="$DOTFILES_DIR/modules/tmux-sessions"
TMUX_SESSIONS_TMUX="$TMUX_SESSIONS_MODULE/targets/tmux.conf.tmpl"
TMUX_SESSIONS_WHICH_KEY="$TMUX_SESSIONS_MODULE/targets/tmux-which-key-sessions.yaml.tmpl"
GHOSTTY_AUTO_THEME="$DOTFILES_DIR/home/Library/Application Support/com.mitchellh.ghostty/auto/theme.ghostty"
SESH_CONFIG="$TMUX_SESSIONS_MODULE/config/sesh.toml"
assert_file_exists "$GHOSTTY_CONFIG" "Ghostty config is managed"
assert_file_exists "$GHOSTTY_AUTO_THEME" "Ghostty auto theme override is managed"
assert_contains "$GHOSTTY_CONFIG" "theme = Cyberpunk Scarlet Protocol" "Ghostty uses Cyberpunk Scarlet Protocol"
assert_not_contains "$GHOSTTY_AUTO_THEME" "^theme[[:space:]]*=" "Ghostty auto theme override is disabled"
assert_contains "$GHOSTTY_CONFIG" "background-opacity = 0.86" "Ghostty normal terminal background is transparent"
assert_contains "$GHOSTTY_CONFIG" "background-blur = false" "Ghostty background blur is disabled"
assert_contains "$GHOSTTY_CONFIG" 'includeTemplate "../modules/terminal-window-types/targets/ghostty.conf.tmpl"' "Ghostty config composes the terminal-window-types bridge"
assert_contains "$TERMINAL_WINDOW_TYPES_GHOSTTY" "keybind = cmd+backquote=csi:48;5u" "Ghostty maps Cmd+Backtick to terminal type cycling"
assert_contains "$TERMINAL_WINDOW_TYPES_GHOSTTY" "keybind = cmd+digit_1=csi:49;5u" "Ghostty maps Cmd+1 to Codex type cycling"
assert_contains "$TERMINAL_WINDOW_TYPES_GHOSTTY" "keybind = cmd+1=csi:49;5u" "Ghostty includes the Cmd+1 key-name fallback"
assert_contains "$TERMINAL_WINDOW_TYPES_GHOSTTY" "keybind = cmd+digit_2=csi:50;5u" "Ghostty maps Cmd+2 to Neovim type cycling"
assert_contains "$TERMINAL_WINDOW_TYPES_GHOSTTY" "keybind = cmd+2=csi:50;5u" "Ghostty includes the Cmd+2 key-name fallback"
assert_contains "$TERMINAL_WINDOW_TYPES_GHOSTTY" "keybind = cmd+digit_3=csi:51;5u" "Ghostty maps Cmd+3 to Tuxedo type cycling"
assert_contains "$TERMINAL_WINDOW_TYPES_GHOSTTY" "keybind = cmd+3=csi:51;5u" "Ghostty includes the Cmd+3 key-name fallback"
assert_contains "$TMUX_YAZI_MODULE/targets/ghostty.conf.tmpl" "keybind = cmd+b=text:\\\\x01\\\\x62" "tmux-yazi owns the Ghostty Cmd+B bridge"
assert_contains "$TMUX_YAZI_MODULE/targets/ghostty.conf.tmpl" "keybind = cmd+shift+b=text:\\\\x01\\\\x42" "tmux-yazi owns the Ghostty Cmd+Shift+B bridge"
assert_not_contains "$TERMINAL_WINDOW_TYPES_GHOSTTY" '^keybind = ctrl+alt+cmd' "Ghostty terminal-window adapters reserve Hyper"
assert_not_contains "$TERMINAL_WINDOW_TYPES_GHOSTTY" "cmd+backquote=text:\\\\x01" "Ghostty Cmd cycling does not select a fixed index"
assert_contains "$TERMINAL_WINDOW_TYPES_GHOSTTY" "ctrl+shift+digit_0=csi:48;6u" "Ghostty distinguishes Ctrl+Shift+0 for tmux"
assert_contains "$TERMINAL_WINDOW_TYPES_GHOSTTY" "ctrl+shift+digit_1=csi:49;6u" "Ghostty distinguishes Ctrl+Shift+1 for tmux"
assert_contains "$TERMINAL_WINDOW_TYPES_GHOSTTY" "ctrl+shift+digit_2=csi:50;6u" "Ghostty distinguishes Ctrl+Shift+2 for tmux"
assert_contains "$TERMINAL_WINDOW_TYPES_GHOSTTY" "ctrl+shift+digit_3=csi:51;6u" "Ghostty distinguishes Ctrl+Shift+3 for tmux"

echo ""
echo "Testing managed helper commands..."
for file in \
    executable_watch-sync \
    executable_agent-timer.tmpl \
    executable_ghostty-startup-bench \
    executable_lucide-icons-excalidraw.tmpl \
    symlink_gh-create-repo.tmpl \
    executable_man-me \
    executable_dotfiles-module.tmpl \
    executable_dotfiles-deps.tmpl \
    executable_dotfiles-uninstall.tmpl \
    executable_reload-colors \
    executable_setup-yabai-sa.tmpl \
    executable_hotkeys.tmpl \
    executable_scratchpads.tmpl \
    symlink_kit.tmpl \
    symlink_kit-watch.tmpl \
    symlink_todo.tmpl \
    symlink_chezmoi-todo.tmpl \
    executable_tmux-border-accent.tmpl \
    executable_tmux-session-template.tmpl \
    executable_tmux-workspace.tmpl \
    executable_tmux-yazi-pane.tmpl \
    symlink_default-apps.tmpl \
    executable_projects.tmpl \
    executable_projects-pick.tmpl \
    executable_tmux-session-picker.tmpl \
    executable_tmux-sessionizer.tmpl \
    executable_tmux-sessionizer-zoxide.tmpl \
    symlink_unescape-buffer.tmpl \
    symlink_unescape-string.tmpl; do
    assert_file_exists "$DOTFILES_DIR/home/bin/$file" "$file is declared"
done
assert_contains "$SETUP_YABAI_SA_BRIDGE" 'includeTemplate "../modules/space-display/bin/setup-yabai-sa"' "setup-yabai-sa uses a thin module bridge"
assert_contains "$TMUX_BORDER_ACCENT_BRIDGE" 'includeTemplate "../modules/appearance-pip/bin/tmux-border-accent"' "tmux-border-accent uses a thin module bridge"
assert_file_exists "$TERMINAL_WINDOW_TYPES_MODULE/module.yaml" "terminal-window-types module manifest is declared"
assert_file_exists "$TERMINAL_WINDOW_TYPES_COMMAND" "terminal-window-types owns the tmux session template"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template.tmpl" 'includeTemplate "../modules/terminal-window-types/bin/tmux-session-template"' "tmux session template uses a thin chezmoi bridge"
assert_contains "$TMUX_CONFIG_SOURCE" 'includeTemplate "../modules/terminal-window-types/targets/tmux.conf.tmpl"' "tmux config composes terminal-window behavior"
assert_contains "$TMUX_WHICH_KEY_SOURCE" 'includeTemplate "../modules/terminal-window-types/targets/tmux-which-key-cycle.yaml.tmpl"' "tmux command center composes typed-window cycle actions"
assert_contains "$SKHD_CONFIG_SOURCE" 'includeTemplate "../modules/terminal-window-types/targets/skhdrc.tmpl"' "skhd config composes terminal-window adapters"
assert_file_exists "$APP_FOCUS_MODULE/module.yaml" "app-focus module manifest is declared"
assert_file_exists "$APP_FOCUS_MODULE/bin/hotkeys" "app-focus owns the hotkeys router"
assert_file_exists "$DOTFILES_DIR/home/dot_config/skhd/executable_focus_app.sh.tmpl" "app-focus helper bridge is declared"
assert_file_exists "$DOTFILES_DIR/home/dot_config/skhd/executable_app-mru.sh.tmpl" "app-mru helper bridge is declared"
assert_contains "$DOTFILES_DIR/home/bin/executable_hotkeys.tmpl" 'includeTemplate "../modules/app-focus/bin/hotkeys"' "hotkeys command uses a thin app-focus bridge"
assert_contains "$DOTFILES_DIR/home/dot_config/skhd/executable_focus_app.sh.tmpl" 'includeTemplate "../modules/app-focus/bin/focus_app.sh"' "focus-app helper uses a thin module bridge"
assert_contains "$DOTFILES_DIR/home/dot_config/skhd/executable_app-mru.sh.tmpl" 'includeTemplate "../modules/app-focus/bin/app-mru.sh"' "app-mru helper uses a thin module bridge"
assert_contains "$SKHD_CONFIG_SOURCE" 'includeTemplate "../modules/app-focus/targets/skhd-apps.conf.tmpl"' "skhd config composes app-focus shortcuts"
assert_contains "$YABAI_CONFIG_SOURCE" 'includeTemplate "../modules/app-focus/targets/yabai-signals.sh.tmpl"' "yabai config composes app-focus signals"
assert_file_exists "$PROJECTS_MODULE/module.yaml" "projects module manifest is declared"
assert_file_exists "$PROJECTS_MODULE/bin/projects" "projects module owns its CLI"
assert_file_exists "$PROJECTS_MODULE/bin/projects-pick" "projects module owns its picker"
assert_file_exists "$PROJECTS_MODULE/projectdeck/ProjectDeck.swift" "projects module owns ProjectDeck source"
assert_contains "$DOTFILES_DIR/home/bin/executable_projects.tmpl" 'includeTemplate "../modules/projects/bin/projects"' "projects command uses a thin module bridge"
assert_contains "$DOTFILES_DIR/home/bin/executable_projects-pick.tmpl" 'includeTemplate "../modules/projects/bin/projects-pick"' "projects picker uses a thin module bridge"
assert_file_exists "$DOTFILES_DIR/modules/agent-timer/module.yaml" "agent timer module manifest is declared"
assert_file_exists "$DOTFILES_DIR/modules/module-lifecycle/module.yaml" "module lifecycle manifest is declared"
assert_file_exists "$DOTFILES_DIR/modules/module-lifecycle/bin/dotfiles-module" "module lifecycle owns its controller"
assert_contains "$DOTFILES_DIR/home/bin/executable_dotfiles-module.tmpl" 'includeTemplate "../modules/module-lifecycle/bin/dotfiles-module"' "module lifecycle command uses a thin chezmoi bridge"
assert_contains "$DOTFILES_DIR/modules/module-lifecycle/bin/dotfiles-module" 'This is a read-only plan' "module lifecycle keeps preview plans read-only"
assert_contains "$DOTFILES_DIR/modules/module-lifecycle/bin/dotfiles-module" 'validate_repository' "module lifecycle exposes explicit repository validation"
assert_contains "$DOTFILES_DIR/install.sh" 'validate_modules' "installer validates module manifests before apply"
assert_contains "$DOTFILES_DIR/install.sh" 'validate --json' "installer consumes the stable module validation contract"
assert_contains "$DOTFILES_DIR/home/bin/executable_watch-sync" 'watch_paths+=("[$]modules_dir")' "watcher observes feature-owned module sources"
assert_contains "$DOTFILES_DIR/home/bin/executable_watch-sync" 'validate --json' "watcher validates modules before applying changes"
assert_contains "$DOTFILES_DIR/modules/module-lifecycle/bin/dotfiles-module" 'Never use chezmoi destroy' "whole-system plan protects source state"
assert_file_exists "$DOTFILES_DIR/modules/system-uninstall/module.yaml" "system uninstall module manifest is declared"
assert_file_exists "$DOTFILES_DIR/modules/system-uninstall/bin/dotfiles-uninstall" "system uninstall module owns its command"
assert_file_exists "$DOTFILES_DIR/modules/system-uninstall/tests/test_system_uninstall.sh" "system uninstall module owns disposable-home tests"
assert_contains "$DOTFILES_DIR/home/bin/executable_dotfiles-uninstall.tmpl" 'includeTemplate "../modules/system-uninstall/bin/dotfiles-uninstall"' "system uninstall command uses a thin chezmoi bridge"
assert_file_exists "$DOTFILES_DIR/modules/dependencies/module.yaml" "dependency inventory module manifest is declared"
assert_file_exists "$DOTFILES_DIR/modules/dependencies/config/sources.toml" "dependency inventory uses a standard TOML source adapter"
assert_file_exists "$DOTFILES_DIR/modules/dependencies/dependencies.lock.json" "dependency inventory records a checked snapshot"
assert_file_exists "$DOTFILES_DIR/modules/dependencies/tests/test_dependencies.sh" "dependency module owns its focused manager tests"
assert_file_exists "$DOTFILES_DIR/modules/dependencies/install/apply-git-pins.sh.tmpl" "dependency module owns its ChezMoi Git pin lifecycle"
assert_contains "$DOTFILES_DIR/home/bin/executable_dotfiles-deps.tmpl" 'includeTemplate "../modules/dependencies/bin/dotfiles-deps"' "dependency command uses a thin chezmoi bridge"
assert_contains "$DOTFILES_DIR/home/.chezmoiscripts/run_onchange_after_00-dependency-git-pins.sh.tmpl" 'includeTemplate "../modules/dependencies/install/apply-git-pins.sh.tmpl"' "ChezMoi uses a thin dependency pin lifecycle bridge"
assert_contains "$DOTFILES_DIR/modules/dependencies/bin/dotfiles-deps" 'brew.*outdated.*--json=v2' "dependency checks delegate Homebrew update discovery to Brew"
assert_contains "$DOTFILES_DIR/modules/dependencies/README.md" 'remote-unchecked' "dependency module documents unchecked Git remotes honestly"
assert_file_exists "$DOTFILES_DIR/modules/dotfiles-control-center/module.yaml" "native control-center module manifest is declared"
assert_contains "$DOTFILES_DIR/home/bin/executable_dotfiles-control-center.tmpl" 'includeTemplate "../modules/dotfiles-control-center/bin/dotfiles-control-center"' "control center uses a thin conditional bridge"
assert_file_exists "$DOTFILES_DIR/modules/shortcut-guide/module.yaml" "shortcut-guide module manifest is declared"
assert_contains "$DOTFILES_DIR/home/bin/executable_shortcut-catalog.tmpl" 'includeTemplate "../modules/shortcut-guide/bin/shortcut-catalog"' "shortcut catalog uses a thin conditional bridge"
assert_contains "$DOTFILES_DIR/home/dot_config/skhd/executable_show_keys.sh.tmpl" 'includeTemplate "../modules/shortcut-guide/bin/show_keys.sh"' "shortcut launcher uses a thin module bridge"
assert_contains "$DOTFILES_DIR/home/dot_skhdrc.tmpl" 'dotfiles-owner: shortcut-guide' "skhd composition records shortcut-guide ownership"
assert_file_exists "$DOTFILES_DIR/modules/agent-timer/bin/agent-timer" "agent timer owns its global command"
assert_file_exists "$DOTFILES_DIR/modules/agent-timer/policy/time-boxed-delivery.md" "agent timer owns global delivery behavior"
assert_file_exists "$DOTFILES_DIR/modules/agent-timer/hooks/codex-hooks.json" "agent timer owns Codex lifecycle hooks"
assert_file_exists "$DOTFILES_DIR/modules/agent-timer/config/config.toml.tmpl" "agent timer owns its standard configuration"
assert_file_exists "$DOTFILES_DIR/modules/agent-timer/install/manage-cron.sh.tmpl" "agent timer owns cron lifecycle management"
assert_file_exists "$DOTFILES_DIR/modules/agent-timer/install/prepare-disable.sh.tmpl" "agent timer owns its before-apply disable lifecycle"
assert_file_exists "$DOTFILES_DIR/home/dot_codex/hooks.json.tmpl" "Codex hooks use a thin chezmoi bridge"
assert_contains "$DOTFILES_DIR/home/dot_config/agent-timer/config.toml.tmpl" 'includeTemplate "../modules/agent-timer/config/config.toml.tmpl"' "agent timer config uses a thin chezmoi bridge"
assert_file_exists "$DOTFILES_DIR/home/.chezmoiscripts/run_onchange_after_agent-timer-cron.sh.tmpl" "chezmoi mounts the timer cron lifecycle"
assert_file_exists "$DOTFILES_DIR/home/.chezmoiscripts/run_onchange_before_agent-timer-disable.sh.tmpl" "chezmoi mounts the timer before-apply lifecycle"
assert_contains "$DOTFILES_DIR/home/.chezmoiscripts/run_onchange_before_agent-timer-disable.sh.tmpl" 'includeTemplate "../modules/agent-timer/install/prepare-disable.sh.tmpl"' "timer disable lifecycle uses a thin module bridge"
assert_contains "$DOTFILES_DIR/modules/agent-timer/install/prepare-disable.sh.tmpl" 'if not \.modules\.agentTimer\.enabled' "timer shutdown runs only when the module is disabled"
assert_contains "$DOTFILES_DIR/modules/agent-timer/install/prepare-disable.sh.tmpl" 'shutdown --reason module-disabled' "timer disable lifecycle stops workers before removal"
assert_contains "$DOTFILES_DIR/home/bin/executable_agent-timer.tmpl" 'includeTemplate "../modules/agent-timer/bin/agent-timer"' "agent timer command is a thin module bridge"
assert_contains "$DOTFILES_DIR/home/dot_agents/AGENTS.md.tmpl" 'includeTemplate "../modules/agent-timer/policy/time-boxed-delivery.md"' "global agent policy includes the timer module"
assert_contains "$DOTFILES_DIR/modules/agent-timer/policy/time-boxed-delivery.md" 'TASK_TIMELIMIT_SECS' "global policy declares the hard task budget"
assert_contains "$DOTFILES_DIR/modules/agent-timer/policy/time-boxed-delivery.md" 'Checkpoint expiry is never a termination condition' "global policy continues work after recurring checkpoints"
assert_contains "$DOTFILES_DIR/modules/agent-timer/policy/time-boxed-delivery.md" 'Never wait for checkpoint collection' "global policy delegates non-blocking checkpoint reporting"
assert_contains "$DOTFILES_DIR/modules/agent-timer/policy/time-boxed-delivery.md" 'immediately re-arms 600 seconds' "global policy declares the recurring 600-second default"
assert_not_contains "$DOTFILES_DIR/home/dot_zshrc" 'agent-timer/env.zsh' "zsh does not source timer configuration"
assert_contains "$DOTFILES_DIR/modules/agent-timer/bin/agent-timer" 'sesh list --tmux --json\|[$]SESH_BIN.*list --tmux --json' "agent timer inventories durable sessions through sesh"
assert_contains "$DOTFILES_DIR/modules/agent-timer/bin/agent-timer" 'send-keys -t.*-l' "agent timer uses literal tmux steering"
assert_contains "$DOTFILES_DIR/modules/agent-timer/bin/agent-timer" 'new %SECONDS%s block is armed immediately' "agent timer default steer announces immediate re-arming"
assert_contains "$DOTFILES_DIR/modules/agent-timer/bin/agent-timer" 'while \[\[ -f "[$]state_file" \]\]' "agent timer worker continues across checkpoint blocks"
assert_file_exists "$DOTFILES_DIR/modules/kit-tts/module.yaml" "kit-tts adapter manifest is declared"
assert_file_exists "$DOTFILES_DIR/modules/kit-tts/targets/kit-path.tmpl" "kit-tts owns the kit checkout path adapter"
assert_file_exists "$DOTFILES_DIR/modules/kit-tts/targets/kit-watch-path.tmpl" "kit-tts owns the watcher checkout path adapter"
assert_contains "$DOTFILES_DIR/home/bin/symlink_kit.tmpl" 'includeTemplate "../../modules/kit-tts/targets/kit-path.tmpl"' "kit uses the pinned project adapter"
assert_contains "$DOTFILES_DIR/home/bin/symlink_kit-watch.tmpl" 'includeTemplate "../../modules/kit-tts/targets/kit-watch-path.tmpl"' "kit-watch uses the pinned project adapter"
assert_file_missing "$DOTFILES_DIR/modules/kit-tts/bin/kit" "kit implementation is no longer duplicated in dotfiles"
assert_file_exists "$DOTFILES_DIR/modules/gh-create-repo/module.yaml" "gh-create-repo adapter manifest is declared"
assert_file_exists "$DOTFILES_DIR/modules/gh-create-repo/tests/test_module.sh" "gh-create-repo owns its parent adapter test"
assert_contains "$DOTFILES_DIR/home/bin/symlink_gh-create-repo.tmpl" 'includeTemplate "../../modules/gh-create-repo/targets/gh-create-repo-path.tmpl"' "gh-create-repo uses the pinned project adapter"
assert_file_missing "$DOTFILES_DIR/home/bin/executable_gh-create-repo" "gh-create-repo implementation is no longer duplicated in dotfiles"
assert_file_exists "$DOTFILES_DIR/modules/macos-default-apps/module.yaml" "macos-default-apps adapter manifest is declared"
assert_file_exists "$DOTFILES_DIR/modules/macos-default-apps/tests/test_module.sh" "macos-default-apps owns its parent adapter test"
assert_contains "$DOTFILES_DIR/home/bin/symlink_default-apps.tmpl" 'includeTemplate "../../modules/macos-default-apps/targets/default-apps-path.tmpl"' "default-apps uses the pinned project adapter"
assert_file_missing "$DOTFILES_DIR/scripts/default-apps.sh" "default-apps implementation is no longer duplicated in dotfiles"
assert_file_exists "$DOTFILES_DIR/modules/unescape-cli/module.yaml" "unescape-cli adapter manifest is declared"
assert_file_exists "$DOTFILES_DIR/modules/unescape-cli/tests/test_module.sh" "unescape-cli owns one consolidated parent test"
assert_contains "$DOTFILES_DIR/home/bin/symlink_unescape-buffer.tmpl" 'includeTemplate "../../modules/unescape-cli/targets/unescape-buffer-path.tmpl"' "unescape-buffer uses the pinned project adapter"
assert_contains "$DOTFILES_DIR/home/bin/symlink_unescape-string.tmpl" 'includeTemplate "../../modules/unescape-cli/targets/unescape-string-path.tmpl"' "unescape-string uses the pinned project adapter"
assert_file_missing "$DOTFILES_DIR/modules/unescape-buffer/module.yaml" "legacy unescape-buffer module is removed"
assert_file_missing "$DOTFILES_DIR/modules/unescape-string/module.yaml" "legacy unescape-string module is removed"
assert_file_missing "$DOTFILES_DIR/home/dot_todo" "Mutable todo.txt data is not managed by chezmoi"
assert_not_contains "$DOTFILES_DIR/home/dot_zshrc" '^export TODO_\|^export DONE_FILE' "Shell does not pin Tuxedo to a global task directory"
assert_file_exists "$DOTFILES_DIR/modules/todo/module.yaml" "todo module manifest is declared"
assert_file_exists "$DOTFILES_DIR/modules/todo/README.md" "todo module documents its external adapter contract"
assert_file_exists "$DOTFILES_DIR/modules/todo/tests/test_todo.sh" "todo module owns its focused tests"
assert_contains "$DOTFILES_DIR/modules/todo/module.yaml" '^apiVersion: dotfiles/v1$' "todo module uses the dotfiles module contract"
assert_contains "$DOTFILES_DIR/modules/todo/module.yaml" 'standalone: false' "todo module delegates standalone distribution upstream"
assert_contains "$DOTFILES_DIR/modules/todo/module.yaml" 'chezmoiCommand: todo' "todo module declares native chezmoi plugin dispatch"
assert_contains "$DOTFILES_DIR/modules/todo/module.yaml" 'preserved:' "todo module preserves project ledgers by default"
assert_contains "$DOTFILES_DIR/modules/todo/module.yaml" 'ephemeral:' "todo module declares its transient lock state"
assert_contains "$DOTFILES_DIR/home/bin/symlink_todo.tmpl" 'includeTemplate "../../modules/todo/targets/todo-path.tmpl"' "todo command uses the pinned project adapter"
assert_contains "$DOTFILES_DIR/home/bin/symlink_chezmoi-todo.tmpl" 'includeTemplate "../../modules/todo/targets/todo-path.tmpl"' "chezmoi-todo uses the pinned project adapter"
assert_contains "$DOTFILES_DIR/home/bin/symlink_todo.tmpl" 'if \.modules\.todo\.enabled' "todo command follows module enablement"
assert_contains "$DOTFILES_DIR/home/bin/symlink_chezmoi-todo.tmpl" 'if \.modules\.todo\.enabled' "chezmoi-todo command follows module enablement"
assert_file_missing "$DOTFILES_DIR/modules/todo/bin/todo" "todo implementation is no longer duplicated in dotfiles"
assert_file_exists "$TMUX_YAZI_MODULE/module.yaml" "tmux-yazi module manifest is declared"
assert_file_exists "$TMUX_YAZI_MODULE/README.md" "tmux-yazi module documents its boundary"
assert_file_exists "$TMUX_YAZI_MODULE/tests/test_tmux_yazi_pane.sh" "tmux-yazi module owns its behavior test"
assert_contains "$TMUX_YAZI_MODULE/module.yaml" '^apiVersion: dotfiles/v1$' "tmux-yazi uses the dotfiles module contract"
assert_contains "$TMUX_YAZI_MODULE/module.yaml" 'standalone: true' "tmux-yazi declares standalone distribution"
assert_contains "$TMUX_YAZI_MODULE/module.yaml" 'libraries:' "tmux-yazi declares its public standard-library dependency"
assert_contains "$TMUX_YAZI_MODULE/module.yaml" 'preserved: \[\]' "tmux-yazi declares that it owns no persistent files"
assert_contains "$TMUX_YAZI_MODULE/module.yaml" 'tmux-pane-option:@dotfiles_yazi_side' "tmux-yazi declares its ephemeral pane marker"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-yazi-pane.tmpl" 'if \.modules\.tmuxYazi\.enabled' "tmux-yazi command follows module enablement"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-yazi-pane.tmpl" 'includeTemplate "../modules/tmux-yazi/bin/tmux-yazi-pane"' "tmux-yazi command is a thin chezmoi bridge"
assert_not_contains "$DOTFILES_DIR/home/bin/executable_tmux-yazi-pane.tmpl" '@dotfiles_yazi_side' "tmux-yazi bridge does not duplicate implementation"
assert_contains "$TMUX_YAZI_MODULE/bin/tmux-yazi-pane" 'source "[$]DOTFILES_LIB_DIR/[$]library"' "tmux-yazi consumes the public standard library"
assert_not_contains "$TMUX_YAZI_MODULE/bin/tmux-yazi-pane" '^tmux_cmd()' "tmux-yazi does not duplicate standard tmux routing"
assert_not_contains "$DOTFILES_DIR/install.sh" 'todo_dir\|touch.*todo\.txt' "Installer does not create a global task store"
assert_file_exists "$TMUX_WHICH_KEY_SOURCE" "tmux command-center YAML template is declared"
assert_file_exists "$TMUX_SESSIONS_MODULE/module.yaml" "tmux-sessions module manifest is declared"
assert_file_exists "$SESH_CONFIG" "tmux-sessions owns the sesh picker config"
assert_file_exists "$TMUX_SESSIONS_MODULE/layouts/project.tmux.tsx" "tmux-sessions owns the React-like project layout"
assert_file_exists "$TMUX_SESSIONS_MODULE/layouts/globals.d.ts" "tmux-sessions owns the layout editor globals"
assert_file_exists "$TMUX_SESSIONS_MODULE/layouts/tsconfig.json" "tmux-sessions owns the layout editor config"
assert_contains "$DOTFILES_DIR/home/dot_config/sesh/sesh.toml.tmpl" 'includeTemplate "../modules/tmux-sessions/config/sesh.toml"' "sesh config uses a thin tmux-sessions bridge"
assert_contains "$DOTFILES_DIR/home/dot_config/tmux/layouts/project.tmux.tsx.tmpl" 'includeTemplate "../modules/tmux-sessions/layouts/project.tmux.tsx"' "project layout uses a thin tmux-sessions bridge"
assert_contains "$DOTFILES_DIR/home/dot_config/tmux/layouts/globals.d.ts.tmpl" 'includeTemplate "../modules/tmux-sessions/layouts/globals.d.ts"' "layout globals use a thin tmux-sessions bridge"
assert_contains "$DOTFILES_DIR/home/dot_config/tmux/layouts/tsconfig.json.tmpl" 'includeTemplate "../modules/tmux-sessions/layouts/tsconfig.json"' "layout editor config uses a thin tmux-sessions bridge"
assert_contains "$DOTFILES_DIR/home/bin/executable_man-me" "parse_metadata_file" "man-me parses source metadata comments"
assert_contains "$DOTFILES_DIR/home/bin/executable_man-me" "SEARCH_QUERY" "man-me supports free-text query matching"
assert_contains "$DOTFILES_DIR/home/bin/executable_man-me" "rg -iq" "man-me uses ripgrep for matching when available"
assert_contains "$APP_FOCUS_MODULE/bin/hotkeys" "man-me: tags=.*hotkeys" "hotkeys command carries man-me search tags"
assert_contains "$SKHD_CONFIG_SOURCE" "man-me: name=skhdrc" "skhdrc carries man-me metadata"
assert_file_exists "$DOTFILES_DIR/modules/shortcut-guide/app/WhichKey.swift" "Shortcut guide module owns its Swift source"
assert_file_exists "$DOTFILES_DIR/scripts/build-whichkey.sh" "Shortcut guide build script is declared"
assert_contains "$DOTFILES_DIR/install.sh" "WHICHKEY_INSTALL_PATH=" "Installer builds the shortcut guide into the destination home"
assert_contains "$DOTFILES_DIR/install.sh" 'tmux source-file.*CHEZMOI_DESTINATION' "Installer reloads a running tmux server after apply"
assert_contains "$DOTFILES_DIR/install.sh" "pkill -USR2 -f '/Ghostty" "Installer reloads every running Ghostty process after apply"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-picker.tmpl" 'includeTemplate "../modules/tmux-sessions/bin/tmux-session-picker"' "Tmux-only helper uses a thin tmux-sessions bridge"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-sessionizer.tmpl" 'includeTemplate "../modules/tmux-sessions/bin/tmux-sessionizer"' "Tmux sessionizer uses a thin tmux-sessions bridge"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-sessionizer-zoxide.tmpl" 'includeTemplate "../modules/tmux-sessions/bin/tmux-sessionizer-zoxide"' "Zoxide sessionizer uses a thin tmux-sessions bridge"
assert_contains "$TMUX_SESSIONS_MODULE/bin/tmux-session-picker" 'exec sesh picker --icons --hide-duplicates --separator-aware --tmux' "Tmux-only helper uses sesh's built-in picker"
assert_contains "$TMUX_SESSIONS_MODULE/bin/tmux-sessionizer" 'exec sesh picker --icons --hide-duplicates --separator-aware' "Tmux sessionizer uses sesh's built-in picker"
assert_contains "$TMUX_SESSIONS_MODULE/bin/tmux-sessionizer-zoxide" 'exec sesh picker --icons --hide-duplicates --separator-aware' "Zoxide sessionizer uses sesh's built-in picker"
assert_not_contains "$TMUX_SESSIONS_MODULE/bin/tmux-session-picker" 'fzf --' "Tmux-only helper does not hand-roll an fzf picker"
assert_not_contains "$TMUX_SESSIONS_MODULE/bin/tmux-sessionizer" 'fzf --' "Tmux sessionizer does not hand-roll an fzf picker"
assert_not_contains "$TMUX_SESSIONS_MODULE/bin/tmux-sessionizer-zoxide" 'fzf --' "Zoxide sessionizer does not hand-roll an fzf picker"
assert_contains "$SESH_CONFIG" '^\[tui\]$' "Sesh config manages its picker UI"
assert_contains "$SESH_CONFIG" '^show_icons = true$' "Sesh picker enables source icons"
assert_contains "$SESH_CONFIG" '^strict_mode = true$' "Sesh rejects unknown managed configuration fields"
assert_not_contains "$SESH_CONFIG" '^\[default_session\]$' "Sesh config does not inject default layouts"
assert_not_contains "$SESH_CONFIG" '^\[\[window\]\]$' "Sesh config does not define mutable window templates"
assert_not_contains "$SESH_CONFIG" '^\[\[session\]\]$' "Sesh config does not define sessions that can mutate the caller"
assert_file_missing "$DOTFILES_DIR/home/dot_config/skhd/executable_whichkey" "Architecture-specific shortcut binary is not checked in"

echo ""
echo "Testing scratchpad implementation..."
assert_contains "$TERMINAL_WINDOW_TYPES_TMUX" "after-new-session\[50\].*tmux-session-template auto.*session_name" "Tmux config applies the standard template to ordinary new sessions"
assert_contains "$TMUX_CONFIG_SOURCE" 'includeTemplate "../modules/tmux-sessions/targets/tmux.conf.tmpl"' "tmux config uses the tmux-sessions contribution bridge"
assert_contains "$TMUX_WHICH_KEY_SOURCE" 'includeTemplate "../modules/tmux-sessions/targets/tmux-which-key-sessions.yaml.tmpl"' "tmux command center uses the tmux-sessions contribution bridge"
assert_contains "$TMUX_SESSIONS_TMUX" '^set-option -g detach-on-destroy off$' "Tmux remains usable when the current session is destroyed"
assert_contains "$TMUX_SESSIONS_TMUX" 'bind-key -N "Open sesh session picker" s display-popup.*tmux-sessionizer-zoxide' "Tmux config opens the built-in sesh picker"
assert_contains "$TMUX_SESSIONS_TMUX" 'bind-key -N "Switch to client-local last session" L switch-client -l' "Tmux config keeps last-session history local to each client"
assert_contains "$TMUX_SESSIONS_WHICH_KEY" 'command: switch-client -l' "Tmux command center keeps last-session history local to each client"
assert_contains "$TMUX_SESSIONS_TMUX" 'bind-key -N "New named session" N command-prompt.*new-session -A -s' "Tmux config exposes direct named-session creation"
assert_contains "$TMUX_SESSIONS_TMUX" "bind-key -N \"Rename session contextually\" '[$]' command-prompt.*rename-session" "Tmux config exposes direct session renaming"
assert_contains "$TMUX_SESSIONS_TMUX" 'Rename #S · #{b:pane_current_path}' "Tmux config shows active folder context while renaming a session"
assert_contains "$TMUX_SESSIONS_TMUX" '#{?#{m/r:' "Tmux config suggests folder names for numeric sessions"
assert_contains "$TMUX_SESSIONS_TMUX" 'command-prompt -F -l' "Tmux config treats contextual rename input literally"
assert_contains "$TMUX_SESSIONS_TMUX" 'rename-session -t "#{session_id}" -- "%%%"' "Tmux config safely forwards the full prompted session name"
assert_contains "$TMUX_SESSIONS_WHICH_KEY" 'name: Rename contextually' "Tmux command center exposes contextual session renaming"
assert_contains "$TMUX_SESSIONS_WHICH_KEY" 'command-prompt -l' "Tmux command center uses literal rename input"
assert_contains "$TMUX_SESSIONS_WHICH_KEY" 'rename-session -- "%%%"' "Tmux command center safely forwards contextual names"
assert_contains "$TMUX_SESSIONS_TMUX" 'bind-key -N "Close session" X confirm-before.*kill-session' "Tmux config confirms direct session closure"
assert_contains "$TERMINAL_WINDOW_TYPES_TMUX" 'bind-key -N "New terminal window" c run-shell.*tmux-session-template new' "Tmux config exposes direct terminal-window creation"
assert_contains "$TMUX_CONFIG_SOURCE" 'bind-key -N "Previous window" p previous-window' "Tmux config exposes direct previous-window selection"
assert_contains "$TMUX_CONFIG_SOURCE" 'bind-key -N "Next window" n next-window' "Tmux config exposes direct next-window selection"
assert_contains "$TMUX_CONFIG_SOURCE" 'bind-key -N "Close window".*&.*confirm-before.*kill-window' "Tmux config confirms direct window closure"
assert_contains "$TMUX_CONFIG_SOURCE" 'bind-key -N "Toggle pane zoom" z resize-pane -Z' "Tmux config exposes direct pane zoom"
assert_contains "$TERMINAL_WINDOW_TYPES_TMUX" "C-0.*tmux-session-template cycle.*terminal" "Ctrl+0 cycles terminal windows by type"
assert_contains "$TERMINAL_WINDOW_TYPES_TMUX" "C-1.*tmux-session-template cycle.*codex" "Ctrl+1 cycles Codex windows by type"
assert_contains "$TERMINAL_WINDOW_TYPES_TMUX" "C-2.*tmux-session-template cycle.*nvim" "Ctrl+2 cycles Neovim windows by type"
assert_contains "$TERMINAL_WINDOW_TYPES_TMUX" "C-3.*tmux-session-template cycle.*tuxedo" "Ctrl+3 cycles Tuxedo windows by type"
assert_contains "$TERMINAL_WINDOW_TYPES_TMUX" "C-S-0.*tmux-session-template new.*terminal" "Ctrl+Shift+0 creates a terminal window"
assert_contains "$TERMINAL_WINDOW_TYPES_TMUX" "C-S-1.*tmux-session-template new.*codex" "Ctrl+Shift+1 creates a Codex window"
assert_contains "$TERMINAL_WINDOW_TYPES_TMUX" "C-S-2.*tmux-session-template new.*nvim" "Ctrl+Shift+2 creates a Neovim window"
assert_contains "$TERMINAL_WINDOW_TYPES_TMUX" "C-S-3.*tmux-session-template new.*tuxedo" "Ctrl+Shift+3 creates a Tuxedo window"
assert_contains "$TERMINAL_WINDOW_TYPES_TMUX" 'S-F4.*tmux-session-template duplicate.*session_id.*pane_id' "Right Command duplicate reaches tmux through terminal F16"
assert_contains "$TMUX_CONFIG_SOURCE" 'S-F7.*show-wk-menu-root' "Right Command command-center action reaches tmux through terminal F19"
assert_contains "$TERMINAL_WINDOW_TYPES_WHICH_KEY_DUPLICATE" "tmux-session-template duplicate" "Tmux command center duplicates the current window"
assert_contains "$TERMINAL_WINDOW_TYPES_WHICH_KEY_CYCLE" "cycle.*tuxedo" "Tmux command center cycles Tuxedo windows"
assert_contains "$TERMINAL_WINDOW_TYPES_WHICH_KEY_NEW" "new.*tuxedo" "Tmux command center creates Tuxedo windows"
assert_contains "$TERMINAL_WINDOW_TYPES_WHICH_KEY_CYCLE" "cycle.*awrit" "Tmux command center cycles Awrit windows"
assert_contains "$TERMINAL_WINDOW_TYPES_WHICH_KEY_NEW" "new.*awrit" "Tmux command center creates Awrit windows"
assert_not_contains "$TERMINAL_WINDOW_TYPES_TMUX" "C-[0123] select-window" "Ctrl+0/1/2/3 are type selectors instead of fixed indices"
assert_contains "$TMUX_CONFIG_SOURCE" "C-4 select-window -t :4" "Ctrl+4 retains direct index switching"
assert_contains "$TMUX_CONFIG_SOURCE" 'includeTemplate "../modules/tmux-yazi/targets/tmux-resurrect-process.tmpl"' "Tmux persistence composes the tmux-yazi process contribution"
assert_contains "$TMUX_YAZI_MODULE/targets/tmux-resurrect-process.tmpl" '^yazi$' "tmux-yazi owns its persistence process"
assert_contains "$TERMINAL_WINDOW_TYPES_COMMAND" "pane_start_command" "Tmux template preserves command sessions"
assert_contains "$TERMINAL_WINDOW_TYPES_COMMAND" "DOTFILES_TMUX_TEMPLATE" "Tmux template supports an explicit opt-out"
assert_contains "$TERMINAL_WINDOW_TYPES_COMMAND" 'session.*!= hs-\*' "Tmux template preserves hs orchestrator sessions"
assert_contains "$TERMINAL_WINDOW_TYPES_COMMAND" "dotfiles_tmux_wait_lock_acquire" "Tmux template serializes concurrent layout creation"
assert_contains "$TERMINAL_WINDOW_TYPES_COMMAND" "WINDOW_TYPE_OPTION=.*dotfiles_window_type" "Tmux template persists window type metadata"
assert_contains "$TERMINAL_WINDOW_TYPES_COMMAND" "new-window -d -P" "Tmux template captures duplicate window IDs"
assert_contains "$TERMINAL_WINDOW_TYPES_COMMAND" "allows_legacy_index_migration" "Tmux template protects typed slots during upgrades"
assert_file_exists "$SCRATCHPADS_MODULE/module.yaml" "scratchpads module manifest is declared"
assert_file_exists "$SCRATCHPADS_COMMAND" "scratchpads module owns its CLI"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads.tmpl" 'includeTemplate "../modules/scratchpads/bin/scratchpads"' "scratchpads command uses a thin module bridge"
assert_contains "$DOTFILES_DIR/home/dot_config/skhd/executable_toggle_ghostty_quick_terminal.sh.tmpl" 'includeTemplate "../modules/scratchpads/bin/toggle_ghostty_quick_terminal.sh"' "quick-terminal helper uses a thin scratchpads bridge"
assert_not_contains "$SCRATCHPADS_COMMAND" 'SCRATCHPAD_STATE_FILE' "Scratchpads CLI does not use a JSON registry"
assert_not_contains "$SCRATCHPADS_COMMAND" 'scratchpads\.json' "Scratchpads CLI does not persist window IDs"
assert_contains "$SCRATCHPADS_COMMAND" "SCRATCHPAD_TERMINAL_LABEL" "Scratchpads CLI declares one terminal scratchpad label"
assert_contains "$SCRATCHPADS_COMMAND" "SCRATCHPAD_DOTFILES_TMUX_SESSION" "Scratchpads CLI declares the dotfiles tmux session"
assert_contains "$SCRATCHPADS_COMMAND" "SCRATCHPAD_PROJECTS_TMUX_SESSION" "Scratchpads CLI declares the projects tmux session"
assert_not_contains "$SCRATCHPADS_COMMAND" "SCRATCHPAD_TMUX_SESSION=" "Scratchpads CLI does not use one shared tmux session"
assert_contains "$SCRATCHPADS_COMMAND" "scratchpad_codex_dotfiles" "Scratchpads CLI removes the stale dotfiles scratchpad rule"
assert_contains "$SCRATCHPADS_COMMAND" "scratchpad_projects_tmux" "Scratchpads CLI removes the stale projects scratchpad rule"
assert_contains "$SCRATCHPADS_COMMAND" "print_rule_for_label.*SCRATCHPAD_TERMINAL_LABEL" "Scratchpads CLI creates one terminal scratchpad rule"
assert_contains "$SCRATCHPADS_COMMAND" "open_terminal_tmux_scratchpad.*dotfiles" "Codex scratchpad opens the terminal window on dotfiles"
assert_contains "$SCRATCHPADS_COMMAND" "open_terminal_tmux_scratchpad.*projects" "Projects scratchpad opens the terminal window on projects"
assert_contains "$SCRATCHPADS_COMMAND" "switch_terminal_scratchpad_client" "Scratchpads CLI switches the existing tmux client"
assert_contains "$SCRATCHPADS_COMMAND" "SCRATCHPAD_TMUX_CLIENT_OPTION" "Scratchpads CLI records the terminal tmux client"
assert_contains "$SCRATCHPADS_COMMAND" "infer_terminal_scratchpad_client" "Scratchpads CLI recovers a stale terminal tmux client"
assert_contains "$SCRATCHPADS_COMMAND" "client_session" "Scratchpads CLI infers the terminal client from scratchpad sessions"
assert_contains "$SCRATCHPADS_COMMAND" "attach_dotfiles_tmux_session" "Codex scratchpad attaches to the dotfiles tmux session"
assert_contains "$SCRATCHPADS_COMMAND" "attach_projects_tmux_session.*nvim" "Projects scratchpad can attach to the nvim tmux window"
assert_contains "$SCRATCHPADS_COMMAND" "close_scratchpads_except_label" "Scratchpads CLI closes other scratchpad windows"
assert_contains "$SCRATCHPADS_COMMAND" "close_duplicate_scratchpads_for_label" "Scratchpads CLI closes duplicate scratchpad windows"
assert_contains "$SCRATCHPADS_COMMAND" "SCRATCHPAD_PROJECTS_DIR" "Scratchpads CLI declares the projects root"
assert_contains "$SCRATCHPADS_COMMAND" "SCRATCHPAD_DOTFILES_DIR" "Scratchpads CLI declares the dotfiles root"
assert_contains "$SCRATCHPADS_COMMAND" "background=#000000" "Scratchpad Ghostty windows use a black background"
assert_contains "$SCRATCHPADS_COMMAND" "background-opacity=1" "Scratchpad Ghostty windows stay opaque"
assert_contains "$SCRATCHPADS_COMMAND" "background-blur=false" "Scratchpad Ghostty windows disable blur"
assert_contains "$SCRATCHPADS_COMMAND" "window-padding-x=12" "Scratchpad Ghostty windows add horizontal breathing room"
assert_contains "$SCRATCHPADS_COMMAND" "window-padding-y=10" "Scratchpad Ghostty windows add vertical breathing room"
assert_contains "$SCRATCHPADS_COMMAND" "window-padding-balance=true" "Scratchpad Ghostty windows balance terminal padding"
assert_contains "$SCRATCHPADS_COMMAND" "resize-overlay=never" "Scratchpad Ghostty windows hide resize telemetry"
assert_contains "$SCRATCHPADS_COMMAND" "window-save-state=never" "Scratchpad geometry remains owned by yabai"
assert_contains "$SCRATCHPADS_COMMAND" "quit-after-last-window-closed=true" "Scratchpad Ghostty processes quit with their window"
assert_contains "$SCRATCHPADS_COMMAND" 'env -u ZDOTDIR -u TMUX -u TMUX_PANE' "Scratchpads do not inherit a stale tmux client environment"
assert_contains "$SCRATCHPADS_COMMAND" "acquire_scratchpad_open_lock" "Scratchpad hotkeys serialize concurrent launches"
assert_contains "$SCRATCHPADS_COMMAND" "close_duplicate_scratchpad_title_windows" "Scratchpads remove unlabeled same-title launch-race windows"
assert_contains "$SCRATCHPADS_COMMAND" 'visible_ids=$(scratchpad_visible_ids' "Visible same-target scratchpads close without requiring focus"
assert_contains "$SCRATCHPADS_COMMAND" "suppress-scratchpads" "Scratchpads suppress only their exact JankyBorders window"
assert_contains "$SCRATCHPADS_COMMAND" 'has-shadow' "Scratchpads inspect their native shadow state"
assert_contains "$SCRATCHPADS_COMMAND" 'toggle shadow' "Scratchpads enable a native shadow for visual separation"
assert_contains "$TMUX_BORDER_ACCENT_COMMAND" 'apply-to=' "JankyBorders supports exact scratchpad window overrides"
assert_contains "$TMUX_BORDER_ACCENT_COMMAND" 'scratchpad_window_ids' "Border helper discovers existing yabai scratchpads"
assert_contains "$TMUX_BORDER_ACCENT_COMMAND" 'active_color=\$TRANSPARENT_COLOR' "Border helper keeps scratchpad overrides transparent"
assert_contains "$TMUX_BORDER_ACCENT_COMMAND" 'SUPPRESS_ATTEMPTS' "Border helper retries scratchpad overrides during JankyBorders startup"
assert_contains "$SCRATCHPADS_COMMAND" "tmux new-session -d -e DOTFILES_TMUX_TEMPLATE=skip.*-n terminal" "Scratchpad tmux sessions opt out while creating their raw terminal"
assert_contains "$SCRATCHPADS_COMMAND" "ensure_standard_scratchpad_tmux_windows" "Scratchpad tmux sessions keep standard windows"
assert_contains "$SCRATCHPADS_COMMAND" "tmux-session-template.*ensure" "Scratchpad tmux sessions reuse the default template"
assert_contains "$TERMINAL_WINDOW_TYPES_COMMAND" "ensure_standard_tmux_window.*terminal 0" "Tmux template keeps terminal at window 0"
assert_contains "$TERMINAL_WINDOW_TYPES_COMMAND" "ensure_standard_tmux_window.*codex 1 codex" "Tmux template starts Codex at window 1"
assert_contains "$TERMINAL_WINDOW_TYPES_COMMAND" "ensure_standard_tmux_window.*nvim 2 nvim" "Tmux template starts Neovim at window 2"
assert_contains "$TERMINAL_WINDOW_TYPES_COMMAND" "ensure_standard_tmux_window.*tuxedo 3 todo" "Tmux template starts Tuxedo through the canonical todo wrapper at window 3"
assert_contains "$TERMINAL_WINDOW_TYPES_COMMAND" 'ensure_standard_tmux_window.*awrit 4 ""' "Tmux template keeps a lazy canonical Awrit slot at window 4"
assert_contains "$TERMINAL_WINDOW_TYPES_COMMAND" "awrit) printf 'awrit" "Explicit Awrit windows launch the installed command"
assert_file_exists "$APP_FOCUS_MODULE/bin/app-mru.sh" "app-mru helper is declared"
assert_contains "$APP_FOCUS_MODULE/bin/focus_app.sh" 'app-mru.sh' "App focus helper uses MRU stacks"
assert_contains "$APP_FOCUS_MODULE/bin/focus_app.sh" 'app_mru_cycle' "App focus helper cycles by MRU"
assert_contains "$APP_FOCUS_MODULE/bin/focus_app.sh" 'hotkeys terminal new' "Ghostty app focus creates a normal terminal fallback"
assert_contains "$APP_FOCUS_MODULE/bin/focus_app.sh" 'EDITOR_APP:-.*VSCodium' "Editor app focus defaults to VSCodium"
assert_not_contains "$APP_FOCUS_MODULE/bin/focus_app.sh" 'focus recent' "App focus helper does not jump to unrelated windows"
assert_not_contains "$APP_FOCUS_MODULE/bin/app-mru.sh" 'focus recent' "App MRU helper stays within app windows"
assert_contains "$APP_FOCUS_MODULE/bin/app-mru.sh" 'app_mru_id_in_list' "App MRU validates saved IDs against eligible windows"
assert_file_exists "$CREATE_SPACE_COMMAND" "Create-space helper is declared"
assert_file_exists "$CREATE_SPACE_BRIDGE" "Create-space helper bridge is declared"
assert_contains "$CREATE_SPACE_BRIDGE" 'includeTemplate "../modules/space-display/bin/create-space"' "Create-space helper uses a thin module bridge"
assert_contains "$CREATE_SPACE_COMMAND" "before_uuids" "Create-space helper identifies the new space by UUID"
assert_contains "$CREATE_SPACE_COMMAND" "auto|focus|move-window" "Create-space helper supports automatic move-or-focus mode"
assert_contains "$CREATE_SPACE_COMMAND" "scratchpad_label" "Create-space helper ignores focused scratchpad windows"
assert_contains "$CREATE_SPACE_COMMAND" "movable_windows.*-gt 1" "Create-space auto mode leaves a space's only normal window in place"
assert_contains "$CREATE_SPACE_COMMAND" "capture_focused_window_for_move true" "Create-space auto mode only moves when another normal window remains"
assert_contains "$CREATE_SPACE_COMMAND" "capture_focused_window_for_move false" "Create-space explicit move mode does not require another normal window"
assert_not_contains "$CREATE_SPACE_COMMAND" "YABAI_SPACE_WALLPAPER" "Create-space helper does not expose wallpaper assignment knobs"
assert_not_contains "$CREATE_SPACE_COMMAND" "set picture of current desktop" "Create-space helper does not change wallpapers"
assert_file_exists "$TILE_PIP_WINDOW_COMMAND" "PiP tiling helper is declared"
assert_file_exists "$TILE_PIP_WINDOW_BRIDGE" "PiP tiling helper bridge is declared"
assert_contains "$TILE_PIP_WINDOW_BRIDGE" 'includeTemplate "../modules/appearance-pip/bin/tile-pip-window"' "PiP tiling helper uses a thin module bridge"
assert_contains "$TILE_PIP_WINDOW_COMMAND" "toggle float" "PiP tiling helper inserts PiP into the tree"
assert_contains "$TILE_PIP_WINDOW_COMMAND" "YABAI_WINDOW_ID" "PiP tiling helper accepts yabai signal window IDs"
assert_not_contains "$SCRATCHPADS_COMMAND" 'SPOTLIGHT_SHELL' "Scratchpads CLI does not load hyperspace shell"
assert_file_exists "$HYPERSPACE_MODULE/module.yaml" "Hyperspace module manifest stays parked"
assert_file_exists "$HYPERSPACE_MODULE/targets/hyperspace.skhdrc" "Hyperspace module keeps its parked skhd bindings"
assert_file_exists "$HYPERSPACE_MODULE/bin/spotlight-zsh" "Hyperspace module keeps spotlight shell wrapper"
assert_file_exists "$HYPERSPACE_MODULE/config/zshrc" "Hyperspace module keeps spotlight zshrc"
assert_file_exists "$HYPERSPACE_MODULE/bin/hyperspace" "Hyperspace module keeps hyperspace CLI"
assert_file_exists "$HYPERSPACE_MODULE/bin/open-spotlight-scratchpad" "Hyperspace module keeps spotlight scratchpad launcher"
assert_contains "$DOTFILES_DIR/home/dot_config/skhd/modules/hyperspace.skhdrc.tmpl" 'includeTemplate "../modules/hyperspace/targets/hyperspace.skhdrc"' "Hyperspace skhd bindings use a thin module bridge"
assert_contains "$DOTFILES_DIR/home/dot_config/skhd/modules/hyperspace/executable_spotlight-zsh.tmpl" 'includeTemplate "../modules/hyperspace/bin/spotlight-zsh"' "Hyperspace shell wrapper uses a thin module bridge"
assert_contains "$DOTFILES_DIR/home/dot_config/skhd/modules/hyperspace/dot_zshrc.tmpl" 'includeTemplate "../modules/hyperspace/config/zshrc"' "Hyperspace zshrc uses a thin module bridge"
assert_contains "$DOTFILES_DIR/home/dot_config/skhd/modules/hyperspace/executable_hyperspace.tmpl" 'includeTemplate "../modules/hyperspace/bin/hyperspace"' "Hyperspace CLI uses a thin module bridge"
assert_contains "$DOTFILES_DIR/home/dot_config/skhd/modules/hyperspace/executable_open_spotlight_scratchpad.tmpl" 'includeTemplate "../modules/hyperspace/bin/open-spotlight-scratchpad"' "Hyperspace scratchpad launcher uses a thin module bridge"
assert_contains "$SCRATCHPADS_QUICK_TERMINAL" "background-opacity=1" "Quick terminal scratchpad keeps Ghostty opaque"
assert_contains "$HYPERSPACE_MODULE/bin/open-spotlight-scratchpad" "background-opacity=1" "Spotlight scratchpad keeps Ghostty opaque"

echo ""
echo "Testing extension declarations..."
assert_contains "$DOTFILES_DIR/home/.chezmoidata.toml" "vscodeExtensions" "VSCodium extensions are declared"
assert_contains "$DOTFILES_DIR/home/.chezmoidata.toml" "jeanp413.open-remote-ssh" "VSCodium remote SSH extension is declared"
assert_not_contains "$DOTFILES_DIR/home/.chezmoidata.toml" "anysphere." "Cursor-only extensions are not declared"
assert_contains "$DOTFILES_DIR/home/.chezmoidata.toml" "name = \"gemma-gem\"" "Chrome extension is declared"
assert_contains "$DOTFILES_DIR/home/.chezmoidata.toml" "buildCommand = \"pnpm build\"" "Chrome extension is built from source"
assert_contains "$DOTFILES_DIR/home/.chezmoidata.toml" "\\[\\[externalProjects\\]\\]" "External projects are declared"
assert_contains "$DOTFILES_DIR/home/.chezmoidata.toml" "name = \"raycast-lucide-excalidraw\"" "Lucide Raycast project is declared"
assert_contains "$DOTFILES_DIR/home/.chezmoidata.toml" "npm --prefix projects/excalidraw-library run generate" "External project setup is declared"
for project in kittentts-cli tuxedo-project-todo gh-create-repo macos-default-apps unescape-cli; do
    assert_contains "$DOTFILES_DIR/home/.chezmoidata.toml" "name = \"$project\"" "$project is declared as a chezmoi external project"
    assert_contains "$DOTFILES_DIR/modules/dependencies/config/sources.toml" "id = \"$project\"" "$project is surfaced through the centralized dependency inventory"
done
assert_contains "$DOTFILES_DIR/home/.chezmoidata.toml" 'revision = "f6142dcc697e3c8c760855dd4af2a22bfd1161a7"' "kittentts-cli bootstrap is pinned to its tested release"
assert_contains "$DOTFILES_DIR/home/.chezmoidata.toml" 'revision = "11928c7c05b2dd9faab57466b2d0ee0739461268"' "tuxedo-project-todo bootstrap is pinned to its tested release"
assert_contains "$DOTFILES_DIR/home/.chezmoidata.toml" 'revision = "ad85879fe7d91e10362da14f6d3f69840bce478d"' "gh-create-repo bootstrap is pinned to its tested release"
assert_contains "$DOTFILES_DIR/home/.chezmoidata.toml" 'revision = "d74118ca4802f75c17d991fb11128aad3fc39b14"' "macos-default-apps bootstrap is pinned to its tested release"
assert_contains "$DOTFILES_DIR/home/.chezmoidata.toml" 'revision = "c6e028f7fa219a6a506f4e2cca4c62b8a6760e0f"' "unescape-cli bootstrap is pinned to its tested release"
assert_contains "$DOTFILES_DIR/home/.chezmoiexternal.toml.tmpl" "type = \"git-repo\"" "Extension repositories use chezmoi externals"
assert_contains "$DOTFILES_DIR/home/.chezmoiexternal.toml.tmpl" "externalProjects" "External projects use chezmoi externals"
assert_file_exists "$DOTFILES_DIR/home/.chezmoiscripts/run_onchange_after_install-vscodium-extensions.sh.tmpl" "VSCodium install hook exists"
assert_file_exists "$DOTFILES_DIR/home/.chezmoiscripts/run_once_install-vscodium-cli.sh.tmpl" "VSCodium CLI install hook exists"
assert_file_exists "$DOTFILES_DIR/home/Library/Application Support/VSCodium/User/settings.json" "VSCodium settings are managed"
assert_file_exists "$DOTFILES_DIR/home/.chezmoiscripts/run_after_sync-chrome-extensions.sh.tmpl" "Chrome build hook exists"
assert_file_exists "$DOTFILES_DIR/home/.chezmoiscripts/run_after_sync-external-projects.sh.tmpl" "External project setup hook exists"
assert_file_exists "$DOTFILES_DIR/home/.chezmoiscripts/run_after_sync-yazi-packages.sh.tmpl" "Yazi package sync hook exists"

echo ""
echo "Testing chezmoi parsing..."
if command -v chezmoi >/dev/null 2>&1; then
    if chezmoi -S "$DOTFILES_DIR" -D "$TEMP_HOME" --persistent-state "$TEMP_HOME/state.db" -n apply --exclude=scripts,externals >/dev/null; then
        echo "  ✓ chezmoi parses the source state"
        ((PASSED++))
    else
        echo "  ✗ chezmoi failed to parse the source state"
        ((FAILED++))
    fi
else
    echo "  ⚠ chezmoi is not installed; skipping parse check"
fi

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

exit $FAILED
