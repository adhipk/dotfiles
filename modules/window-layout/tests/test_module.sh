#!/usr/bin/env bash

set -uo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$TEST_DIR")"
DOTFILES_DIR="$(cd "$MODULE_DIR/../.." && pwd)"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-window-layout-module.XXXXXX")"
DESTINATION="$TEMP_DIR/home"
STATE="$TEMP_DIR/state.db"
FAKE_BIN="$TEMP_DIR/bin"
PASSED=0
FAILED=0

cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT

pass() { printf '  ✓ %s\n' "$1"; PASSED=$((PASSED + 1)); }
fail() {
  printf '  ✗ %s\n    Expected: %s\n    Actual:   %s\n' "$1" "$2" "$3"
  FAILED=$((FAILED + 1))
}
assert_file() { [[ -f "$1" ]] && pass "$2" || fail "$2" "$1" "missing"; }
assert_executable() { [[ -x "$1" ]] && pass "$2" || fail "$2" "executable $1" "missing or not executable"; }
assert_absent() { [[ ! -e "$1" ]] && pass "$2" || fail "$2" "absent" "$1 exists"; }
assert_contains() { grep -Fq -- "$2" "$1" && pass "$3" || fail "$3" "text containing $2" "$1"; }
assert_not_contains() { ! grep -Fq -- "$2" "$1" && pass "$3" || fail "$3" "text excluding $2" "$1"; }

render_profile() {
  local enabled="$1"
  mkdir -p "$DESTINATION"
  chezmoi -S "$DOTFILES_DIR" -D "$DESTINATION" --persistent-state "$STATE" \
    --override-data "{\"modules\":{\"windowLayout\":{\"enabled\":$enabled}}}" \
    apply --exclude=scripts,externals --force >/dev/null
}

printf '================================\n'
printf 'Window Layout Module Contract Tests\n'
printf '================================\n'

assert_file "$MODULE_DIR/module.yaml" "module manifest exists"
assert_executable "$MODULE_DIR/bin/snap_window.sh" "module owns half-screen snap helper"
assert_executable "$MODULE_DIR/bin/float-prefs" "module owns remembered float helper"
assert_file "$MODULE_DIR/targets/skhdrc.tmpl" "module owns window-layout bindings"
assert_file "$MODULE_DIR/targets/yabairc.tmpl" "module owns yabai layout policy"
assert_file "$MODULE_DIR/targets/yabairc-restore.tmpl" "module owns float-preference restoration"

if yq eval '.' "$MODULE_DIR/module.yaml" >/dev/null 2>&1; then
  pass "module manifest parses as YAML"
else
  fail "module manifest parses as YAML" "valid YAML" "parse error"
fi

if bash -n "$MODULE_DIR/bin/snap_window.sh" \
  && bash -n "$MODULE_DIR/bin/float-prefs" \
  && bash -n "$MODULE_DIR/targets/yabairc.tmpl"; then
  pass "module shell sources parse"
else
  fail "module shell sources parse" "valid shell" "syntax error"
fi

assert_contains "$DOTFILES_DIR/home/dot_config/skhd/executable_snap_window.sh.tmpl" \
  'includeTemplate "../modules/window-layout/bin/snap_window.sh"' \
  "stable snap path is a thin module bridge"
assert_contains "$DOTFILES_DIR/home/dot_config/yabai/executable_float-prefs.tmpl" \
  'includeTemplate "../modules/window-layout/bin/float-prefs"' \
  "stable float path is a thin module bridge"
assert_contains "$DOTFILES_DIR/home/dot_skhdrc.tmpl" \
  'includeTemplate "../modules/window-layout/targets/skhdrc.tmpl"' \
  "skhd has one guarded window-layout mount"
assert_contains "$DOTFILES_DIR/home/dot_yabairc.tmpl" \
  'includeTemplate "../modules/window-layout/targets/yabairc.tmpl"' \
  "yabai has a guarded layout-policy mount"

