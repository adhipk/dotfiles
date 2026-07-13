#!/usr/bin/env bash

set -uo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$TEST_DIR")"
DOTFILES_DIR="$(cd "$MODULE_DIR/../.." && pwd)"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-tmux-sessions-module.XXXXXX")"
DESTINATION="$TEMP_DIR/home"
STATE="$TEMP_DIR/state.db"
PASSED=0
FAILED=0

cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT

pass() {
  printf '  ✓ %s\n' "$1"
  PASSED=$((PASSED + 1))
}

fail() {
  printf '  ✗ %s\n    Expected: %s\n    Actual:   %s\n' "$1" "$2" "$3"
  FAILED=$((FAILED + 1))
}

assert_file() {
  [[ -f "$1" ]] && pass "$2" || fail "$2" "$1" "missing"
}

assert_executable() {
  [[ -x "$1" ]] && pass "$2" || fail "$2" "executable $1" "missing or not executable"
}

assert_absent() {
  [[ ! -e "$1" ]] && pass "$2" || fail "$2" "absent" "$1 exists"
}

assert_contains() {
  grep -Fq -- "$2" "$1" \
    && pass "$3" \
    || fail "$3" "text containing $2" "$1"
}

assert_not_contains() {
  ! grep -Fq -- "$2" "$1" \
    && pass "$3" \
    || fail "$3" "text excluding $2" "$1"
}

render_profile() {
  local enabled="$1"
  mkdir -p "$DESTINATION"
  chezmoi \
    -S "$DOTFILES_DIR" \
    -D "$DESTINATION" \
    --persistent-state "$STATE" \
    --override-data "{\"modules\":{\"tmuxSessions\":{\"enabled\":$enabled}}}" \
    apply --exclude=scripts,externals --force >/dev/null
}

printf '%s\n' '===================================' 'Tmux Sessions Module Contract Tests' '==================================='

assert_file "$MODULE_DIR/module.yaml" "module manifest exists"
assert_file "$MODULE_DIR/README.md" "module owns its documentation"
assert_executable "$MODULE_DIR/bin/tmux-session-picker" "module owns the session-only picker"
assert_executable "$MODULE_DIR/bin/tmux-sessionizer" "module owns the compatibility sessionizer"
assert_executable "$MODULE_DIR/bin/tmux-sessionizer-zoxide" "module owns the project-aware picker"
assert_executable "$MODULE_DIR/bin/tmux-workspace" "module owns the workspace runtime"
assert_file "$MODULE_DIR/config/sesh.toml" "module owns sesh configuration"
assert_file "$MODULE_DIR/layouts/project.tmux.tsx" "module owns the project layout"
assert_file "$MODULE_DIR/targets/tmux.conf.tmpl" "module owns tmux session controls"
assert_file "$MODULE_DIR/targets/tmux-persistence.conf.tmpl" "module owns persistence configuration"
assert_file "$MODULE_DIR/targets/tmux-which-key-sessions.yaml.tmpl" "module owns session menu actions"
assert_file "$MODULE_DIR/targets/tmux-which-key-layouts.yaml.tmpl" "module owns layout menu actions"

if yq eval '.' "$MODULE_DIR/module.yaml" >/dev/null 2>&1; then
  pass "module manifest parses as YAML"
else
  fail "module manifest parses as YAML" "valid YAML" "parse error"
fi

assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-workspace.tmpl" \
  'includeTemplate "../modules/tmux-sessions/bin/tmux-workspace"' \
  "workspace command is mounted through a thin bridge"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf.tmpl" \
  'includeTemplate "../modules/tmux-sessions/targets/tmux.conf.tmpl"' \
  "tmux mounts one guarded session fragment"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf.tmpl" \
  'includeTemplate "../modules/tmux-sessions/targets/tmux-persistence.conf.tmpl"' \
  "tmux mounts one guarded persistence fragment"
