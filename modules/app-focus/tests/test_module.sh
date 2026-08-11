#!/usr/bin/env bash

set -uo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$TEST_DIR")"
DOTFILES_DIR="$(cd "$MODULE_DIR/../.." && pwd)"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-app-focus-module.XXXXXX")"
DESTINATION="$TEMP_DIR/home"
STATE="$TEMP_DIR/state.db"
FAKE_BIN="$TEMP_DIR/bin"
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
    fail "$2" "$1" "missing or not executable"
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
    fail "$3" "text excluding $2" "$1"
  fi
}

render_profile() {
  local override_data="${1:-}"
  local -a args=(
    -S "$DOTFILES_DIR"
    -D "$DESTINATION"
    --persistent-state "$STATE"
  )
  if [[ -n "$override_data" ]]; then
    args+=(--override-data "$override_data")
  fi
  chezmoi "${args[@]}" apply --exclude=scripts,externals --force >/dev/null
}

echo "================================"
echo "App Focus Module Contract Tests"
echo "================================"

assert_file "$MODULE_DIR/module.yaml" "module manifest exists"
assert_file "$MODULE_DIR/config/defaults.toml" "module owns standard TOML defaults"
assert_file "$MODULE_DIR/lib/config.sh" "module owns its config adapter"
assert_file "$MODULE_DIR/bin/hotkeys" "module owns the action router"
assert_executable "$MODULE_DIR/bin/focus-open-tmux-window.sh" "module owns the open tmux window focus helper"
assert_file "$DOTFILES_DIR/home/dot_config/skhd/executable_focus-open-tmux-window.sh.tmpl" "open tmux window focus helper has a thin bridge"
assert_file "$MODULE_DIR/bin/focus_app.sh" "module owns app resolution and focus policy"
assert_file "$MODULE_DIR/bin/app-mru.sh" "module owns MRU focus state"
assert_file "$MODULE_DIR/targets/skhd-apps.conf.tmpl" "module owns app focus bindings"
assert_file "$MODULE_DIR/targets/skhd-modes.conf.tmpl" "module owns mode bindings"
assert_file "$MODULE_DIR/targets/yabai-signals.sh.tmpl" "module owns its yabai signal"

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

if [[ "$(yq -p=toml -o=yaml -r '.apps.editor' "$MODULE_DIR/config/defaults.toml")" == "VSCodium" \
  && "$(yq -p=toml -o=yaml -r '.apps.terminal' "$MODULE_DIR/config/defaults.toml")" == "Ghostty" \
  && "$(yq -p=toml -o=yaml -r '.modes.zen_blocked_slots | join(",")' "$MODULE_DIR/config/defaults.toml")" == "3,4,5" ]]; then
  pass "TOML defaults preserve editor, terminal, and zen behavior"
else
  fail "TOML defaults preserve editor, terminal, and zen behavior" "VSCodium/Ghostty/3,4,5" "defaults differ"
fi

cat >"$TEMP_DIR/custom.toml" <<'EOF'
schema_version = 1
[apps]
editor = "Zed"
terminal = "WezTerm"
[modes]
state_directory = ".state/app-focus"
zen_blocked_slots = [8, 9]
[integrations]
notification_command = ".local/bin/desktop-notify"
EOF
CUSTOM_VALUES=$(HOME="$TEMP_DIR/config-home" APP_FOCUS_CONFIG_FILE="$TEMP_DIR/custom.toml" \
  bash -c 'source "$1"; printf "%s|%s|%s|%s\n" \
    "$(app_focus_config_string .apps.editor fallback)" \
    "$(app_focus_config_string .apps.terminal fallback)" \
    "$(app_focus_config_list .modes.zen_blocked_slots fallback)" \
    "$(app_focus_state_directory)"' _ "$MODULE_DIR/lib/config.sh")
if [[ "$CUSTOM_VALUES" == "Zed|WezTerm|8 9|$TEMP_DIR/config-home/.state/app-focus" ]]; then
  pass "standard TOML overrides drive runtime defaults"
