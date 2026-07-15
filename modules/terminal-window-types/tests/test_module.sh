#!/usr/bin/env bash

set -uo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$TEST_DIR")"
DOTFILES_DIR="$(cd "$MODULE_DIR/../.." && pwd)"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-terminal-window-types.XXXXXX")"
DESTINATION="$TEMP_DIR/home"
STATE="$TEMP_DIR/state.db"

PASSED=0
FAILED=0

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

pass() {
    echo "  ✓ $1"
    ((PASSED++))
}

fail() {
    echo "  ✗ $1"
    echo "    Expected: $2"
    echo "    Actual:   $3"
    ((FAILED++))
}

assert_file() {
    if [[ -f "$1" ]]; then
        pass "$2"
    else
        fail "$2" "$1" "missing"
    fi
}

assert_executable() {
    if [[ -x "$1" ]]; then
        pass "$2"
    else
        fail "$2" "executable $1" "missing or not executable"
    fi
}

assert_absent() {
    if [[ ! -e "$1" ]]; then
        pass "$2"
    else
        fail "$2" "absent" "$1 exists"
    fi
}

assert_contains() {
    if grep -Fq -- "$2" "$1"; then
        pass "$3"
    else
        fail "$3" "text containing $2" "$1"
    fi
}

assert_not_contains() {
    if ! grep -Fq -- "$2" "$1"; then
        pass "$3"
    else
        fail "$3" "no text containing $2" "$1"
    fi
}

render_profile() {
    local enabled="$1"
    mkdir -p "$DESTINATION"
    chezmoi \
        -S "$DOTFILES_DIR" \
        -D "$DESTINATION" \
        --persistent-state "$STATE" \
        --override-data "{\"modules\":{\"terminalWindowTypes\":{\"enabled\":$enabled}}}" \
        apply --exclude=scripts,externals --force >/dev/null
}

echo "===================================="
echo "Terminal Window Types Module Tests"
echo "===================================="

assert_file "$MODULE_DIR/module.yaml" "module manifest exists"
assert_executable "$MODULE_DIR/bin/tmux-session-template" "module owns its executable entrypoint"
assert_file "$MODULE_DIR/targets/tmux.conf.tmpl" "module owns its tmux behavior"
assert_file "$MODULE_DIR/targets/ghostty.conf.tmpl" "module owns its Ghostty adapters"
assert_file "$MODULE_DIR/targets/skhdrc.tmpl" "module owns its sided-Command adapters"
assert_file "$MODULE_DIR/targets/tmux-which-key-cycle.yaml.tmpl" "module owns its command-center actions"
assert_file "$MODULE_DIR/install/remove-legacy-awrit-link.sh.tmpl" "module owns its legacy Awrit cleanup migration"

if yq eval '.' "$MODULE_DIR/module.yaml" >/dev/null 2>&1; then
    pass "module manifest parses as YAML"
else
    fail "module manifest parses as YAML" "valid YAML" "parse error"
fi

assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-session-template.tmpl" \
    'includeTemplate "../modules/terminal-window-types/bin/tmux-session-template"' \
    "stable command path is a thin module bridge"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf.tmpl" \
    'includeTemplate "../modules/terminal-window-types/targets/tmux.conf.tmpl"' \
    "tmux mounts the module through an owned fragment"
assert_contains "$DOTFILES_DIR/home/Library/Application Support/com.mitchellh.ghostty/config.tmpl" \
    'includeTemplate "../modules/terminal-window-types/targets/ghostty.conf.tmpl"' \
    "Ghostty mounts the module through an owned fragment"
assert_contains "$DOTFILES_DIR/home/dot_skhdrc.tmpl" \
    'includeTemplate "../modules/terminal-window-types/targets/skhdrc.tmpl"' \
    "skhd mounts the module through an owned fragment"
assert_contains "$DOTFILES_DIR/home/.chezmoiscripts/run_onchange_before_remove-legacy-awrit-link.sh.tmpl" \
    'includeTemplate "../modules/terminal-window-types/install/remove-legacy-awrit-link.sh.tmpl"' \
    "ChezMoi mounts the module-owned legacy cleanup migration"
