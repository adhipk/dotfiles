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
assert_contains "$DOTFILES_DIR/Brewfile" 'brew "tree-sitter"' "Tree-sitter CLI is declared in Brewfile"
assert_contains "$DOTFILES_DIR/Brewfile" 'brew "yq"' "yq is declared in Brewfile"
assert_contains "$DOTFILES_DIR/home/dot_config/yazi/package.toml" "orhnk/system-clipboard" "Yazi system clipboard plugin is declared"
assert_contains "$DOTFILES_DIR/home/dot_config/yazi/keymap.toml" "plugin system-clipboard" "Yazi system clipboard keymap is declared"
assert_contains "$DOTFILES_DIR/home/dot_config/zsh/zshrc.commands" "svg-png()" "svg-png shell helper is declared"

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
    symlink_default-apps.tmpl \
    executable_projects \
    executable_tmux-session-picker \
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

echo ""
echo "Testing scratchpad implementation..."
assert_not_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" 'SCRATCHPAD_STATE_FILE' "Scratchpads CLI does not use a JSON registry"
assert_not_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" 'scratchpads\.json' "Scratchpads CLI does not persist window IDs"
assert_file_exists "$DOTFILES_DIR/home/dot_config/yabai/executable_projects" "projects CLI is declared"
assert_file_exists "$DOTFILES_DIR/home/dot_config/yabai/executable_tile-pip-window" "PiP tiling helper is declared"
assert_contains "$DOTFILES_DIR/home/dot_config/yabai/executable_tile-pip-window" "toggle float" "PiP tiling helper inserts PiP into the tree"
assert_contains "$DOTFILES_DIR/home/dot_config/yabai/executable_tile-pip-window" "YABAI_WINDOW_ID" "PiP tiling helper accepts yabai signal window IDs"
assert_not_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" 'SPOTLIGHT_SHELL' "Scratchpads CLI does not load hyperspace shell"
assert_file_exists "$DOTFILES_DIR/home/dot_config/skhd/modules/hyperspace/executable_spotlight-zsh" "Hyperspace module keeps spotlight shell wrapper"
assert_file_exists "$DOTFILES_DIR/home/dot_config/skhd/modules/hyperspace/dot_zshrc" "Hyperspace module keeps spotlight zshrc"
assert_file_exists "$DOTFILES_DIR/home/dot_config/skhd/modules/hyperspace/executable_hyperspace" "Hyperspace module keeps hyperspace CLI"
assert_file_exists "$DOTFILES_DIR/home/dot_config/skhd/modules/hyperspace/executable_open_spotlight_scratchpad" "Hyperspace module keeps spotlight scratchpad launcher"

echo ""
echo "Testing extension declarations..."
assert_contains "$DOTFILES_DIR/home/.chezmoidata.toml" "vscodeExtensions" "VS Code extensions are declared"
assert_contains "$DOTFILES_DIR/home/.chezmoidata.toml" "name = \"gemma-gem\"" "Chrome extension is declared"
assert_contains "$DOTFILES_DIR/home/.chezmoidata.toml" "buildCommand = \"pnpm build\"" "Chrome extension is built from source"
assert_contains "$DOTFILES_DIR/home/.chezmoidata.toml" "\\[\\[externalProjects\\]\\]" "External projects are declared"
assert_contains "$DOTFILES_DIR/home/.chezmoidata.toml" "name = \"raycast-lucide-excalidraw\"" "Lucide Raycast project is declared"
assert_contains "$DOTFILES_DIR/home/.chezmoidata.toml" "npm --prefix projects/excalidraw-library run generate" "External project setup is declared"
assert_contains "$DOTFILES_DIR/home/.chezmoiexternal.toml.tmpl" "type = \"git-repo\"" "Extension repositories use chezmoi externals"
assert_contains "$DOTFILES_DIR/home/.chezmoiexternal.toml.tmpl" "externalProjects" "External projects use chezmoi externals"
assert_file_exists "$DOTFILES_DIR/home/.chezmoiscripts/run_onchange_after_install-vscode-extensions.sh.tmpl" "VS Code install hook exists"
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
