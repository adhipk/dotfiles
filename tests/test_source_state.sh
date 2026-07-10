#!/usr/bin/env bash

# Test suite for chezmoi source-state layout

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(dirname "$TEST_DIR")"
TEMP_HOME="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-source-state-test.XXXXXX")"

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
    dot_skhdrc \
    dot_yabairc \
    dot_tmux.conf \
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
assert_file_exists "$DOTFILES_DIR/home/dot_agents/AGENTS.md" "shared agent guidance is declared"
assert_file_exists "$DOTFILES_DIR/home/dot_codex/symlink_AGENTS.md.tmpl" "Codex global guidance link is declared"
assert_file_exists "$DOTFILES_DIR/home/dot_claude/symlink_CLAUDE.md.tmpl" "Claude global guidance link is declared"
assert_file_exists "$DOTFILES_DIR/home/dot_config/opencode/symlink_AGENTS.md.tmpl" "OpenCode global guidance link is declared"
assert_file_exists "$DOTFILES_DIR/home/dot_config/opencode/opencode.json" "OpenCode agent configuration is declared"
assert_contains "$DOTFILES_DIR/home/dot_agents/AGENTS.md" '## Canonical Task Tracking' "shared agent guidance declares canonical task tracking"
assert_contains "$DOTFILES_DIR/home/dot_agents/AGENTS.md" 'todo ls --json' "shared agent guidance requires canonical task inspection"
assert_contains "$DOTFILES_DIR/home/dot_agents/AGENTS.md" 'current project or tmux session working directory' "shared agent guidance keeps tasks beside the active work"
assert_contains "$DOTFILES_DIR/home/dot_agents/AGENTS.md" 'same working directory as the session' "shared agent guidance keeps tmux apps in the session cwd"
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
assert_contains "$DOTFILES_DIR/install.sh" 'expected_revision="85fb9756447b989f3b94e515d1e6ee7fec76cba2"' "installer pins the tested tmux-which-key revision"
assert_contains "$DOTFILES_DIR/install.sh" 'ln -sfn.*managed_config.*plugin_dir/config.yaml' "installer avoids tmux-which-key's GNU-only XDG path"
assert_contains "$DOTFILES_DIR/install.sh" 'mkdir -p.*projects' "installer creates the projects scratchpad root"
assert_contains "$DOTFILES_DIR/bootstrap.sh" 'start_desktop_service yabai' "bootstrap starts the yabai launch service"
assert_contains "$DOTFILES_DIR/bootstrap.sh" 'start_desktop_service skhd' "bootstrap starts the skhd launch service"
assert_contains "$DOTFILES_DIR/bootstrap.sh" 'setup-yabai-sa' "bootstrap documents the required yabai scripting-addition step"
assert_contains "$DOTFILES_DIR/bootstrap.sh" 'DriverKit extension and Input Monitoring' "bootstrap documents Karabiner's first-run approvals"
assert_contains "$DOTFILES_DIR/home/bin/executable_setup-yabai-sa" 'sha256:.*--load-sa' "yabai setup scopes sudoers access to the installed binary checksum"
assert_contains "$DOTFILES_DIR/home/bin/executable_setup-yabai-sa" 'visudo -cf' "yabai setup validates its sudoers file"
assert_contains "$DOTFILES_DIR/scripts/build-projectdeck.sh" 'command -v swiftc' "ProjectDeck build reports a missing Swift toolchain clearly"

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
GHOSTTY_CONFIG="$DOTFILES_DIR/home/Library/Application Support/com.mitchellh.ghostty/config"
GHOSTTY_AUTO_THEME="$DOTFILES_DIR/home/Library/Application Support/com.mitchellh.ghostty/auto/theme.ghostty"
SESH_CONFIG="$DOTFILES_DIR/home/dot_config/sesh/sesh.toml"
assert_file_exists "$GHOSTTY_CONFIG" "Ghostty config is managed"
assert_file_exists "$GHOSTTY_AUTO_THEME" "Ghostty auto theme override is managed"
assert_contains "$GHOSTTY_CONFIG" "theme = Cyberpunk Scarlet Protocol" "Ghostty uses Cyberpunk Scarlet Protocol"
assert_not_contains "$GHOSTTY_AUTO_THEME" "^theme[[:space:]]*=" "Ghostty auto theme override is disabled"
assert_contains "$GHOSTTY_CONFIG" "background-opacity = 0.86" "Ghostty normal terminal background is transparent"
assert_contains "$GHOSTTY_CONFIG" "background-blur = false" "Ghostty background blur is disabled"
assert_contains "$GHOSTTY_CONFIG" "keybind = cmd+backquote=csi:48;5u" "Ghostty maps Cmd+Backtick to terminal type cycling"
assert_contains "$GHOSTTY_CONFIG" "keybind = cmd+digit_1=csi:49;5u" "Ghostty maps Cmd+1 to Codex type cycling"
assert_contains "$GHOSTTY_CONFIG" "keybind = cmd+1=csi:49;5u" "Ghostty includes the Cmd+1 key-name fallback"
assert_contains "$GHOSTTY_CONFIG" "keybind = cmd+digit_2=csi:50;5u" "Ghostty maps Cmd+2 to Neovim type cycling"
assert_contains "$GHOSTTY_CONFIG" "keybind = cmd+2=csi:50;5u" "Ghostty includes the Cmd+2 key-name fallback"
assert_contains "$GHOSTTY_CONFIG" "keybind = cmd+digit_3=csi:51;5u" "Ghostty maps Cmd+3 to Tuxedo type cycling"
assert_contains "$GHOSTTY_CONFIG" "keybind = cmd+3=csi:51;5u" "Ghostty includes the Cmd+3 key-name fallback"
assert_contains "$GHOSTTY_CONFIG" "keybind = cmd+b=text:\\\\x01\\\\x62" "Ghostty maps Cmd+B to the Yazi side pane"
assert_contains "$GHOSTTY_CONFIG" "keybind = cmd+shift+b=text:\\\\x01\\\\x42" "Ghostty maps Cmd+Shift+B to the Yazi window"
assert_not_contains "$GHOSTTY_CONFIG" '^keybind = ctrl+alt+cmd' "Ghostty reserves Hyper"
assert_not_contains "$GHOSTTY_CONFIG" "cmd+backquote=text:\\\\x01" "Ghostty Cmd cycling does not select a fixed index"
assert_contains "$GHOSTTY_CONFIG" "ctrl+shift+digit_0=csi:48;6u" "Ghostty distinguishes Ctrl+Shift+0 for tmux"
assert_contains "$GHOSTTY_CONFIG" "ctrl+shift+digit_1=csi:49;6u" "Ghostty distinguishes Ctrl+Shift+1 for tmux"
assert_contains "$GHOSTTY_CONFIG" "ctrl+shift+digit_2=csi:50;6u" "Ghostty distinguishes Ctrl+Shift+2 for tmux"
assert_contains "$GHOSTTY_CONFIG" "ctrl+shift+digit_3=csi:51;6u" "Ghostty distinguishes Ctrl+Shift+3 for tmux"