assert_contains "$DOTFILES_DIR/home/.chezmoiscripts/run_onchange_before_remove-legacy-awrit-link.sh.tmpl" \
    'if .modules.terminalWindowTypes.enabled' \
    "legacy cleanup bridge is safe when the module is disabled and removed"
assert_contains "$MODULE_DIR/install/remove-legacy-awrit-link.sh.tmpl" \
    '[[ -L "$legacy_link" ]] || exit 0' \
    "legacy cleanup only considers symlinks"
assert_contains "$MODULE_DIR/install/remove-legacy-awrit-link.sh.tmpl" \
    '[[ "$current_target" != "$legacy_target" ]]' \
    "legacy cleanup verifies the exact former managed target"
assert_contains "$MODULE_DIR/install/remove-legacy-awrit-link.sh.tmpl" \
    'unlink "$legacy_link"' \
    "legacy cleanup unlinks only the verified launcher"
assert_not_contains "$MODULE_DIR/install/remove-legacy-awrit-link.sh.tmpl" \
    'rm -' \
    "legacy cleanup never recursively removes Awrit state"
assert_contains "$MODULE_DIR/bin/tmux-session-template" \
    'source "$DOTFILES_LIB_DIR/$library"' \
    "runtime command consumes the public standard library"

render_profile true

assert_executable "$DESTINATION/bin/tmux-session-template" "enabled profile installs the public command"
assert_contains "$DESTINATION/.tmux.conf" 'after-new-session[50]' "enabled profile renders automatic session setup"
assert_contains "$DESTINATION/.tmux.conf" 'Cycle Tuxedo windows' "enabled profile renders typed cycling"
assert_contains "$DESTINATION/.tmux.conf" 'New Tuxedo window' "enabled profile renders typed creation"
assert_contains "$DESTINATION/.tmux.conf" 'set-option -gu allow-passthrough' "enabled profile clears legacy graphics passthrough"
assert_not_contains "$DESTINATION/.tmux.conf" 'allow-passthrough on' "enabled profile does not enable graphics passthrough"
assert_absent "$DESTINATION/bin/awrit" "enabled profile does not install an Awrit launcher"
assert_contains "$DESTINATION/.tmux.conf" 'S-Enter send-keys Escape "[13;2u"' "enabled profile forwards Shift+Enter to Codex explicitly"
assert_contains "$DESTINATION/.tmux.conf" 'Duplicate current window" S-F4' "enabled profile renders the duplicate bridge"
assert_contains "$DESTINATION/.tmux.conf" '@resurrect-processes '\''codex tuxedo yazi'\''' "enabled profile contributes typed persistence"
assert_contains "$DESTINATION/Library/Application Support/com.mitchellh.ghostty/config" 'keybind = cmd+backquote=csi:48;5u' "enabled profile renders Command cycling"
assert_contains "$DESTINATION/Library/Application Support/com.mitchellh.ghostty/config" 'keybind = ctrl+shift+digit_3=csi:51;6u' "enabled profile renders typed creation translation"
assert_contains "$DESTINATION/Library/Application Support/com.mitchellh.ghostty/config" 'keybind = shift+enter=csi:13;2u' "enabled profile distinguishes Shift+Enter"
assert_contains "$DESTINATION/.skhdrc" '"Ghostty" : skhd -k "f16"' "enabled profile renders Right Command+D"
assert_contains "$DESTINATION/.config/tmux/which-key.yaml" 'name: Cycle terminal' "enabled profile renders command-center cycling"
assert_contains "$DESTINATION/.config/tmux/which-key.yaml" 'name: Duplicate current' "enabled profile renders command-center duplication"
assert_not_contains "$DESTINATION/.config/tmux/which-key.yaml" 'Awrit' "enabled profile omits Awrit command-center actions"

if yq eval '.' "$DESTINATION/.config/tmux/which-key.yaml" >/dev/null 2>&1; then
    pass "enabled command-center YAML is valid"
else
    fail "enabled command-center YAML is valid" "valid YAML" "parse error"
fi

if ghostty +validate-config --config-file="$DESTINATION/Library/Application Support/com.mitchellh.ghostty/config" >/dev/null 2>&1; then
    pass "enabled Ghostty configuration validates"
