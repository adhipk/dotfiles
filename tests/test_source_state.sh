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
assert_contains "$DOTFILES_DIR/home/dot_config/symlink_nvim.tmpl" '\.chezmoi\.sourceDir }}/../nvim' "Neovim config links to the repository checkout"
assert_file_exists "$DOTFILES_DIR/nvim/init.lua" "Neovim config is stored in the repository"
assert_contains "$DOTFILES_DIR/Brewfile" 'brew "clipboard"' "Clipboard CLI is declared in Brewfile"
assert_contains "$DOTFILES_DIR/Brewfile" 'brew "gh"' "GitHub CLI is declared in Brewfile"
assert_contains "$DOTFILES_DIR/Brewfile" 'brew "marksman"' "Marksman Markdown LSP is declared in Brewfile"
assert_contains "$DOTFILES_DIR/Brewfile" 'brew "tree-sitter"' "Tree-sitter CLI is declared in Brewfile"
assert_contains "$DOTFILES_DIR/Brewfile" 'brew "yq"' "yq is declared in Brewfile"
assert_contains "$DOTFILES_DIR/Brewfile" 'cask "vscodium"' "VSCodium is declared in Brewfile"
assert_contains "$DOTFILES_DIR/Brewfile" 'brew "starship"' "Starship prompt is declared in Brewfile"
assert_contains "$DOTFILES_DIR/home/dot_config/yazi/package.toml" "orhnk/system-clipboard" "Yazi system clipboard plugin is declared"
assert_contains "$DOTFILES_DIR/home/dot_config/yazi/keymap.toml" "plugin system-clipboard" "Yazi system clipboard keymap is declared"
assert_contains "$DOTFILES_DIR/home/dot_config/zsh/zshrc.commands" "svg-png()" "svg-png shell helper is declared"

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
assert_file_exists "$GHOSTTY_CONFIG" "Ghostty config is managed"
assert_file_exists "$GHOSTTY_AUTO_THEME" "Ghostty auto theme override is managed"
assert_contains "$GHOSTTY_CONFIG" "theme = Cyberpunk Scarlet Protocol" "Ghostty uses Cyberpunk Scarlet Protocol"
assert_not_contains "$GHOSTTY_AUTO_THEME" "^theme[[:space:]]*=" "Ghostty auto theme override is disabled"
assert_contains "$GHOSTTY_CONFIG" "background-opacity = 0.86" "Ghostty normal terminal background is transparent"
assert_contains "$GHOSTTY_CONFIG" "background-blur = false" "Ghostty background blur is disabled"
assert_contains "$GHOSTTY_CONFIG" "keybind = cmd+backquote=text:\\\\x01\\\\x30" "Ghostty maps Cmd+Backtick to tmux window 0"
assert_contains "$GHOSTTY_CONFIG" "keybind = cmd+1=text:\\\\x01\\\\x31" "Ghostty maps Cmd+1 to tmux window 1"
assert_contains "$GHOSTTY_CONFIG" "keybind = cmd+digit_1=text:\\\\x01\\\\x31" "Ghostty maps Cmd+digit_1 to tmux window 1"
assert_contains "$GHOSTTY_CONFIG" "keybind = cmd+2=text:\\\\x01\\\\x32" "Ghostty maps Cmd+2 to tmux window 2"
assert_contains "$GHOSTTY_CONFIG" "keybind = cmd+digit_2=text:\\\\x01\\\\x32" "Ghostty maps Cmd+digit_2 to tmux window 2"
assert_not_contains "$GHOSTTY_CONFIG" "keybind = cmd+3=text:" "Ghostty leaves Cmd+3 available for Ghostty defaults"
assert_not_contains "$GHOSTTY_CONFIG" "keybind = cmd+digit_3=text:" "Ghostty leaves Cmd+digit_3 available for Ghostty defaults"
assert_not_contains "$GHOSTTY_CONFIG" "keybind = cmd+9=text:" "Ghostty leaves Cmd+9 available for Ghostty defaults"
assert_not_contains "$GHOSTTY_CONFIG" "keybind = cmd+digit_9=text:" "Ghostty leaves Cmd+digit_9 available for Ghostty defaults"