else
  fail "standard TOML overrides drive runtime defaults" "configured apps, slots, and state path" "$CUSTOM_VALUES"
fi

assert_contains "$DOTFILES_DIR/home/bin/executable_hotkeys.tmpl" \
  'includeTemplate "../modules/app-focus/bin/hotkeys"' \
  "stable hotkeys path is a thin module bridge"
assert_contains "$DOTFILES_DIR/home/dot_skhdrc.tmpl" \
  'includeTemplate "../modules/app-focus/targets/skhd-apps.conf.tmpl"' \
  "skhd mounts app bindings through one contribution"
assert_contains "$DOTFILES_DIR/home/dot_yabairc.tmpl" \
  'includeTemplate "../modules/app-focus/targets/yabai-signals.sh.tmpl"' \
  "yabai mounts the MRU signal through one contribution"

mkdir -p "$FAKE_BIN" "$TEMP_DIR/runtime-home/.config/skhd"
cat >"$TEMP_DIR/notify" <<'EOF'
#!/usr/bin/env bash
printf '%s|%s\n' "$1" "$2" >>"$APP_FOCUS_TEST_LOG"
EOF
cat >"$TEMP_DIR/runtime-home/.config/skhd/focus_app.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$APP_FOCUS_TEST_FOCUS_LOG"
EOF
chmod +x "$TEMP_DIR/notify" "$TEMP_DIR/runtime-home/.config/skhd/focus_app.sh"

RUNTIME_ENV=(
  HOME="$TEMP_DIR/runtime-home"
  APP_FOCUS_CONFIG_FILE="$MODULE_DIR/config/defaults.toml"
  APP_FOCUS_CONFIG_LIB="$MODULE_DIR/lib/config.sh"
  APP_FOCUS_NOTIFY_COMMAND="$TEMP_DIR/notify"
  APP_FOCUS_TEST_LOG="$TEMP_DIR/notifications.log"
  APP_FOCUS_TEST_FOCUS_LOG="$TEMP_DIR/focus.log"
)

if env "${RUNTIME_ENV[@]}" "$MODULE_DIR/bin/hotkeys" zen status | grep -Fxq off; then
  pass "zen mode defaults off"
else
  fail "zen mode defaults off" "off" "unexpected status"
fi

env "${RUNTIME_ENV[@]}" "$MODULE_DIR/bin/hotkeys" zen toggle
if [[ "$(<"$TEMP_DIR/runtime-home/.config/skhd/zen_mode")" == "on" ]]; then
  pass "zen toggle preserves the existing state path"
else
  fail "zen toggle preserves the existing state path" "on" "missing or different state"
fi

: >"$TEMP_DIR/focus.log"
env "${RUNTIME_ENV[@]}" "$MODULE_DIR/bin/hotkeys" app-focus 3 "Microsoft Teams"
if [[ ! -s "$TEMP_DIR/focus.log" ]]; then
  pass "zen mode blocks configured app slot 3"
else
  fail "zen mode blocks configured app slot 3" "no focus invocation" "$(cat "$TEMP_DIR/focus.log")"
fi

env "${RUNTIME_ENV[@]}" "$MODULE_DIR/bin/hotkeys" app-focus 2 @editor
if grep -Fxq '@editor' "$TEMP_DIR/focus.log"; then
  pass "zen mode leaves editor focus active"
else
  fail "zen mode leaves editor focus active" "@editor delegation" "$(cat "$TEMP_DIR/focus.log")"
fi

env "${RUNTIME_ENV[@]}" "$MODULE_DIR/bin/hotkeys" presentation toggle
if [[ "$(<"$TEMP_DIR/runtime-home/.config/skhd/presentation_mode")" == "on" ]]; then
  pass "presentation toggle preserves the existing state path"
else
  fail "presentation toggle preserves the existing state path" "on" "missing or different state"
fi