else
    fail "enabled Ghostty configuration validates" "valid Ghostty configuration" "validation failed"
fi

render_profile false

assert_absent "$DESTINATION/bin/tmux-session-template" "disabled profile removes the public command"
assert_not_contains "$DESTINATION/.tmux.conf" 'tmux-session-template' "disabled profile removes typed tmux actions"
assert_not_contains "$DESTINATION/.tmux.conf" '@dotfiles_window_type' "disabled profile removes typed rename policy"
assert_contains "$DESTINATION/.tmux.conf" 'set-option -gu allow-passthrough' "disabled profile keeps the legacy passthrough reset"
assert_not_contains "$DESTINATION/.tmux.conf" 'allow-passthrough on' "disabled profile does not enable graphics passthrough"
assert_not_contains "$DESTINATION/Library/Application Support/com.mitchellh.ghostty/config" 'cmd+backquote' "disabled profile removes Ghostty cycling"
assert_not_contains "$DESTINATION/.skhdrc" 'skhd -k "f16"' "disabled profile removes Right Command+D"
assert_not_contains "$DESTINATION/.config/tmux/which-key.yaml" 'tmux-session-template' "disabled profile removes command-center actions"
assert_contains "$DESTINATION/.tmux.conf" 'Open sesh session picker" S-F6' "disabled profile preserves the shared session picker"
assert_contains "$DESTINATION/.tmux.conf" 'C-4 select-window -t :4' "disabled profile preserves direct index switching"
assert_contains "$DESTINATION/.skhdrc" '"Ghostty" : skhd -k "f18"' "disabled profile preserves Right Command+S"
assert_contains "$DESTINATION/Library/Application Support/com.mitchellh.ghostty/config" 'keybind = cmd+b=' "disabled profile preserves the Yazi module"
assert_contains "$DESTINATION/.tmux.conf" '@resurrect-processes '\''yazi'\''' "disabled profile leaves only enabled persistence contributions"

if yq eval '.' "$DESTINATION/.config/tmux/which-key.yaml" >/dev/null 2>&1; then
    pass "disabled command-center YAML remains valid"
else
    fail "disabled command-center YAML remains valid" "valid YAML" "parse error"
fi

if ghostty +validate-config --config-file="$DESTINATION/Library/Application Support/com.mitchellh.ghostty/config" >/dev/null 2>&1; then
    pass "disabled Ghostty configuration validates"
else
    fail "disabled Ghostty configuration validates" "valid Ghostty configuration" "validation failed"
fi

# Model source removal after disable: a copy of the parent source must still
# render when the feature folder is physically absent.
REMOVAL_SOURCE="$TEMP_DIR/removal-source"
REMOVAL_HOME="$TEMP_DIR/removal-home"
mkdir -p "$REMOVAL_SOURCE" "$REMOVAL_HOME"
cp -R "$DOTFILES_DIR/home" "$REMOVAL_SOURCE/home"
cp -R "$DOTFILES_DIR/modules" "$REMOVAL_SOURCE/modules"
cp "$DOTFILES_DIR/.chezmoiroot" "$REMOVAL_SOURCE/.chezmoiroot"
rm -rf "$REMOVAL_SOURCE/modules/terminal-window-types"

if chezmoi \
    -S "$REMOVAL_SOURCE" \
    -D "$REMOVAL_HOME" \
    --persistent-state "$TEMP_DIR/removal-state.db" \
    --override-data '{"modules":{"terminalWindowTypes":{"enabled":false}}}' \
    apply --exclude=scripts,externals --force >/dev/null 2>&1; then
    pass "parent source renders after the disabled module folder is removed"
else
    fail "parent source renders after the disabled module folder is removed" "successful render" "render failed"
fi

assert_contains "$REMOVAL_HOME/.tmux.conf" 'Open tmux command center" S-F7' "physical removal preserves unrelated tmux behavior"
assert_contains "$REMOVAL_HOME/.skhdrc" 'skhd -k "f19"' "physical removal preserves unrelated skhd behavior"
assert_contains "$REMOVAL_HOME/Library/Application Support/com.mitchellh.ghostty/config" 'keybind = cmd+b=' "physical removal preserves unrelated Ghostty behavior"

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

exit "$FAILED"