echo ""
echo "Testing managed helper commands..."
for file in \
    executable_watch-sync \
    executable_ghostty-startup-bench \
    executable_lucide-icons-excalidraw.tmpl \
    executable_gh-create-repo \
    executable_man-me \
    executable_reload-colors \
    executable_hotkeys \
    executable_scratchpads \
    executable_tmux-session-template \
    symlink_default-apps.tmpl \
    executable_projects \
    executable_tmux-session-picker \
    executable_tmux-sessionizer \
    executable_tmux-sessionizer-zoxide \
    executable_unescape-buffer \
    executable_unescape-string; do
    assert_file_exists "$DOTFILES_DIR/home/bin/$file" "$file is declared"
done
assert_contains "$DOTFILES_DIR/home/bin/executable_man-me" "parse_metadata_file" "man-me parses source metadata comments"
assert_contains "$DOTFILES_DIR/home/bin/executable_man-me" "SEARCH_QUERY" "man-me supports free-text query matching"
assert_contains "$DOTFILES_DIR/home/bin/executable_man-me" "rg -iq" "man-me uses ripgrep for matching when available"
assert_contains "$DOTFILES_DIR/home/bin/executable_hotkeys" "man-me: tags=.*hotkeys" "hotkeys command carries man-me search tags"
assert_contains "$DOTFILES_DIR/home/dot_skhdrc" "man-me: name=skhdrc" "skhdrc carries man-me metadata"
assert_file_exists "$DOTFILES_DIR/scripts/whichkey/WhichKey.swift" "Shortcut guide Swift source is declared"
assert_file_exists "$DOTFILES_DIR/scripts/build-whichkey.sh" "Shortcut guide build script is declared"
assert_contains "$DOTFILES_DIR/install.sh" "WHICHKEY_INSTALL_PATH=" "Installer builds the shortcut guide into the destination home"
assert_contains "$DOTFILES_DIR/install.sh" 'tmux source-file.*CHEZMOI_DESTINATION' "Installer reloads a running tmux server after apply"
assert_file_missing "$DOTFILES_DIR/home/dot_config/skhd/executable_whichkey" "Architecture-specific shortcut binary is not checked in"

echo ""
echo "Testing scratchpad implementation..."
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" "after-new-session\[50\].*tmux-session-template auto.*session_name" "Tmux config applies the standard template to ordinary new sessions"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template" "pane_start_command" "Tmux template preserves command sessions"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template" "DOTFILES_TMUX_TEMPLATE" "Tmux template supports an explicit opt-out"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template" 'session.*!= hs-\*' "Tmux template preserves hs orchestrator sessions"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template" "wait-for -L" "Tmux template serializes concurrent layout creation"
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
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "tmux new-session -d -e DOTFILES_TMUX_TEMPLATE=skip.*-n terminal" "Scratchpad tmux sessions opt out while creating their raw terminal"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "ensure_standard_scratchpad_tmux_windows" "Scratchpad tmux sessions keep standard windows"
assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" "tmux-session-template.*ensure" "Scratchpad tmux sessions reuse the default template"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template" "create_tmux_window_with_command.*codex.*codex" "Tmux template starts Codex"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template" "create_tmux_window_with_command.*nvim.*nvim" "Tmux template starts Neovim"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template" "ensure_tmux_window_index.*terminal.*0" "Tmux template keeps terminal at window 0"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template" "ensure_tmux_window_index.*codex.*1" "Tmux template keeps Codex at window 1"
assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template" "ensure_tmux_window_index.*nvim.*2" "Tmux template keeps nvim at window 2"
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