assert_contains "$DOTFILES_DIR/home/dot_config/tmux/which-key.yaml.tmpl" \
  'includeTemplate "../modules/tmux-sessions/targets/tmux-which-key-sessions.yaml.tmpl"' \
  "command center mounts the module through an explicit fragment"
assert_contains "$DOTFILES_DIR/home/dot_zshrc" \
  '[ -r "$HOME/.config/zsh/tmux-sessions.zsh" ]' \
  "parent zsh config uses a guarded runtime adapter"

if HOME="$TEMP_DIR/standalone-home" \
  TMUX_WORKSPACE_LAYOUT_DIR="$MODULE_DIR/layouts" \
  "$MODULE_DIR/bin/tmux-workspace" list 2>/dev/null | grep -qx project; then
  pass "workspace command discovers module-local layouts in isolation"
else
  fail "workspace command discovers module-local layouts in isolation" "project" "layout discovery failed"
fi

render_profile true

for command in tmux-session-picker tmux-sessionizer tmux-sessionizer-zoxide tmux-workspace; do
  assert_executable "$DESTINATION/bin/$command" "enabled profile installs $command"
done
assert_file "$DESTINATION/.config/sesh/sesh.toml" "enabled profile installs sesh configuration"
assert_file "$DESTINATION/.config/zsh/tmux-sessions.zsh" "enabled profile installs shell bindings"
assert_file "$DESTINATION/.config/tmux/layouts/project.tmux.tsx" "enabled profile installs the project layout"
assert_contains "$DESTINATION/.tmux.conf" 'detach-on-destroy off' "enabled profile preserves client-local session history"
assert_contains "$DESTINATION/.tmux.conf" 'Switch to client-local last session' "enabled profile renders last-session selection"
assert_contains "$DESTINATION/.tmux.conf" 'set -s extended-keys off' "enabled profile avoids broad extended-key rewriting"
assert_contains "$DESTINATION/.tmux.conf" "tmux-resurrect#v4.0.0" "enabled profile renders pinned Resurrect"
assert_contains "$DESTINATION/.tmux.conf" "tmux-continuum#v3.1.0" "enabled profile renders pinned Continuum"
assert_contains "$DESTINATION/.tmux.conf" 'tmux-workspace snapshot restore' "enabled profile renders workspace metadata restoration"
assert_contains "$DESTINATION/.config/tmux/which-key.yaml" 'name: Save all state' "enabled profile exposes persistence actions"
assert_contains "$DESTINATION/.config/tmux/which-key.yaml" 'name: +Layouts' "enabled profile exposes workspace actions"
assert_contains "$DESTINATION/.config/zsh/tmux-sessions.zsh" 'tmux-sessionizer -s 3' "enabled shell fragment preserves session slots"

if yq eval '.' "$DESTINATION/.config/tmux/which-key.yaml" >/dev/null 2>&1; then
  pass "enabled command-center YAML remains valid"
else
  fail "enabled command-center YAML remains valid" "valid YAML" "parse error"
fi

mkdir -p "$DESTINATION/.local/state/tmux-workspace" "$DESTINATION/.tmux/resurrect"
touch "$DESTINATION/.local/state/tmux-workspace/keep" "$DESTINATION/.tmux/resurrect/keep"
render_profile false

for command in tmux-session-picker tmux-sessionizer tmux-sessionizer-zoxide tmux-workspace; do
  assert_absent "$DESTINATION/bin/$command" "disabled profile removes $command"