if grep -Fq 'skhd|Zen mode on' "$TEMP_DIR/notifications.log" \
  && grep -Fq 'skhd|Presentation mode on' "$TEMP_DIR/notifications.log"; then
  pass "mode changes use the optional notification adapter"
else
  fail "mode changes use the optional notification adapter" "zen and presentation notices" "$(cat "$TEMP_DIR/notifications.log")"
fi

if HOME="$TEMP_DIR/runtime-home" APP_FOCUS_CONFIG_FILE="$MODULE_DIR/config/defaults.toml" \
  "$MODULE_DIR/bin/hotkeys" --help >/dev/null; then
  pass "copied module command discovers its child-local config adapter"
else
  fail "copied module command discovers its child-local config adapter" "successful help" "command failed"
fi

MRU_HOME="$TEMP_DIR/mru-home"
MRU_STATE="$TEMP_DIR/mru-state"
MRU_LOG="$TEMP_DIR/mru-yabai.log"
mkdir -p "$MRU_HOME" "$MRU_STATE" "$FAKE_BIN"
cat >"$FAKE_BIN/yabai" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  '-m query --windows')
    cat <<'JSON'
[
  {"id":100,"app":"Ghostty","space":1,"display":1,"is-minimized":false,"is-hidden":false,"scratchpad":""},
  {"id":200,"app":"Ghostty","space":1,"display":1,"is-minimized":false,"is-hidden":false,"scratchpad":"terminal"},
  {"id":300,"app":"Ghostty","space":1,"display":1,"is-minimized":false,"is-hidden":false,"scratchpad":null},
  {"id":400,"app":"Ghostty","space":1,"display":1,"is-minimized":false,"is-hidden":false,"scratchpad":""}
]
JSON
    ;;
  '-m query --windows --window')
    printf '{"id":%s,"app":"Ghostty","space":1,"display":1,"is-minimized":false,"is-hidden":false,"scratchpad":""}\n' \
      "${APP_FOCUS_TEST_FOCUSED_ID:-100}"
    ;;
  '-m query --spaces --space') printf '%s\n' '{"index":1}' ;;
  '-m query --displays --display') printf '%s\n' '{"index":1}' ;;
  *) printf '%s\n' "$*" >>"$APP_FOCUS_TEST_YABAI_LOG" ;;
esac
EOF
chmod +x "$FAKE_BIN/yabai"
printf '200\n100\n999\n' >"$MRU_STATE/Ghostty.ids"

MRU_ENV=(
  HOME="$MRU_HOME"
  PATH="$FAKE_BIN:$PATH"
  APP_FOCUS_CONFIG_FILE="$MODULE_DIR/config/defaults.toml"
  APP_FOCUS_CONFIG_LIB="$MODULE_DIR/lib/config.sh"
  APP_FOCUS_TEST_YABAI_LOG="$MRU_LOG"
  APP_MRU_DIR="$MRU_STATE"
)

MRU_OUTPUT=$(env "${MRU_ENV[@]}" bash -c 'source "$1"; app_mru_list Ghostty' _ "$MODULE_DIR/bin/app-mru.sh")
if [[ "$MRU_OUTPUT" == $'100\n300\n400' ]]; then
  pass "MRU state prunes scratchpads and stale window IDs"
else
  fail "MRU state prunes scratchpads and stale window IDs" $'100\n300\n400' "$MRU_OUTPUT"
fi

: >"$MRU_LOG"
env "${MRU_ENV[@]}" bash -c 'source "$1"; app_mru_cycle Ghostty "" true' _ "$MODULE_DIR/bin/app-mru.sh"
if [[ ! -s "$MRU_LOG" ]]; then
  pass "presentation mode keeps an already focused app window stable"
else
  fail "presentation mode keeps an already focused app window stable" "no focus command" "$(cat "$MRU_LOG")"
fi

