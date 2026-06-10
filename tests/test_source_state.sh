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
    dot_config/symlink_nvim.tmpl; do
    assert_file_exists "$DOTFILES_DIR/home/$file" "$file is declared"
done
assert_contains "$DOTFILES_DIR/home/dot_config/symlink_nvim.tmpl" '\.chezmoi\.sourceDir }}/../nvim' "Neovim config links to the repository checkout"
assert_file_exists "$DOTFILES_DIR/nvim/init.lua" "Neovim config is stored in the repository"

echo ""
echo "Testing managed helper commands..."
for file in \
    executable_watch-sync \
    executable_defuddle-clipboard-url \
    executable_ghostty-startup-bench \
    executable_lucide-icons-excalidraw.tmpl \
    executable_reload-colors \
    executable_hotkeys \
    executable_scratchpads \
    executable_serve_md \
    symlink_default-apps.tmpl \
    executable_tmux-session-picker \
    executable_tmux-sessionizer-zoxide \
    executable_unescape-buffer \
    executable_unescape-string \
    executable_nearly-headless \
    executable_hyperspace-open-report \
    executable_hyperspace \
    executable_hyperspace-serve \
    executable_hyperspace-agent-launch \
    executable_hyperspace-run-live-doc; do
    assert_file_exists "$DOTFILES_DIR/home/bin/$file" "$file is declared"
done

echo ""
echo "Testing nearly-headless profile..."
assert_file_exists "$DOTFILES_DIR/home/dot_agents/profiles/nearly-headless/AGENTS.md" "nearly-headless profile exists"
assert_file_exists "$DOTFILES_DIR/home/dot_agents/skills/html-artifact/SKILL.md" "html-artifact skill exists"
assert_file_exists "$DOTFILES_DIR/home/dot_agents/skills/hyperspace-status/SKILL.md" "hyperspace-status skill exists"
assert_file_exists "$DOTFILES_DIR/home/dot_agents/docs/templates/base.html" "HTML base template exists"
assert_file_exists "$DOTFILES_DIR/home/dot_agents/docs/html-artifacts.md" "HTML artifacts guide exists"
assert_file_exists "$DOTFILES_DIR/home/dot_agents/docs/templates/components/finding.html" "HTML finding component exists"
assert_not_contains "$DOTFILES_DIR/home/dot_agents/docs/templates/review.html" "hyperclay" "Review template is plain HTML"
assert_contains "$DOTFILES_DIR/home/dot_agents/AGENTS.md" "profiles/" "Root agents docs mention profiles"