echo ""
echo "Testing managed helper commands..."
for file in \
    executable_watch-sync \
    executable_ghostty-startup-bench \
    executable_lucide-icons-excalidraw.tmpl \
    executable_gh-create-repo \
    executable_man-me \
    executable_reload-colors \
    executable_setup-yabai-sa \
    executable_hotkeys \
    executable_scratchpads \
    executable_todo \
    executable_tmux-border-accent \
    executable_tmux-session-template \
    executable_tmux-workspace \
    executable_tmux-yazi-pane \
    symlink_default-apps.tmpl \
    executable_projects \
    executable_tmux-session-picker \
    executable_tmux-sessionizer \
    executable_tmux-sessionizer-zoxide \
    executable_unescape-buffer \
    executable_unescape-string; do
    assert_file_exists "$DOTFILES_DIR/home/bin/$file" "$file is declared"
done
assert_file_missing "$DOTFILES_DIR/home/dot_todo" "Mutable todo.txt data is not managed by chezmoi"
assert_not_contains "$DOTFILES_DIR/home/dot_zshrc" '^export TODO_\|^export DONE_FILE' "Shell does not pin Tuxedo to a global task directory"
assert_contains "$DOTFILES_DIR/home/bin/executable_todo" 'TODO_DIR="[$]PWD"' "todo wrapper pins tasks to the current working directory"
assert_contains "$DOTFILES_DIR/home/bin/executable_todo" 'TODO_AGENT_LOCK=' "todo wrapper serializes agent operations"
assert_contains "$DOTFILES_DIR/home/bin/executable_todo" '^[[:space:]]*exec tuxedo$' "todo wrapper lets interactive Tuxedo inherit the current directory"
assert_not_contains "$DOTFILES_DIR/install.sh" 'todo_dir\|touch.*todo\.txt' "Installer does not create a global task store"
assert_file_exists "$DOTFILES_DIR/home/dot_config/tmux/which-key.yaml" "tmux command-center YAML is declared"
assert_file_exists "$SESH_CONFIG" "sesh picker config is declared"
assert_file_exists "$DOTFILES_DIR/home/dot_config/tmux/layouts/project.tmux.tsx" "React-like tmux project layout is declared"
assert_file_exists "$DOTFILES_DIR/home/dot_config/tmux/layouts/globals.d.ts" "tmux layout editor globals are declared"
assert_file_exists "$DOTFILES_DIR/home/dot_config/tmux/layouts/tsconfig.json" "tmux layout editor config is declared"
assert_contains "$DOTFILES_DIR/home/bin/executable_man-me" "parse_metadata_file" "man-me parses source metadata comments"
assert_contains "$DOTFILES_DIR/home/bin/executable_man-me" "SEARCH_QUERY" "man-me supports free-text query matching"
assert_contains "$DOTFILES_DIR/home/bin/executable_man-me" "rg -iq" "man-me uses ripgrep for matching when available"
assert_contains "$DOTFILES_DIR/home/bin/executable_hotkeys" "man-me: tags=.*hotkeys" "hotkeys command carries man-me search tags"
assert_contains "$DOTFILES_DIR/home/dot_skhdrc" "man-me: name=skhdrc" "skhdrc carries man-me metadata"
assert_file_exists "$DOTFILES_DIR/scripts/whichkey/WhichKey.swift" "Shortcut guide Swift source is declared"
assert_file_exists "$DOTFILES_DIR/scripts/build-whichkey.sh" "Shortcut guide build script is declared"
assert_contains "$DOTFILES_DIR/install.sh" "WHICHKEY_INSTALL_PATH=" "Installer builds the shortcut guide into the destination home"
assert_contains "$DOTFILES_DIR/install.sh" 'tmux source-file.*CHEZMOI_DESTINATION' "Installer reloads a running tmux server after apply"
assert_contains "$DOTFILES_DIR/install.sh" "pkill -USR2 -f '/Ghostty" "Installer reloads every running Ghostty process after apply"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-picker" 'exec sesh picker --icons --hide-duplicates --separator-aware --tmux' "Tmux-only helper uses sesh's built-in picker"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-sessionizer" 'exec sesh picker --icons --hide-duplicates --separator-aware' "Tmux sessionizer uses sesh's built-in picker"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-sessionizer-zoxide" 'exec sesh picker --icons --hide-duplicates --separator-aware' "Zoxide sessionizer uses sesh's built-in picker"
assert_not_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-picker" 'fzf --' "Tmux-only helper does not hand-roll an fzf picker"
assert_not_contains "$DOTFILES_DIR/home/bin/executable_tmux-sessionizer" 'fzf --' "Tmux sessionizer does not hand-roll an fzf picker"
assert_not_contains "$DOTFILES_DIR/home/bin/executable_tmux-sessionizer-zoxide" 'fzf --' "Zoxide sessionizer does not hand-roll an fzf picker"
assert_contains "$SESH_CONFIG" '^\[tui\]$' "Sesh config manages its picker UI"
assert_contains "$SESH_CONFIG" '^show_icons = true$' "Sesh picker enables source icons"
assert_contains "$SESH_CONFIG" '^strict_mode = true$' "Sesh rejects unknown managed configuration fields"
assert_not_contains "$SESH_CONFIG" '^\[default_session\]$' "Sesh config does not inject default layouts"
assert_not_contains "$SESH_CONFIG" '^\[\[window\]\]$' "Sesh config does not define mutable window templates"
assert_not_contains "$SESH_CONFIG" '^\[\[session\]\]$' "Sesh config does not define sessions that can mutate the caller"
assert_file_missing "$DOTFILES_DIR/home/dot_config/skhd/executable_whichkey" "Architecture-specific shortcut binary is not checked in"