env "${MRU_ENV[@]}" bash -c 'source "$1"; app_mru_cycle Ghostty "" false' _ "$MODULE_DIR/bin/app-mru.sh"
if grep -Fxq -- '-m window --focus 400' "$MRU_LOG" \
  && [[ "$(<"$MRU_STATE/Ghostty.ids")" == $'400\n100\n300' ]]; then
  pass "normal mode focuses the LRU window and promotes it"
else
  fail "normal mode focuses the LRU window and promotes it" \
    $'focus window 400 and order 400\n100\n300' \
    "$(cat "$MRU_LOG"; printf 'order: '; tr '\n' ' ' <"$MRU_STATE/Ghostty.ids")"
fi

if grep -Eq '^400 [0-9]+$' "$MRU_STATE/.suppress-focus"; then
  pass "MRU cycling suppresses its resulting focus signal"
else
  fail "MRU cycling suppresses its resulting focus signal" "target 400 with expiry" "$(cat "$MRU_STATE/.suppress-focus" 2>/dev/null || true)"
fi

env "${MRU_ENV[@]}" APP_FOCUS_TEST_FOCUSED_ID=400 \
  bash -c 'source "$1"; app_mru_update_from_focus' _ "$MODULE_DIR/bin/app-mru.sh"
if [[ "$(<"$MRU_STATE/Ghostty.ids")" == $'400\n100\n300' && ! -e "$MRU_STATE/.suppress-focus" ]]; then
  pass "programmatic focus preserves the explicit LRU promotion"
else
  fail "programmatic focus preserves the explicit LRU promotion" $'400\n100\n300 and no marker' "$(cat "$MRU_STATE/Ghostty.ids"; ls "$MRU_STATE/.suppress-focus" 2>/dev/null || true)"
fi

env "${MRU_ENV[@]}" APP_FOCUS_TEST_FOCUSED_ID=300 \
  bash -c 'source "$1"; app_mru_update_from_focus' _ "$MODULE_DIR/bin/app-mru.sh"
if [[ "$(<"$MRU_STATE/Ghostty.ids")" == $'300\n400\n100' ]]; then
  pass "manual focus still promotes a window in MRU order"
else
  fail "manual focus still promotes a window in MRU order" $'300\n400\n100' "$(<"$MRU_STATE/Ghostty.ids")"
fi

: >"$MRU_LOG"
env "${MRU_ENV[@]}" APP_FOCUS_TEST_FOCUSED_ID=300 \
  bash -c 'source "$1"; app_mru_cycle Ghostty "" false' _ "$MODULE_DIR/bin/app-mru.sh"
if grep -Fxq -- '-m window --focus 100' "$MRU_LOG" \
  && [[ "$(<"$MRU_STATE/Ghostty.ids")" == $'100\n300\n400' ]]; then
  pass "repeated app switching advances through LRU order"
else
  fail "repeated app switching advances through LRU order" \
    $'focus window 100 and order 100\n300\n400' \
    "$(cat "$MRU_LOG"; printf 'order: '; tr '\n' ' ' <"$MRU_STATE/Ghostty.ids")"
fi

TMUX_WINDOW_LOG="$TEMP_DIR/tmux-window-yabai.log"
cat >"$FAKE_BIN/yabai" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  '-m query --windows')
    cat <<'JSON'
[
  {"id":10,"app":"Ghostty","title":"uvx marimo@latest edit","is-minimized":false,"scratchpad":""},
  {"id":20,"app":"Ghostty","title":"tmux","is-minimized":false,"scratchpad":"terminal"},
  {"id":50,"app":"Ghostty","title":"tmux","is-minimized":true,"scratchpad":""},
  {"id":100,"app":"Ghostty","title":"tmux · project","is-minimized":false,"scratchpad":""},
  {"id":200,"app":"VSCodium","title":"tmux","is-minimized":false,"scratchpad":""}
]
JSON
    ;;
  '-m query --windows --window')
    printf '{"id":%s}\n' "${FAKE_CURRENT_WINDOW_ID:-50}"
    ;;
  *) printf '%s\n' "$*" >>"$APP_FOCUS_TEST_YABAI_LOG" ;;