echo ""
echo "Testing hyperspace runtime..."
assert_file_exists "$DOTFILES_DIR/home/dot_config/sesh/sesh.toml" "sesh.toml exists"
assert_file_exists "$DOTFILES_DIR/home/dot_config/hyperspaces/agents.json" "hyperspace agents config exists"
assert_file_exists "$DOTFILES_DIR/home/dot_config/hyperspaces/executable_notify.sh" "hyperspace notify script exists"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf" "alert-bell" "tmux config wires alert-bell hook"
assert_contains "$DOTFILES_DIR/home/dot_skhdrc" "hyperspace connect 1" "skhd loads hyperspace bindings"
assert_contains "$DOTFILES_DIR/home/bin/executable_hyperspace" "connect_session" "hyperspace has session connect helper"
assert_contains "$DOTFILES_DIR/home/bin/executable_hyperspace" "tmux select-window" "hyperspace focuses windows via tmux"
assert_contains "$DOTFILES_DIR/home/bin/executable_hyperspace" "hyperspace focus" "hyperspace focus command exists"
assert_file_exists "$DOTFILES_DIR/home/dot_config/hyperspaces/hyperspace_server.mjs" "hyperspace server script exists"
assert_contains "$DOTFILES_DIR/home/dot_config/hyperspaces/hyperspace_server.mjs" "4200" "hyperspace server defaults to port 4200"
assert_contains "$DOTFILES_DIR/home/dot_config/hyperspaces/hyperspace_server.mjs" "discoverSessions" "hyperspace server routes by session"
assert_contains "$DOTFILES_DIR/home/dot_config/hyperspaces/hyperspace_server.mjs" "resolveSession" "hyperspace server resolves session cwd"
assert_contains "$DOTFILES_DIR/home/dot_config/hyperspaces/hyperspace_server.mjs" "spawnSync" "hyperspace server uses spawnSync for tmux"
assert_file_exists "$DOTFILES_DIR/home/dot_config/hyperspaces/hyperspace_live.js" "hyperspace live doc client exists"
assert_file_exists "$DOTFILES_DIR/home/dot_config/hyperspaces/components/hyperspace-components.js" "hyperspace web components JS exists"
assert_file_exists "$DOTFILES_DIR/home/dot_config/hyperspaces/components/hyperspace-components.css" "hyperspace web components CSS exists"
assert_file_exists "$DOTFILES_DIR/home/dot_config/hyperspaces/livedoc.html.template" "livedoc.html template exists"
assert_contains "$DOTFILES_DIR/home/dot_config/hyperspaces/components/hyperspace-components.js" "hs-callout" "web components register hs-callout"
assert_contains "$DOTFILES_DIR/home/dot_config/hyperspaces/hyperspace_server.mjs" "livedoc.html" "hyperspace server uses livedoc.html source"
assert_contains "$DOTFILES_DIR/home/dot_config/hyperspaces/hyperspace_server.mjs" "readLiveDoc" "hyperspace server loads live doc"
assert_contains "$DOTFILES_DIR/home/dot_config/hyperspaces/hyperspace_server.mjs" "hyperspace-run-live-doc" "hyperspace server runs codex exec on save"
assert_contains "$DOTFILES_DIR/home/dot_config/hyperspaces/hyperspace_server.mjs" "hyperspace-components.js" "live doc shell loads web components"
assert_contains "$DOTFILES_DIR/home/dot_config/hyperspaces/hyperspace_server.mjs" "preview" "hyperspace server serves livedoc preview"
assert_contains "$DOTFILES_DIR/home/dot_config/hyperspaces/hyperspace_server.mjs" "live-doc-canvas" "live doc browser shows rendered editable canvas"
assert_contains "$DOTFILES_DIR/home/dot_config/hyperspaces/hyperspace_server.mjs" "readRenderedCanvas" "live doc API serves canvas HTML"
assert_not_contains "$DOTFILES_DIR/home/dot_config/hyperspaces/hyperspace_server.mjs" "build-live-doc" "live doc has no astro build step"
assert_contains "$DOTFILES_DIR/home/dot_config/hyperspaces/agents.json" "hyperspace-agent-launch" "agents declare launch command"
assert_contains "$DOTFILES_DIR/home/bin/executable_hyperspace-agent-launch" "exec codex" "agent launch starts interactive codex"
assert_contains "$DOTFILES_DIR/AGENTS.md" "Hyperspace live doc" "dotfiles AGENTS.md documents live doc"
assert_file_exists "$DOTFILES_DIR/home/dot_agents/skills/live-doc/SKILL.md" "live-doc skill exists"
assert_contains "$DOTFILES_DIR/home/bin/executable_hyperspace" "valid_project_slug" "hyperspace validates project slugs"
assert_contains "$DOTFILES_DIR/home/bin/executable_hyperspace" "HYPERSPACE_PROJECT_PATH" "hyperspace passes project path to agents"
assert_contains "$DOTFILES_DIR/home/bin/executable_hyperspace" "normalize_project_id" "hyperspace normalizes project ids"

echo ""
echo "Testing scratchpad implementation..."
assert_not_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" 'SCRATCHPAD_STATE_FILE' "Scratchpads CLI does not use a JSON registry"
assert_not_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" 'scratchpads\.json' "Scratchpads CLI does not persist window IDs"
assert_contains "$DOTFILES_DIR/home/dot_config/skhd/executable_focus_app.sh" 'scratchpad // ""' "App focus helper excludes scratchpad windows"
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
assert_contains "$DOTFILES_DIR/home/.chezmoidata.toml" "npm run generate:excalidraw" "External project setup is declared"
assert_contains "$DOTFILES_DIR/home/.chezmoiexternal.toml.tmpl" "type = \"git-repo\"" "Extension repositories use chezmoi externals"
assert_contains "$DOTFILES_DIR/home/.chezmoiexternal.toml.tmpl" "externalProjects" "External projects use chezmoi externals"
assert_file_exists "$DOTFILES_DIR/home/.chezmoiscripts/run_onchange_after_install-vscode-extensions.sh.tmpl" "VS Code install hook exists"
assert_file_exists "$DOTFILES_DIR/home/.chezmoiscripts/run_after_sync-chrome-extensions.sh.tmpl" "Chrome build hook exists"
assert_file_exists "$DOTFILES_DIR/home/.chezmoiscripts/run_after_sync-external-projects.sh.tmpl" "External project setup hook exists"

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
