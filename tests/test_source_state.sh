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
    executable_unescape-buffer \
    executable_unescape-string \
    executable_headless-artifacts \
    executable_nearly-headless \
    executable_hyperspace-open-report \
    executable_hyperspace-serve \
    executable_hyperspace-run-live-doc; do
    assert_file_exists "$DOTFILES_DIR/home/bin/$file" "$file is declared"
done

echo ""
echo "Testing nearly-headless profile..."
assert_file_exists "$DOTFILES_DIR/home/dot_agents/profiles/nearly-headless/AGENTS.md" "nearly-headless profile exists"
assert_file_exists "$DOTFILES_DIR/home/dot_agents/skills/html-artifact/SKILL.md" "html-artifact skill exists"
assert_file_exists "$DOTFILES_DIR/home/dot_agents/skills/live-doc/SKILL.md" "live-doc skill exists"
assert_not_contains "$DOTFILES_DIR/home/dot_agents/profiles/nearly-headless/AGENTS.md" "hyperspace-status" "profile docs no longer reference hyperspace-status"
assert_file_exists "$DOTFILES_DIR/home/dot_agents/docs/templates/base.html" "HTML base template exists"
assert_file_exists "$DOTFILES_DIR/home/dot_agents/docs/html-artifacts.md" "HTML artifacts guide exists"
assert_file_exists "$DOTFILES_DIR/home/dot_agents/docs/headless-html-artifacts.md" "nearly-headless product guide exists"
assert_file_exists "$DOTFILES_DIR/home/dot_agents/docs/nearly-headless-product.md" "nearly-headless product thesis exists"
assert_not_contains "$DOTFILES_DIR/home/dot_agents/docs/nearly-headless.md" "tmux-session-manager" "nearly-headless doc no longer references tmux manager"
assert_contains "$DOTFILES_DIR/AGENTS.md" "Hyperspace live doc" "dotfiles AGENTS.md documents live doc"
assert_file_exists "$DOTFILES_DIR/home/dot_config/nearly-headless/config.json" "nearly-headless config exists"
assert_file_exists "$DOTFILES_DIR/home/dot_agents/docs/templates/components/finding.html" "HTML finding component exists"
assert_not_contains "$DOTFILES_DIR/home/dot_agents/docs/templates/review.html" "hyperclay" "Review template is plain HTML"
assert_contains "$DOTFILES_DIR/home/dot_agents/AGENTS.md" "profiles/" "Root agents docs mention profiles"
assert_contains "$DOTFILES_DIR/home/bin/executable_nearly-headless" ".local/share/nearly-headless" "nearly-headless command shims to external project"
assert_contains "$DOTFILES_DIR/home/bin/executable_hyperspace-serve" "nearly-headless serve" "hyperspace-serve is compatibility alias"
assert_contains "$DOTFILES_DIR/home/bin/executable_hyperspace-open-report" "nearly-headless open" "open-report is compatibility alias"
assert_contains "$DOTFILES_DIR/home/dot_agents/docs/nearly-headless-product.md" "chooses provider" "nearly-headless product thesis uses provider sessions"
assert_contains "$DOTFILES_DIR/home/bin/executable_defuddle-clipboard-url" "npx --yes defuddle" "Defuddle helper can run through npx"
assert_contains "$DOTFILES_DIR/home/bin/executable_defuddle-clipboard-url" "wrap_with_original_css" "Defuddle helper preserves original CSS"
assert_contains "$DOTFILES_DIR/home/dot_skhdrc" "defuddle-clipboard-url" "skhd binds Defuddle clipboard helper"
assert_contains "$DOTFILES_DIR/home/bin/executable_serve_md" "pandoc" "serve_md renders Markdown through pandoc"
assert_contains "$DOTFILES_DIR/home/bin/executable_serve_md" "caddy" "serve_md serves rendered Markdown with caddy"
assert_contains "$DOTFILES_DIR/Brewfile" "brew \"caddy\"" "Brewfile installs caddy for serve_md"
assert_contains "$DOTFILES_DIR/Brewfile" "brew \"pandoc\"" "Brewfile installs pandoc for serve_md"