esac
EOF
chmod +x "$FAKE_BIN/yabai"
: >"$TMUX_WINDOW_LOG"
HOME="$MRU_HOME" PATH="$FAKE_BIN:$PATH" APP_FOCUS_TEST_YABAI_LOG="$TMUX_WINDOW_LOG" \
  "$MODULE_DIR/bin/focus-open-tmux-window.sh" 1
HOME="$MRU_HOME" PATH="$FAKE_BIN:$PATH" APP_FOCUS_TEST_YABAI_LOG="$TMUX_WINDOW_LOG" \
  "$MODULE_DIR/bin/focus-open-tmux-window.sh" 2
if [[ "$(cat "$TMUX_WINDOW_LOG")" == $'-m window --focus 50\n-m window --focus 100' ]]; then
  pass "Fn tmux slots use open normal Ghostty windows in creation order"
else
  fail "Fn tmux slots use open normal Ghostty windows in creation order" "focus 50 then 100" "$(cat "$TMUX_WINDOW_LOG")"
fi
if HOME="$MRU_HOME" PATH="$FAKE_BIN:$PATH" APP_FOCUS_TEST_YABAI_LOG="$TMUX_WINDOW_LOG" \
  "$MODULE_DIR/bin/focus-open-tmux-window.sh" 3 >/dev/null 2>&1; then
  fail "Fn tmux slots reject missing open windows" "slot 3 failure" "command succeeded"
else
  pass "Fn tmux slots reject missing open windows"
fi

: >"$TMUX_WINDOW_LOG"
HOME="$MRU_HOME" PATH="$FAKE_BIN:$PATH" APP_FOCUS_TEST_YABAI_LOG="$TMUX_WINDOW_LOG" \
  FAKE_CURRENT_WINDOW_ID=50 "$MODULE_DIR/bin/focus-open-tmux-window.sh" cycle
HOME="$MRU_HOME" PATH="$FAKE_BIN:$PATH" APP_FOCUS_TEST_YABAI_LOG="$TMUX_WINDOW_LOG" \
  FAKE_CURRENT_WINDOW_ID=100 "$MODULE_DIR/bin/focus-open-tmux-window.sh" cycle
if [[ "$(cat "$TMUX_WINDOW_LOG")" == $'-m window --focus 100\n-m window --focus 50' ]]; then
  pass "Fn+Tab cycles and wraps across open normal tmux windows"
else
  fail "Fn+Tab cycles and wraps across open normal tmux windows" "focus 100 then 50" "$(cat "$TMUX_WINDOW_LOG")"
fi

mkdir -p "$DESTINATION"
if render_profile; then
  pass "enabled profile renders in a cold home"
else
  fail "enabled profile renders in a cold home" "successful chezmoi apply" "apply failed"
fi

