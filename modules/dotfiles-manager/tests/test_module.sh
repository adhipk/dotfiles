#!/usr/bin/env bash

set -uo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$TEST_DIR")"
DOTFILES_DIR="$(cd "$MODULE_DIR/../.." && pwd)"
MANAGER="$MODULE_DIR/bin/dotfiles-manager"
UI="$MODULE_DIR/bin/dotfiles-manager-ui"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-manager-test.XXXXXX")"
ACTIONS_FILE="$TEMP_ROOT/actions"
PASSED=0
FAILED=0

cleanup() {
  rm -rf "$TEMP_ROOT"
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

assert_contains() {
  if grep -Fq -- "$2" "$1"; then pass "$3"; else fail "$3" "text containing $2" "$1"; fi
}

assert_action() {
  if grep -Fqx -- "$1" "$ACTIONS_FILE"; then pass "$2"; else fail "$2" "$1" "$(cat "$ACTIONS_FILE")"; fi
}

assert_no_action_fragment() {
  if grep -Fq -- "$1" "$ACTIONS_FILE"; then fail "$2" "no action containing $1" "$(cat "$ACTIONS_FILE")"; else pass "$2"; fi
}

printf '%s\n' '================================'
printf '%s\n' 'Dotfiles Manager Module Tests'
printf '%s\n' '================================'

assert_file "$MODULE_DIR/module.yaml" "module manifest exists"
assert_executable "$MANAGER" "module owns the manager command"
assert_executable "$UI" "module owns the Textual control panel"
assert_file "$UI.lock" "module pins the control panel dependencies"
assert_file "$MODULE_DIR/assets/theme.example.tcss" "module owns the editable theme example"
assert_file "$MODULE_DIR/assets/hermes-skin.yaml" "module owns the optional Hermes skin"
assert_file "$MODULE_DIR/install/configure-hermes.sh.tmpl" "module owns Hermes skin reconciliation"
assert_file "$MODULE_DIR/targets/skhdrc.tmpl" "module owns Fn+Comma"
assert_file "$MODULE_DIR/targets/yabairc.tmpl" "module owns its scratchpad rule"

if yq -e '.id == "dotfiles-manager" and .dataKey == "modules.dotfilesManager"' \
    "$MODULE_DIR/module.yaml" >/dev/null 2>&1 \
  && yq -e '.requires.executables[] | select(. == "uv")' \
    "$MODULE_DIR/module.yaml" >/dev/null 2>&1 \
  && yq -e '.optional.executables[] | select(. == "hermes")' \
    "$MODULE_DIR/module.yaml" >/dev/null 2>&1 \
  && yq -e '.state.preserved[] | select(. == "~/.config/dotfiles-manager/theme.tcss")' \
    "$MODULE_DIR/module.yaml" >/dev/null 2>&1; then
  pass "manifest declares the human-first UI boundary"
else
  fail "manifest declares the human-first UI boundary" "uv required, Hermes optional, theme preserved" "$(cat "$MODULE_DIR/module.yaml")"
fi

assert_contains "$DOTFILES_DIR/home/dot_skhdrc.tmpl" \
  'includeTemplate "../modules/dotfiles-manager/targets/skhdrc.tmpl"' \
  "parent mounts one manager hotkey contribution"
assert_contains "$DOTFILES_DIR/home/dot_yabairc.tmpl" \
  'includeTemplate "../modules/dotfiles-manager/targets/yabairc.tmpl"' \
  "parent mounts one manager window-rule contribution"
assert_contains "$MANAGER" 'scratchpads_bin" open command' \
  "manager depends only on the public scratchpad transport"
assert_contains "$MANAGER" 'Ctrl+` Terminal' \
  "manager owns one persistent three-surface navigation row"
assert_contains "$MANAGER" '"$manager_command" ui' \
  "manager session starts on the control panel"
assert_contains "$MANAGER" 'dotfiles_pref hermes_skin dotfiles-manager' \
  "manager reads the selected Hermes skin from shared preferences"
assert_contains "$MANAGER" 'export AGENT_TODO_DIR="$todo_dir"' \
  "manager agent process receives a profile-private todo store"
assert_contains "$MODULE_DIR/assets/hermes-skin.yaml" 'banner_logo:' \
  "managed Hermes skin replaces the startup logo"
assert_contains "$MODULE_DIR/assets/hermes-skin.yaml" 'banner_hero:' \
  "managed Hermes skin replaces the startup hero art"

if bash -n "$MANAGER"; then
  pass "manager shell entrypoint parses"
else
  fail "manager shell entrypoint parses" "valid Bash" "syntax error"
fi

if "$UI" --self-test >/dev/null; then
  pass "Textual control panel passes headless interaction tests"
else
  fail "Textual control panel passes headless interaction tests" "successful self-test" "failed"
fi

# Source the guarded shell entrypoint and exercise the tmux orchestration
# without touching the user's live server.
source "$MANAGER"
root="$TEMP_ROOT/root"
mkdir -p "$root"
session="dotfiles-manager"
manager_command="/tmp/dotfiles-manager"
HAS_SESSION=0
TERMINAL_PRESENT=0
AGENT_PRESENT=0
: > "$ACTIONS_FILE"

tmux() {
  case "$*" in
    "has-session -t =dotfiles-manager")
      [[ "$HAS_SESSION" == 1 ]]
      ;;
    "new-session -d -P -F #{window_id} -e DOTFILES_TMUX_TEMPLATE=skip -s dotfiles-manager -c $root -n settings /tmp/dotfiles-manager ui")
      printf '%s\n' "$*" >> "$ACTIONS_FILE"
      printf '%s\n' '@1'
      ;;
    "list-windows -t =dotfiles-manager: -F #{window_id} #{window_name} #{@dotfiles_manager_role}")
      if [[ "$HAS_SESSION" == 1 ]]; then
        printf '%s\n' '@1 settings settings'
        [[ "$TERMINAL_PRESENT" == 1 ]] && printf '%s\n' '@2 terminal terminal'
      fi
      ;;
    "list-windows -t =dotfiles-manager: -F #{window_id} #{@dotfiles_manager_role}")
      printf '%s\n' '@1 settings'
      [[ "$TERMINAL_PRESENT" == 1 ]] && printf '%s\n' '@2 terminal'
      [[ "$AGENT_PRESENT" == 1 ]] && printf '%s\n' '@3 agent'
      return 0
      ;;
    "new-window -d -P -F #{window_id} -t =dotfiles-manager: -c $root -n terminal")
      printf '%s\n' "$*" >> "$ACTIONS_FILE"
      printf '%s\n' '@2'
      ;;
    "new-window -d -P -F #{window_id} -t =dotfiles-manager: -c $root -n agent /tmp/dotfiles-manager agent")
      printf '%s\n' "$*" >> "$ACTIONS_FILE"
      printf '%s\n' '@3'
      ;;
    *)
      printf '%s\n' "$*" >> "$ACTIONS_FILE"
      ;;
  esac
}