echo ""
echo "Testing scratchpad implementation..."
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" "after-new-session\[50\].*tmux-session-template auto.*session_name" "Tmux config applies the standard template to ordinary new sessions"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" '^set-option -g detach-on-destroy off$' "Tmux remains usable when the current session is destroyed"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" 'bind-key -N "Open sesh session picker" s display-popup.*tmux-sessionizer-zoxide' "Tmux config opens the built-in sesh picker"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" 'bind-key -N "Switch to client-local last session" L switch-client -l' "Tmux config keeps last-session history local to each client"
assert_contains "$DOTFILES_DIR/home/dot_config/tmux/which-key.yaml" 'command: switch-client -l' "Tmux command center keeps last-session history local to each client"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" 'bind-key -N "New named session" N command-prompt.*new-session -A -s' "Tmux config exposes direct named-session creation"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" "bind-key -N \"Rename session contextually\" '[$]' command-prompt.*rename-session" "Tmux config exposes direct session renaming"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" 'Rename #S · #{b:pane_current_path}' "Tmux config shows active folder context while renaming a session"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" '#{?#{m/r:' "Tmux config suggests folder names for numeric sessions"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" 'command-prompt -F -l' "Tmux config treats contextual rename input literally"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" 'rename-session -t "#{session_id}" -- "%%%"' "Tmux config safely forwards the full prompted session name"
assert_contains "$DOTFILES_DIR/home/dot_config/tmux/which-key.yaml" 'name: Rename contextually' "Tmux command center exposes contextual session renaming"
assert_contains "$DOTFILES_DIR/home/dot_config/tmux/which-key.yaml" 'command-prompt -l' "Tmux command center uses literal rename input"
assert_contains "$DOTFILES_DIR/home/dot_config/tmux/which-key.yaml" 'rename-session -- "%%%"' "Tmux command center safely forwards contextual names"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" 'bind-key -N "Close session" X confirm-before.*kill-session' "Tmux config confirms direct session closure"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" 'bind-key -N "New terminal window" c run-shell.*tmux-session-template new' "Tmux config exposes direct terminal-window creation"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" 'bind-key -N "Previous window" p previous-window' "Tmux config exposes direct previous-window selection"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" 'bind-key -N "Next window" n next-window' "Tmux config exposes direct next-window selection"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" 'bind-key -N "Close window".*&.*confirm-before.*kill-window' "Tmux config confirms direct window closure"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" 'bind-key -N "Toggle pane zoom" z resize-pane -Z' "Tmux config exposes direct pane zoom"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" "C-0.*tmux-session-template cycle.*terminal" "Ctrl+0 cycles terminal windows by type"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" "C-1.*tmux-session-template cycle.*codex" "Ctrl+1 cycles Codex windows by type"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" "C-2.*tmux-session-template cycle.*nvim" "Ctrl+2 cycles Neovim windows by type"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" "C-3.*tmux-session-template cycle.*tuxedo" "Ctrl+3 cycles Tuxedo windows by type"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" "C-S-0.*tmux-session-template new.*terminal" "Ctrl+Shift+0 creates a terminal window"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" "C-S-1.*tmux-session-template new.*codex" "Ctrl+Shift+1 creates a Codex window"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" "C-S-2.*tmux-session-template new.*nvim" "Ctrl+Shift+2 creates a Neovim window"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" "C-S-3.*tmux-session-template new.*tuxedo" "Ctrl+Shift+3 creates a Tuxedo window"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" 'S-F4.*tmux-session-template duplicate.*session_id.*pane_id' "Right Command duplicate reaches tmux through terminal F16"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" 'S-F7.*show-wk-menu-root' "Right Command command-center action reaches tmux through terminal F19"
assert_contains "$DOTFILES_DIR/home/dot_config/tmux/which-key.yaml" "tmux-session-template duplicate" "Tmux command center duplicates the current window"
assert_contains "$DOTFILES_DIR/home/dot_config/tmux/which-key.yaml" "cycle.*tuxedo" "Tmux command center cycles Tuxedo windows"
assert_contains "$DOTFILES_DIR/home/dot_config/tmux/which-key.yaml" "new.*tuxedo" "Tmux command center creates Tuxedo windows"
assert_not_contains "$DOTFILES_DIR/home/dot_tmux.conf" "C-[0123] select-window" "Ctrl+0/1/2/3 are type selectors instead of fixed indices"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" "C-4 select-window -t :4" "Ctrl+4 retains direct index switching"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" "@resurrect-processes 'codex tuxedo yazi'" "Tmux persistence restores Tuxedo"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template" "pane_start_command" "Tmux template preserves command sessions"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template" "DOTFILES_TMUX_TEMPLATE" "Tmux template supports an explicit opt-out"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template" 'session.*!= hs-\*' "Tmux template preserves hs orchestrator sessions"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template" "wait-for -L" "Tmux template serializes concurrent layout creation"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template" "WINDOW_TYPE_OPTION=.*dotfiles_window_type" "Tmux template persists window type metadata"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template" "new-window -d -P" "Tmux template captures duplicate window IDs"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template" "allows_legacy_index_migration" "Tmux template protects the new Tuxedo slot during upgrades"
assert_not_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" 'SCRATCHPAD_STATE_FILE' "Scratchpads CLI does not use a JSON registry"
assert_not_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" 'scratchpads\.json' "Scratchpads CLI does not persist window IDs"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "SCRATCHPAD_TERMINAL_LABEL" "Scratchpads CLI declares one terminal scratchpad label"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "SCRATCHPAD_DOTFILES_TMUX_SESSION" "Scratchpads CLI declares the dotfiles tmux session"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "SCRATCHPAD_PROJECTS_TMUX_SESSION" "Scratchpads CLI declares the projects tmux session"
assert_not_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "SCRATCHPAD_TMUX_SESSION=" "Scratchpads CLI does not use one shared tmux session"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "scratchpad_codex_dotfiles" "Scratchpads CLI removes the stale dotfiles scratchpad rule"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "scratchpad_projects_tmux" "Scratchpads CLI removes the stale projects scratchpad rule"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "print_rule_for_label.*SCRATCHPAD_TERMINAL_LABEL" "Scratchpads CLI creates one terminal scratchpad rule"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "open_terminal_tmux_scratchpad.*dotfiles" "Codex scratchpad opens the terminal window on dotfiles"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "open_terminal_tmux_scratchpad.*projects" "Projects scratchpad opens the terminal window on projects"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "switch_terminal_scratchpad_client" "Scratchpads CLI switches the existing tmux client"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "SCRATCHPAD_TMUX_CLIENT_OPTION" "Scratchpads CLI records the terminal tmux client"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "infer_terminal_scratchpad_client" "Scratchpads CLI recovers a stale terminal tmux client"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "client_session" "Scratchpads CLI infers the terminal client from scratchpad sessions"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "attach_dotfiles_tmux_session" "Codex scratchpad attaches to the dotfiles tmux session"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "attach_projects_tmux_session.*nvim" "Projects scratchpad can attach to the nvim tmux window"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "close_scratchpads_except_label" "Scratchpads CLI closes other scratchpad windows"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "close_duplicate_scratchpads_for_label" "Scratchpads CLI closes duplicate scratchpad windows"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "SCRATCHPAD_PROJECTS_DIR" "Scratchpads CLI declares the projects root"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "SCRATCHPAD_DOTFILES_DIR" "Scratchpads CLI declares the dotfiles root"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "background=#000000" "Scratchpad Ghostty windows use a black background"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "background-opacity=1" "Scratchpad Ghostty windows stay opaque"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "background-blur=false" "Scratchpad Ghostty windows disable blur"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "window-padding-x=12" "Scratchpad Ghostty windows add horizontal breathing room"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "window-padding-y=10" "Scratchpad Ghostty windows add vertical breathing room"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "window-padding-balance=true" "Scratchpad Ghostty windows balance terminal padding"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "resize-overlay=never" "Scratchpad Ghostty windows hide resize telemetry"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "window-save-state=never" "Scratchpad geometry remains owned by yabai"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "quit-after-last-window-closed=true" "Scratchpad Ghostty processes quit with their window"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" 'env -u ZDOTDIR -u TMUX -u TMUX_PANE' "Scratchpads do not inherit a stale tmux client environment"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "acquire_scratchpad_open_lock" "Scratchpad hotkeys serialize concurrent launches"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "close_duplicate_scratchpad_title_windows" "Scratchpads remove unlabeled same-title launch-race windows"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" 'visible_ids=$(scratchpad_visible_ids' "Visible same-target scratchpads close without requiring focus"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "suppress-scratchpads" "Scratchpads suppress only their exact JankyBorders window"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" 'has-shadow' "Scratchpads inspect their native shadow state"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" 'toggle shadow' "Scratchpads enable a native shadow for visual separation"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-border-accent" 'apply-to=' "JankyBorders supports exact scratchpad window overrides"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-border-accent" 'scratchpad_window_ids' "Border helper discovers existing yabai scratchpads"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-border-accent" 'active_color=\$TRANSPARENT_COLOR' "Border helper keeps scratchpad overrides transparent"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-border-accent" 'SUPPRESS_ATTEMPTS' "Border helper retries scratchpad overrides during JankyBorders startup"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "tmux new-session -d -e DOTFILES_TMUX_TEMPLATE=skip.*-n terminal" "Scratchpad tmux sessions opt out while creating their raw terminal"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "ensure_standard_scratchpad_tmux_windows" "Scratchpad tmux sessions keep standard windows"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "tmux-session-template.*ensure" "Scratchpad tmux sessions reuse the default template"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template" "ensure_standard_tmux_window.*terminal 0" "Tmux template keeps terminal at window 0"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template" "ensure_standard_tmux_window.*codex 1 codex" "Tmux template starts Codex at window 1"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template" "ensure_standard_tmux_window.*nvim 2 nvim" "Tmux template starts Neovim at window 2"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template" "ensure_standard_tmux_window.*tuxedo 3 todo" "Tmux template starts Tuxedo through the canonical todo wrapper at window 3"
assert_file_exists "$DOTFILES_DIR/home/dot_config/skhd/executable_app-mru.sh" "app-mru helper is declared"
assert_contains "$DOTFILES_DIR/home/dot_config/skhd/executable_focus_app.sh" 'app-mru.sh' "App focus helper uses MRU stacks"
assert_contains "$DOTFILES_DIR/home/dot_config/skhd/executable_focus_app.sh" 'app_mru_cycle' "App focus helper cycles by MRU"
assert_contains "$DOTFILES_DIR/home/dot_config/skhd/executable_focus_app.sh" 'hotkeys terminal new' "Ghostty app focus creates a normal terminal fallback"
assert_contains "$DOTFILES_DIR/home/dot_config/skhd/executable_focus_app.sh" 'EDITOR_APP:-VSCodium' "Editor app focus defaults to VSCodium"
assert_not_contains "$DOTFILES_DIR/home/dot_config/skhd/executable_focus_app.sh" 'focus recent' "App focus helper does not jump to unrelated windows"
assert_not_contains "$DOTFILES_DIR/home/dot_config/skhd/executable_app-mru.sh" 'focus recent' "App MRU helper stays within app windows"
assert_contains "$DOTFILES_DIR/home/dot_config/skhd/executable_app-mru.sh" 'app_mru_id_in_list' "App MRU validates saved IDs against eligible windows"
assert_file_exists "$DOTFILES_DIR/home/dot_config/yabai/executable_create-space" "Create-space helper is declared"
assert_contains "$DOTFILES_DIR/home/dot_config/yabai/executable_create-space" "before_uuids" "Create-space helper identifies the new space by UUID"
assert_contains "$DOTFILES_DIR/home/dot_config/yabai/executable_create-space" "auto|focus|move-window" "Create-space helper supports automatic move-or-focus mode"
assert_contains "$DOTFILES_DIR/home/dot_config/yabai/executable_create-space" "scratchpad_label" "Create-space helper ignores focused scratchpad windows"
assert_contains "$DOTFILES_DIR/home/dot_config/yabai/executable_create-space" "movable_windows.*-gt 1" "Create-space auto mode leaves a space's only normal window in place"
assert_contains "$DOTFILES_DIR/home/dot_config/yabai/executable_create-space" "capture_focused_window_for_move true" "Create-space auto mode only moves when another normal window remains"
assert_contains "$DOTFILES_DIR/home/dot_config/yabai/executable_create-space" "capture_focused_window_for_move false" "Create-space explicit move mode does not require another normal window"
assert_not_contains "$DOTFILES_DIR/home/dot_config/yabai/executable_create-space" "YABAI_SPACE_WALLPAPER" "Create-space helper does not expose wallpaper assignment knobs"
assert_not_contains "$DOTFILES_DIR/home/dot_config/yabai/executable_create-space" "set picture of current desktop" "Create-space helper does not change wallpapers"
assert_file_exists "$DOTFILES_DIR/home/dot_config/yabai/executable_tile-pip-window" "PiP tiling helper is declared"
assert_contains "$DOTFILES_DIR/home/dot_config/yabai/executable_tile-pip-window" "toggle float" "PiP tiling helper inserts PiP into the tree"
assert_contains "$DOTFILES_DIR/home/dot_config/yabai/executable_tile-pip-window" "YABAI_WINDOW_ID" "PiP tiling helper accepts yabai signal window IDs"
assert_not_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" 'SPOTLIGHT_SHELL' "Scratchpads CLI does not load hyperspace shell"
assert_file_exists "$DOTFILES_DIR/home/dot_config/skhd/modules/hyperspace.skhdrc" "Hyperspace skhd module stays parked"
assert_file_exists "$DOTFILES_DIR/home/dot_config/skhd/modules/hyperspace/executable_spotlight-zsh" "Hyperspace module keeps spotlight shell wrapper"
assert_file_exists "$DOTFILES_DIR/home/dot_config/skhd/modules/hyperspace/dot_zshrc" "Hyperspace module keeps spotlight zshrc"
assert_file_exists "$DOTFILES_DIR/home/dot_config/skhd/modules/hyperspace/executable_hyperspace" "Hyperspace module keeps hyperspace CLI"
assert_file_exists "$DOTFILES_DIR/home/dot_config/skhd/modules/hyperspace/executable_open_spotlight_scratchpad" "Hyperspace module keeps spotlight scratchpad launcher"
assert_contains "$DOTFILES_DIR/home/dot_config/skhd/executable_toggle_ghostty_quick_terminal.sh" "background-opacity=1" "Quick terminal scratchpad keeps Ghostty opaque"
assert_contains "$DOTFILES_DIR/home/dot_config/skhd/modules/hyperspace/executable_open_spotlight_scratchpad" "background-opacity=1" "Spotlight scratchpad keeps Ghostty opaque"

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