done
assert_absent "$DESTINATION/.config/sesh/sesh.toml" "disabled profile removes sesh configuration"
assert_absent "$DESTINATION/.config/zsh/tmux-sessions.zsh" "disabled profile removes shell bindings"
assert_absent "$DESTINATION/.config/tmux/layouts/project.tmux.tsx" "disabled profile removes the project layout"
assert_file "$DESTINATION/.local/state/tmux-workspace/keep" "disable preserves workspace metadata"
assert_file "$DESTINATION/.tmux/resurrect/keep" "disable preserves Resurrect snapshots"
assert_not_contains "$DESTINATION/.tmux.conf" 'tmux-sessionizer-zoxide' "disabled profile removes tmux session picker bindings"
assert_not_contains "$DESTINATION/.tmux.conf" 'detach-on-destroy off' "disabled profile removes session lifecycle policy"
assert_not_contains "$DESTINATION/.tmux.conf" 'tmux-resurrect' "disabled profile removes persistence plugins"
assert_not_contains "$DESTINATION/.tmux.conf" 'tmux-workspace snapshot' "disabled profile removes persistence hooks"
assert_not_contains "$DESTINATION/.config/tmux/which-key.yaml" 'name: Save all state' "disabled profile removes persistence menu actions"
assert_not_contains "$DESTINATION/.config/tmux/which-key.yaml" 'name: +Layouts' "disabled profile removes workspace menu actions"
assert_contains "$DESTINATION/.tmux.conf" 'tmux-session-template cycle' "disabled profile preserves typed window behavior"
assert_contains "$DESTINATION/.tmux.conf" 'Toggle Yazi side pane' "disabled profile preserves the Yazi module"
assert_contains "$DESTINATION/.tmux.conf" 'Manage agent timers and durable sessions' "disabled profile preserves agent timers"
assert_contains "$DESTINATION/.zshrc" '.config/zsh/tmux-sessions.zsh' "disabled profile preserves the guarded shell adapter"

if yq eval '.' "$DESTINATION/.config/tmux/which-key.yaml" >/dev/null 2>&1; then
  pass "disabled command-center YAML remains valid"
else
  fail "disabled command-center YAML remains valid" "valid YAML" "parse error"
fi

# Simulate deletion after disable. False template branches must not resolve any
# child source, and unrelated parent targets must still render successfully.
REMOVAL_SOURCE="$TEMP_DIR/removal-source"
REMOVAL_HOME="$TEMP_DIR/removal-home"
mkdir -p "$REMOVAL_SOURCE" "$REMOVAL_HOME"
cp -R "$DOTFILES_DIR/home" "$REMOVAL_SOURCE/home"
cp -R "$DOTFILES_DIR/modules" "$REMOVAL_SOURCE/modules"
cp "$DOTFILES_DIR/.chezmoiroot" "$REMOVAL_SOURCE/.chezmoiroot"
rm -rf "$REMOVAL_SOURCE/modules/tmux-sessions"

if chezmoi \
  -S "$REMOVAL_SOURCE" \
  -D "$REMOVAL_HOME" \
  --persistent-state "$TEMP_DIR/removal-state.db" \
  --override-data '{"modules":{"tmuxSessions":{"enabled":false}}}' \
  apply --exclude=scripts,externals --force >/dev/null 2>&1; then
  pass "parent source renders after the disabled module folder is removed"
else
  fail "parent source renders after the disabled module folder is removed" "successful render" "render failed"
fi

assert_absent "$REMOVAL_HOME/bin/tmux-workspace" "physical removal leaves no workspace command"
assert_contains "$REMOVAL_HOME/.tmux.conf" 'Open tmux command center' "physical removal preserves base tmux behavior"
assert_contains "$REMOVAL_HOME/.tmux.conf" 'tmux-session-template cycle' "physical removal preserves typed windows"
assert_contains "$REMOVAL_HOME/.config/tmux/which-key.yaml" 'Agent timers and durable sessions' "physical removal preserves sibling command-center contributions"
assert_contains "$REMOVAL_HOME/.zshrc" '[ -r "$HOME/.config/zsh/tmux-sessions.zsh" ]' "physical removal leaves a safe shell guard"

printf '\nResults: %s passed, %s failed\n' "$PASSED" "$FAILED"
exit "$FAILED"