ensure_tmux_session
assert_action "new-session -d -P -F #{window_id} -e DOTFILES_TMUX_TEMPLATE=skip -s dotfiles-manager -c $root -n settings /tmp/dotfiles-manager ui" \
  "new manager sessions start directly in settings"
assert_action "new-window -d -P -F #{window_id} -t =dotfiles-manager: -c $root -n terminal" \
  "manager creates a persistent shell surface"
assert_action "set-option -t dotfiles-manager status on" \
  "manager session keeps its thin navigation row visible"
assert_contains "$ACTIONS_FILE" 'Ctrl+` Terminal' \
  "manager status names the direct terminal control"
assert_contains "$ACTIONS_FILE" 'Ctrl+1 Agent' \
  "manager status names the direct agent control"
assert_contains "$ACTIONS_FILE" 'Ctrl+2 Settings' \
  "manager status names the direct settings control"
assert_action "select-window -t @1" \
  "manager selects the control panel by default"
assert_no_action_fragment "-n agent" \
  "manager does not start Hermes eagerly"

: > "$ACTIONS_FILE"
HAS_SESSION=1
TERMINAL_PRESENT=1
select_manager_window agent
assert_action "new-window -d -P -F #{window_id} -t =dotfiles-manager: -c $root -n agent /tmp/dotfiles-manager agent" \
  "agent action creates Hermes on demand"
assert_action "set-option -w -t @3 @dotfiles_manager_role agent" \
  "on-demand agent carries stable manager metadata"
assert_action "select-window -t @3" \
  "agent action switches to its exact window ID"

: > "$ACTIONS_FILE"
select_manager_window terminal
assert_action "select-window -t @2" \
  "terminal action switches to the persistent shell by role"

# Validate the optional parent boundary: disabling and physically removing the
# child folder must leave unrelated scratchpad behavior renderable.
REMOVAL_SOURCE="$TEMP_ROOT/removal-source"
REMOVAL_HOME="$TEMP_ROOT/removal-home"
mkdir -p "$REMOVAL_SOURCE" "$REMOVAL_HOME"
cp -R "$DOTFILES_DIR/home" "$REMOVAL_SOURCE/home"
cp -R "$DOTFILES_DIR/modules" "$REMOVAL_SOURCE/modules"
cp "$DOTFILES_DIR/.chezmoiroot" "$REMOVAL_SOURCE/.chezmoiroot"
[[ ! -f "$DOTFILES_DIR/MODULE_PLATFORM.md" ]] || cp "$DOTFILES_DIR/MODULE_PLATFORM.md" "$REMOVAL_SOURCE/MODULE_PLATFORM.md"
rm -rf "$REMOVAL_SOURCE/modules/dotfiles-manager"
if chezmoi -S "$REMOVAL_SOURCE" -D "$REMOVAL_HOME" \
    --override-data '{"modules":{"dotfilesManager":{"enabled":false}}}' \
    apply --exclude=scripts,externals --force >/dev/null; then
  pass "parent renders after the disabled manager folder is removed"
else
  fail "parent renders after the disabled manager folder is removed" "successful cold render" "render failed"
fi
if grep -Fq 'fn - p : ~/bin/scratchpads open sessions' "$REMOVAL_HOME/.skhdrc"; then
  pass "removing the manager preserves the generic session scratchpad"
else
  fail "removing the manager preserves the generic session scratchpad" "Fn+P scratchpad binding" "missing"
fi
if ! grep -Fq 'dotfiles-manager open' "$REMOVAL_HOME/.skhdrc"; then
  pass "removing the manager removes only its own hotkey"
else
  fail "removing the manager removes only its own hotkey" "no manager hotkey" "binding remains"
fi

printf '\n================================\n'
printf 'Results: %d passed, %d failed\n' "$PASSED" "$FAILED"
printf '%s\n' '================================'

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
