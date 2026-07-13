#!/usr/bin/env bash

set -uo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$TEST_DIR")"
DOTFILES_DIR="$(cd "$MODULE_DIR/../.." && pwd)"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-scratchpads-module.XXXXXX")"
DESTINATION="$TEMP_DIR/home"
STATE="$TEMP_DIR/state.db"

PASSED=0
FAILED=0

cleanup() {
  rm -rf "$TEMP_DIR"
}
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
  if [[ -f "$1" ]]; then pass "$2"; else fail "$2" "$1" "missing"; fi
}

assert_executable() {
  if [[ -x "$1" ]]; then pass "$2"; else fail "$2" "executable $1" "missing or not executable"; fi
}

assert_absent() {
  if [[ ! -e "$1" ]]; then pass "$2"; else fail "$2" "absent" "$1 exists"; fi
}

assert_contains() {
  if grep -Fq -- "$2" "$1"; then pass "$3"; else fail "$3" "text containing $2" "$1"; fi
}

assert_not_contains() {
  if ! grep -Fq -- "$2" "$1"; then pass "$3"; else fail "$3" "no text containing $2" "$1"; fi
}

render_profile() {
  local enabled="$1"
  mkdir -p "$DESTINATION"
  chezmoi \
    -S "$DOTFILES_DIR" \
    -D "$DESTINATION" \
    --persistent-state "$STATE" \
    --override-data "{\"modules\":{\"scratchpads\":{\"enabled\":$enabled}}}" \
    apply --exclude=scripts,externals --force >/dev/null
}

printf '================================\n'
printf 'Scratchpads Module Contract Tests\n'
printf '================================\n'

assert_file "$MODULE_DIR/module.yaml" "module manifest exists"
assert_executable "$MODULE_DIR/bin/scratchpads" "module owns its executable entrypoint"
assert_executable "$MODULE_DIR/bin/toggle_ghostty_quick_terminal.sh" "module owns the legacy quick-terminal helper"
assert_file "$MODULE_DIR/config/defaults.toml" "module owns standard TOML defaults"
assert_file "$MODULE_DIR/lib/config.sh" "module owns its config adapter"
assert_file "$MODULE_DIR/targets/skhdrc.tmpl" "module owns Fn scratchpad bindings"
assert_file "$MODULE_DIR/targets/yabairc.tmpl" "module owns yabai rule registration"
assert_file "$MODULE_DIR/tests/test_scratchpads.sh" "module owns focused behavior tests"

if yq eval '.' "$MODULE_DIR/module.yaml" >/dev/null 2>&1; then
  pass "module manifest parses as YAML"
else
  fail "module manifest parses as YAML" "valid YAML" "parse error"
fi

if yq -p=toml -o=json eval '.' "$MODULE_DIR/config/defaults.toml" >/dev/null 2>&1; then
  pass "module defaults parse as TOML"
else
  fail "module defaults parse as TOML" "valid TOML" "parse error"
fi