echo ""
echo "Testing nearly-headless dotfiles wiring..."
assert_file_exists "$DOTFILES_DIR/home/dot_config/nearly-headless/config.json" "nearly-headless user config exists"
assert_contains "$DOTFILES_DIR/home/dot_config/nearly-headless/config.json" "dotfiles" "nearly-headless config includes dotfiles project"
assert_file_exists "$DOTFILES_DIR/home/dot_agents/docs/nearly-headless-port-plan.md" "nearly-headless port plan exists"
assert_not_contains "$DOTFILES_DIR/home/dot_skhdrc" "hyperspace connect 1" "skhd no longer loads tmux hyperspace bindings"
assert_not_contains "$DOTFILES_DIR/Brewfile" 'brew "sesh"' "sesh is not a brew dependency"
if [ -f "$DOTFILES_DIR/home/dot_config/hyperspaces/hyperspace_server.mjs" ]; then
  echo "FAIL: nearly-headless server should not remain in dotfiles"
  exit 1
fi
echo "PASS: nearly-headless server removed from dotfiles"
NH_REPO="${NEARLY_HEADLESS_PROJECT_DIR:-$HOME/.local/share/nearly-headless}"
if [ -f "$NH_REPO/package.json" ]; then
  assert_file_exists "$NH_REPO/src/server/index.mjs" "external nearly-headless server exists"
  assert_file_exists "$NH_REPO/src/orchestration/store.mjs" "external orchestration store exists"
  assert_contains "$NH_REPO/src/server/index.mjs" "event-stream" "external server exposes SSE stream"
  assert_contains "$NH_REPO/src/server/index.mjs" "recordEvent" "external server appends orchestration events"
fi
assert_contains "$DOTFILES_DIR/MIGRATION.md" "Dropped: tmux / sesh" "migration doc records tmux stack removal"

echo ""
echo "Testing scratchpad implementation..."
assert_not_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" 'SCRATCHPAD_STATE_FILE' "Scratchpads CLI does not use a JSON registry"
assert_not_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" 'scratchpads\.json' "Scratchpads CLI does not persist window IDs"
assert_contains "$DOTFILES_DIR/home/dot_config/skhd/executable_focus_app.sh" 'scratchpad // ""' "App focus helper excludes scratchpad windows"
assert_not_contains "$DOTFILES_DIR/home/bin/executable_scratchpads" 'SPOTLIGHT_SHELL' "Scratchpads CLI does not load hyperspace shell"

echo ""
echo "Testing migration documentation..."
assert_file_exists "$DOTFILES_DIR/MIGRATION.md" "migration status dashboard exists"
assert_file_exists "$DOTFILES_DIR/EXTERNAL-PROJECTS.md" "external projects workflow exists"
assert_file_exists "$DOTFILES_DIR/home/dot_agents/docs/agent-comms.md" "agent-comms boundary doc exists"
assert_contains "$DOTFILES_DIR/MIGRATION.md" "agent-comms" "migration doc covers agent-comms"
assert_contains "$DOTFILES_DIR/MIGRATION.md" "gemma-gem" "migration doc covers gemma-gem"
assert_contains "$DOTFILES_DIR/home/dot_agents/profiles/nearly-headless/TASKS.md" "Phase 3" "task list includes extraction phase"

echo ""
echo "Testing extension declarations..."
assert_contains "$DOTFILES_DIR/home/.chezmoidata.toml" "vscodeExtensions" "VS Code extensions are declared"
assert_contains "$DOTFILES_DIR/home/.chezmoidata.toml" "name = \"gemma-gem\"" "Chrome extension is declared"
assert_contains "$DOTFILES_DIR/home/.chezmoidata.toml" "buildCommand = \"pnpm build\"" "Chrome extension is built from source"
assert_contains "$DOTFILES_DIR/home/.chezmoidata.toml" "\\[\\[externalProjects\\]\\]" "External projects are declared"
assert_contains "$DOTFILES_DIR/home/.chezmoidata.toml" "name = \"raycast-lucide-excalidraw\"" "Lucide Raycast project is declared"
assert_contains "$DOTFILES_DIR/home/.chezmoidata.toml" "name = \"nearly-headless\"" "nearly-headless external project is declared"
assert_contains "$DOTFILES_DIR/home/.chezmoidata.toml" "npm run generate:excalidraw" "External project setup is declared"
assert_contains "$DOTFILES_DIR/home/.chezmoidata.toml" "git@github.com:adhipk/nearly-headless.git" "nearly-headless external project points at GitHub"
assert_contains "$DOTFILES_DIR/home/.chezmoiexternal.toml.tmpl" "type = \"git-repo\"" "Extension repositories use chezmoi externals"
assert_contains "$DOTFILES_DIR/home/.chezmoiexternal.toml.tmpl" "externalProjects" "External projects use chezmoi externals"
assert_contains "$DOTFILES_DIR/home/.chezmoiexternal.toml.tmpl" '"origin"' "External git pulls specify remote explicitly"
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