# Exercise the two runtime helpers against a deterministic yabai adapter.
mkdir -p "$FAKE_BIN" "$TEMP_DIR/runtime-home/.config/skhd"
cat >"$FAKE_BIN/yabai" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  '-m query --displays --display')
    printf '%s\n' '{"frame":{"w":1200}}'
    ;;
  '-m query --windows --window')
    printf '%s\n' '{"id":42,"app":"Notes","title":"Todo","scratchpad":"","is-floating":false,"has-focus":true,"frame":{"w":800}}'
    ;;
  '-m query --windows --window 42')
    printf '%s\n' '{"id":42,"is-floating":false}'
    ;;
  '-m query --windows')
    printf '%s\n' '[{"id":42,"app":"Notes","title":"Todo","has-focus":true}]'
    ;;
  '-m rule --list')
    printf '%s\n' '[]'
    ;;
  *)
    printf '%s\n' "$*" >>"$WINDOW_LAYOUT_YABAI_LOG"
    ;;
esac
EOF
cat >"$TEMP_DIR/runtime-home/.config/skhd/notify.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s|%s\n' "$1" "$2" >>"$WINDOW_LAYOUT_NOTIFY_LOG"
EOF
chmod +x "$FAKE_BIN/yabai" "$TEMP_DIR/runtime-home/.config/skhd/notify.sh"

RUNTIME_ENV=(
  HOME="$TEMP_DIR/runtime-home"
  PATH="$FAKE_BIN:$PATH"
  WINDOW_LAYOUT_YABAI_LOG="$TEMP_DIR/yabai.log"
  WINDOW_LAYOUT_NOTIFY_LOG="$TEMP_DIR/notify.log"
)

: >"$TEMP_DIR/yabai.log"
env "${RUNTIME_ENV[@]}" "$MODULE_DIR/bin/snap_window.sh" left
if grep -Fxq -- '-m window --warp west' "$TEMP_DIR/yabai.log" \
  && grep -Fxq -- '-m window --resize right:-200:0' "$TEMP_DIR/yabai.log"; then
  pass "snap left preserves warp-first half-screen behavior"
else
  fail "snap left preserves warp-first half-screen behavior" "west warp and -200 resize" "$(cat "$TEMP_DIR/yabai.log")"
fi

env "${RUNTIME_ENV[@]}" "$MODULE_DIR/bin/snap_window.sh" right
if grep -Fxq -- '-m window --warp east' "$TEMP_DIR/yabai.log"; then
  pass "snap right preserves eastward warp behavior"
else
  fail "snap right preserves eastward warp behavior" "east warp" "$(cat "$TEMP_DIR/yabai.log")"
fi

: >"$TEMP_DIR/yabai.log"
env "${RUNTIME_ENV[@]}" "$MODULE_DIR/bin/float-prefs" toggle
PREFS="$TEMP_DIR/runtime-home/.config/yabai/floating-windows.json"
if jq -e '.["Notes|Todo"].grid == "6:6:1:1:4:4"' "$PREFS" >/dev/null \
  && grep -Fq -- '-m rule --add label=float_pref_' "$TEMP_DIR/yabai.log" \
  && grep -Fxq -- '-m window 42 --grid 6:6:1:1:4:4' "$TEMP_DIR/yabai.log"; then
  pass "float toggle persists and applies the existing per-title grid"
else
  fail "float toggle persists and applies the existing per-title grid" "saved grid, rule, and window grid" "$(cat "$TEMP_DIR/yabai.log")"
fi

env "${RUNTIME_ENV[@]}" "$MODULE_DIR/bin/float-prefs" toggle
if [[ "$(jq 'length' "$PREFS")" == "0" ]] \
  && grep -Fq 'yabai Float|Tiled: Todo' "$TEMP_DIR/notify.log"; then
  pass "second float toggle removes the remembered preference"
else
  fail "second float toggle removes the remembered preference" "empty store and tiled notice" "$(cat "$PREFS")"
fi

if render_profile true; then
  pass "enabled profile renders in a cold home"
else
  fail "enabled profile renders in a cold home" "successful chezmoi apply" "apply failed"