assert_executable "$DESTINATION/bin/hotkeys" "enabled profile installs hotkeys executable"
assert_executable "$DESTINATION/.config/skhd/focus_app.sh" "enabled profile installs focus helper"
assert_executable "$DESTINATION/.config/skhd/app-mru.sh" "enabled profile installs MRU helper"
assert_executable "$DESTINATION/.config/skhd/focus-open-tmux-window.sh" "enabled profile installs open tmux window focus helper"
assert_file "$DESTINATION/.config/app-focus/config.toml" "enabled profile installs TOML config"
assert_file "$DESTINATION/.config/app-focus/config.sh" "enabled profile installs config adapter"
assert_contains "$DESTINATION/.skhdrc" 'alt - 0x32 : ~/.config/skhd/focus_app.sh "Ghostty"' "enabled profile preserves Alt+Backtick"
assert_contains "$DESTINATION/.skhdrc" 'alt - 1 : ~/bin/hotkeys app-focus 1 "@browser"' "enabled profile preserves browser slot"
assert_contains "$DESTINATION/.skhdrc" 'alt - 2 : ~/bin/hotkeys app-focus 2 "@editor"' "enabled profile preserves editor slot"
assert_contains "$DESTINATION/.skhdrc" 'alt - 3 : ~/bin/hotkeys app-focus 3 "Microsoft Teams"' "enabled profile preserves Teams slot"
assert_contains "$DESTINATION/.skhdrc" 'alt - 4 : ~/bin/hotkeys app-focus 4 "Slack"' "enabled profile preserves Slack slot"
assert_contains "$DESTINATION/.skhdrc" 'fn - 1 : ~/.config/skhd/focus-open-tmux-window.sh 1' "enabled profile maps Fn+1 to the first open tmux window"
assert_contains "$DESTINATION/.skhdrc" 'fn - 9 : ~/.config/skhd/focus-open-tmux-window.sh 9' "enabled profile maps Fn+9 to the ninth open tmux window"
assert_contains "$DESTINATION/.skhdrc" 'fn - tab : ~/.config/skhd/focus-open-tmux-window.sh cycle' "enabled profile maps Fn+Tab to tmux window cycling"
assert_contains "$DESTINATION/.skhdrc" 'alt - 0x2A : ~/bin/hotkeys presentation toggle' "enabled profile preserves presentation toggle"
assert_contains "$DESTINATION/.skhdrc" 'alt + shift - 0x2A : ~/bin/hotkeys zen toggle' "enabled profile preserves zen toggle"
assert_contains "$DESTINATION/.skhdrc" 'alt + shift - 0x32 : ~/bin/hotkeys terminal new' "enabled profile preserves terminal launch"
assert_contains "$DESTINATION/.yabairc" 'signal --add label=app_mru_update' "enabled profile registers MRU tracking"

if render_profile '{"modules":{"appFocus":{"enabled":false}}}'; then
  pass "disabled profile re-renders in the same cold home"
else
  fail "disabled profile re-renders in the same cold home" "successful chezmoi apply" "apply failed"
fi

assert_absent "$DESTINATION/bin/hotkeys" "disabled profile removes hotkeys"
assert_absent "$DESTINATION/.config/skhd/focus_app.sh" "disabled profile removes focus helper"
assert_absent "$DESTINATION/.config/skhd/app-mru.sh" "disabled profile removes MRU helper"
assert_absent "$DESTINATION/.config/skhd/focus-open-tmux-window.sh" "disabled profile removes open tmux window focus helper"
assert_absent "$DESTINATION/.config/app-focus/config.toml" "disabled profile removes TOML config"
assert_absent "$DESTINATION/.config/app-focus/config.sh" "disabled profile removes config adapter"
assert_not_contains "$DESTINATION/.skhdrc" 'hotkeys app-focus' "disabled profile removes app bindings"
assert_not_contains "$DESTINATION/.skhdrc" 'hotkeys presentation' "disabled profile removes presentation binding"
assert_not_contains "$DESTINATION/.skhdrc" 'hotkeys zen' "disabled profile removes zen binding"
assert_not_contains "$DESTINATION/.skhdrc" 'hotkeys terminal new' "disabled profile removes module terminal binding"
assert_not_contains "$DESTINATION/.skhdrc" 'focus-open-tmux-window.sh' "disabled profile removes Fn tmux window slots"
assert_not_contains "$DESTINATION/.yabairc" 'signal --add label=app_mru_update' "disabled profile removes MRU registration"
assert_contains "$DESTINATION/.yabairc" 'signal --remove "app_mru_update"' "disabled profile cleans a previously registered signal"
assert_contains "$DESTINATION/.skhdrc" 'fn - 0x2B : ~/bin/scratchpads open codex' "disabled profile preserves unrelated scratchpads"
assert_contains "$DESTINATION/.yabairc" 'signal --add label=tile_pip_on_create' "disabled profile preserves unrelated yabai signals"

printf '\n================================\n'
printf 'Results: %s passed, %s failed\n' "$PASSED" "$FAILED"
printf '================================\n'

exit "$FAILED"