DEFAULTS=$(SCRATCHPADS_CONFIG_FILE="$MODULE_DIR/config/defaults.toml" bash -c '
  source "$1"
  printf "%s|%s|%s|%s|%s\n" \
    "$(scratchpads_config_string .paths.dotfiles missing)" \
    "$(scratchpads_config_string .paths.projects missing)" \
    "$(scratchpads_config_string .tmux.terminal_label missing)" \
    "$(scratchpads_config_string .tmux.dotfiles_session missing)" \
    "$(scratchpads_config_string .tmux.projects_session missing)"
' _ "$MODULE_DIR/lib/config.sh")
if [[ "$DEFAULTS" == "dotfiles|projects|terminal|dotfiles|projects" ]]; then
  pass "TOML defaults preserve paths, label, and separate tmux sessions"
else
  fail "TOML defaults preserve paths, label, and separate tmux sessions" \
    "dotfiles|projects|terminal|dotfiles|projects" "$DEFAULTS"
fi

cat >"$TEMP_DIR/custom.toml" <<'EOF'
schema_version = 1
[paths]
dotfiles = "src/dotfiles"
projects = "/tmp/project-root"
[tmux]
terminal_label = "panel"
dotfiles_session = "cfg"
projects_session = "work"
EOF
CUSTOM=$(HOME="$TEMP_DIR/config-home" SCRATCHPADS_CONFIG_FILE="$TEMP_DIR/custom.toml" bash -c '
  source "$1"
  printf "%s|%s|%s|%s\n" \
    "$(scratchpads_home_path "$(scratchpads_config_string .paths.dotfiles missing)")" \
    "$(scratchpads_home_path "$(scratchpads_config_string .paths.projects missing)")" \
    "$(scratchpads_config_string .tmux.terminal_label missing)" \
    "$(scratchpads_config_string .tmux.projects_session missing)"
' _ "$MODULE_DIR/lib/config.sh")
if [[ "$CUSTOM" == "$TEMP_DIR/config-home/src/dotfiles|/tmp/project-root|panel|work" ]]; then
  pass "custom TOML overrides paths and tmux identity"
else
  fail "custom TOML overrides paths and tmux identity" \
    "$TEMP_DIR/config-home/src/dotfiles|/tmp/project-root|panel|work" "$CUSTOM"
fi

assert_contains "$DOTFILES_DIR/home/bin/executable_scratchpads.tmpl" \
  'includeTemplate "../modules/scratchpads/bin/scratchpads"' \
  "stable command path is a thin module bridge"
assert_contains "$DOTFILES_DIR/home/dot_skhdrc.tmpl" \
  'includeTemplate "../modules/scratchpads/targets/skhdrc.tmpl"' \
  "skhd mounts one scratchpad contribution"
assert_contains "$DOTFILES_DIR/home/dot_yabairc.tmpl" \
  'includeTemplate "../modules/scratchpads/targets/yabairc.tmpl"' \
  "yabai mounts one scratchpad contribution"
assert_contains "$MODULE_DIR/bin/scratchpads" \
  'if [ -x "$HOME/bin/tmux-session-template" ]' \
  "scratchpads tolerate the optional typed-window command"

if bash -n "$MODULE_DIR/bin/scratchpads" \
  && bash -n "$MODULE_DIR/bin/toggle_ghostty_quick_terminal.sh" \
  && bash -n "$MODULE_DIR/lib/config.sh"; then
  pass "module shell entrypoints parse"
else
  fail "module shell entrypoints parse" "valid bash" "syntax error"
fi

if HOME="$TEMP_DIR/standalone-home" "$MODULE_DIR/bin/scratchpads" --help >/dev/null; then
  pass "copied command discovers its child-local config"
else
  fail "copied command discovers its child-local config" "successful --help" "command failed"
fi

if render_profile true; then
  pass "enabled profile renders in a cold home"
else
  fail "enabled profile renders in a cold home" "successful chezmoi apply" "apply failed"
fi

assert_executable "$DESTINATION/bin/scratchpads" "enabled profile installs scratchpads"
assert_executable "$DESTINATION/.config/skhd/toggle_ghostty_quick_terminal.sh" "enabled profile installs the quick-terminal helper"
assert_file "$DESTINATION/.config/scratchpads/config.toml" "enabled profile installs TOML config"
assert_file "$DESTINATION/.config/scratchpads/config.sh" "enabled profile installs config adapter"
assert_contains "$DESTINATION/.skhdrc" 'fn - 0x2B : ~/bin/scratchpads open codex' "enabled profile preserves Fn+Comma"
assert_contains "$DESTINATION/.skhdrc" 'fn - 1 : ~/bin/scratchpads open projects' "enabled profile preserves Fn+1"
assert_contains "$DESTINATION/.yabairc" 'eval "$("$HOME/bin/scratchpads" rules)"' "enabled profile registers yabai rules through the public command"
if HOME="$DESTINATION" "$DESTINATION/bin/scratchpads" --help >/dev/null; then
  pass "installed command resolves its managed config adapter"
else
  fail "installed command resolves its managed config adapter" "successful --help" "command failed"
fi

if render_profile false; then
  pass "disabled profile re-renders in the same cold home"
else
  fail "disabled profile re-renders in the same cold home" "successful chezmoi apply" "apply failed"
fi

assert_absent "$DESTINATION/bin/scratchpads" "disabled profile removes the public command"
assert_absent "$DESTINATION/.config/skhd/toggle_ghostty_quick_terminal.sh" "disabled profile removes the quick-terminal helper"
assert_absent "$DESTINATION/.config/scratchpads/config.toml" "disabled profile removes TOML config"
assert_absent "$DESTINATION/.config/scratchpads/config.sh" "disabled profile removes config adapter"
assert_not_contains "$DESTINATION/.skhdrc" 'scratchpads open codex' "disabled profile removes Fn+Comma"
assert_not_contains "$DESTINATION/.skhdrc" 'scratchpads open projects' "disabled profile removes Fn+1"
assert_not_contains "$DESTINATION/.yabairc" 'bin/scratchpads" rules' "disabled profile removes yabai rule registration"
assert_contains "$DESTINATION/.yabairc" 'rule --remove "scratchpad_terminal"' "disabled profile cleans the current yabai rule"
assert_contains "$DESTINATION/.skhdrc" 'alt - n : ~/.config/yabai/create-space auto' "disabled profile preserves space management"
assert_contains "$DESTINATION/.skhdrc" 'hotkeys app-focus 1 "@browser"' "disabled profile preserves app focus"
assert_contains "$DESTINATION/.yabairc" 'signal --add label=tile_pip_on_create' "disabled profile preserves unrelated yabai signals"

# Model disable followed by physical source removal. Every bridge guards its
# child include, so unrelated parent targets must remain renderable.
REMOVAL_SOURCE="$TEMP_DIR/removal-source"
REMOVAL_HOME="$TEMP_DIR/removal-home"
mkdir -p "$REMOVAL_SOURCE" "$REMOVAL_HOME"
cp -R "$DOTFILES_DIR/home" "$REMOVAL_SOURCE/home"
cp -R "$DOTFILES_DIR/modules" "$REMOVAL_SOURCE/modules"
cp "$DOTFILES_DIR/.chezmoiroot" "$REMOVAL_SOURCE/.chezmoiroot"
rm -rf "$REMOVAL_SOURCE/modules/scratchpads"

if chezmoi \
  -S "$REMOVAL_SOURCE" \
  -D "$REMOVAL_HOME" \
  --persistent-state "$TEMP_DIR/removal-state.db" \
  --override-data '{"modules":{"scratchpads":{"enabled":false}}}' \
  apply --exclude=scripts,externals --force >/dev/null 2>&1; then
  pass "parent source renders after the disabled module folder is removed"
else
  fail "parent source renders after the disabled module folder is removed" "successful render" "render failed"
fi

assert_absent "$REMOVAL_HOME/bin/scratchpads" "physical removal leaves no scratchpad command"
assert_contains "$REMOVAL_HOME/.skhdrc" 'alt - n : ~/.config/yabai/create-space auto' "physical removal preserves unrelated skhd behavior"
assert_contains "$REMOVAL_HOME/.yabairc" 'signal --add label=tile_pip_on_create' "physical removal preserves unrelated yabai behavior"

printf '\n================================\n'
printf 'Results: %s passed, %s failed\n' "$PASSED" "$FAILED"
printf '================================\n'

exit "$FAILED"