fi
assert_executable "$DESTINATION/.config/skhd/snap_window.sh" "enabled profile installs snap helper"
assert_executable "$DESTINATION/.config/yabai/float-prefs" "enabled profile installs float helper"
assert_contains "$DESTINATION/.skhdrc" 'ctrl + alt - h : ~/.config/skhd/snap_window.sh left' "enabled profile preserves snap binding"
assert_contains "$DESTINATION/.skhdrc" 'ctrl + alt + shift - h : yabai -m window --swap west' "enabled profile preserves swap binding"
assert_contains "$DESTINATION/.skhdrc" 'ctrl + alt - w : yabai -m window --close' "enabled profile preserves close binding"
assert_contains "$DESTINATION/.yabairc" 'yabai -m config layout                       bsp' "enabled profile preserves BSP layout"
assert_contains "$DESTINATION/.yabairc" 'label="window_layout_system_settings" app="^System Settings$" manage=off' "enabled profile preserves non-tileable rules"
assert_contains "$DESTINATION/.yabairc" '"$HOME/.config/yabai/float-prefs" apply-rules || true' "enabled profile restores remembered floats"

if render_profile false; then
  pass "disabled profile re-renders in the same cold home"
else
  fail "disabled profile re-renders in the same cold home" "successful chezmoi apply" "apply failed"
fi
assert_absent "$DESTINATION/.config/skhd/snap_window.sh" "disabled profile removes snap helper"
assert_absent "$DESTINATION/.config/yabai/float-prefs" "disabled profile removes float helper"
assert_not_contains "$DESTINATION/.skhdrc" 'snap_window.sh' "disabled profile removes window-layout bindings"
assert_not_contains "$DESTINATION/.skhdrc" 'window --close' "disabled profile removes close binding"
assert_not_contains "$DESTINATION/.yabairc" 'rule --add label="window_layout_' "disabled profile removes static layout rules"
assert_not_contains "$DESTINATION/.yabairc" 'float-prefs" apply-rules' "disabled profile removes float restoration"
assert_contains "$DESTINATION/.yabairc" 'rule --remove "$label"' "disabled profile retains runtime rule cleanup"
assert_contains "$DESTINATION/.skhdrc" 'alt - n : ~/.config/yabai/create-space auto' "disabled profile preserves space management"
assert_contains "$DESTINATION/.skhdrc" 'hotkeys app-focus 1 "@browser"' "disabled profile preserves app focus"
assert_contains "$DESTINATION/.yabairc" 'signal --add label=tile_pip_on_create' "disabled profile preserves PiP"

# Simulate disable followed by physical source removal.
REMOVAL_SOURCE="$TEMP_DIR/removal-source"
REMOVAL_HOME="$TEMP_DIR/removal-home"
mkdir -p "$REMOVAL_SOURCE" "$REMOVAL_HOME"
cp -R "$DOTFILES_DIR/home" "$REMOVAL_SOURCE/home"
cp -R "$DOTFILES_DIR/modules" "$REMOVAL_SOURCE/modules"
cp "$DOTFILES_DIR/.chezmoiroot" "$REMOVAL_SOURCE/.chezmoiroot"
rm -rf "$REMOVAL_SOURCE/modules/window-layout"
if chezmoi -S "$REMOVAL_SOURCE" -D "$REMOVAL_HOME" \
  --persistent-state "$TEMP_DIR/removal-state.db" \
  --override-data '{"modules":{"windowLayout":{"enabled":false}}}' \
  apply --exclude=scripts,externals --force >/dev/null 2>&1; then
  pass "parent renders after the disabled module folder is removed"
else
  fail "parent renders after the disabled module folder is removed" "successful render" "render failed"
fi
assert_absent "$REMOVAL_HOME/.config/skhd/snap_window.sh" "physical removal leaves no snap helper"
assert_absent "$REMOVAL_HOME/.config/yabai/float-prefs" "physical removal leaves no float helper"
assert_contains "$REMOVAL_HOME/.skhdrc" 'alt - n : ~/.config/yabai/create-space auto' "physical removal preserves space management"
assert_contains "$REMOVAL_HOME/.yabairc" 'signal --add label=tile_pip_on_create' "physical removal preserves PiP behavior"

printf '\n================================\n'
printf 'Results: %s passed, %s failed\n' "$PASSED" "$FAILED"
printf '================================\n'
exit "$FAILED"
