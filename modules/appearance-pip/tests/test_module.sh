#!/usr/bin/env bash

set -uo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$TEST_DIR")"
DOTFILES_DIR="$(cd "$MODULE_DIR/../.." && pwd)"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-appearance-pip-module.XXXXXX")"
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
    --override-data "{\"modules\":{\"appearancePip\":{\"enabled\":$enabled}}}" \
    apply --exclude=scripts,externals --force >/dev/null
}

printf '================================\n'
printf 'Appearance and PiP Module Contract Tests\n'
printf '================================\n'

assert_file "$MODULE_DIR/module.yaml" "module manifest exists"
assert_executable "$MODULE_DIR/bin/tmux-border-accent" "module owns border-accent command"
assert_executable "$MODULE_DIR/bin/tile-pip-window" "module owns PiP tiling helper"
assert_file "$MODULE_DIR/targets/yabairc-signals.tmpl" "module owns PiP signals"
assert_file "$MODULE_DIR/targets/yabairc-style.tmpl" "module owns appearance policy"
assert_file "$MODULE_DIR/targets/yabairc-display-padding.tmpl" "module owns per-space visual padding"
assert_file "$MODULE_DIR/targets/yabairc-launch.tmpl" "module owns border launch"
assert_file "$MODULE_DIR/targets/tmux.conf.tmpl" "module owns border-update hooks"
assert_file "$MODULE_DIR/tests/test_tmux_border_accent.sh" "module owns focused border tests"

if yq eval '.' "$MODULE_DIR/module.yaml" >/dev/null 2>&1; then
  pass "module manifest parses as YAML"
else
  fail "module manifest parses as YAML" "valid YAML" "parse error"
fi

if bash -n "$MODULE_DIR/bin/tmux-border-accent" \
  && bash -n "$MODULE_DIR/bin/tile-pip-window" \
  && bash -n "$MODULE_DIR/targets/yabairc-style.tmpl" \
  && bash -n "$MODULE_DIR/targets/yabairc-display-padding.tmpl" \
  && bash -n "$MODULE_DIR/targets/yabairc-launch.tmpl"; then
  pass "module shell sources parse"
else
  fail "module shell sources parse" "valid shell" "syntax error"
fi

assert_contains "$DOTFILES_DIR/home/bin/executable_tmux-border-accent.tmpl" \
  'includeTemplate "../modules/appearance-pip/bin/tmux-border-accent"' \
  "stable border command is a thin module bridge"
assert_contains "$DOTFILES_DIR/home/dot_config/yabai/executable_tile-pip-window.tmpl" \
  'includeTemplate "../modules/appearance-pip/bin/tile-pip-window"' \
  "stable PiP helper is a thin module bridge"
assert_contains "$DOTFILES_DIR/home/dot_yabairc.tmpl" \
  'includeTemplate "../modules/appearance-pip/targets/yabairc-style.tmpl"' \
  "yabai conditionally mounts appearance policy"
assert_contains "$DOTFILES_DIR/home/dot_tmux.conf.tmpl" \
  'includeTemplate "../modules/appearance-pip/targets/tmux.conf.tmpl"' \
  "tmux conditionally mounts border hooks"

# PiP behavior uses the public yabai command surface and remains independent of
# the rest of the parent source tree.
mkdir -p "$FAKE_BIN"
cat >"$FAKE_BIN/yabai" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == '-m query --windows --window '* ]]; then
  printf '%s\n' "$FAKE_PIP_WINDOW_JSON"
else
  printf '%s\n' "$*" >>"$APPEARANCE_PIP_YABAI_LOG"
fi
EOF
chmod +x "$FAKE_BIN/yabai"
PIP_ENV=(PATH="$FAKE_BIN:$PATH" APPEARANCE_PIP_YABAI_LOG="$TEMP_DIR/pip.log")

: >"$TEMP_DIR/pip.log"
env "${PIP_ENV[@]}" YABAI_WINDOW_ID=42 \
  FAKE_PIP_WINDOW_JSON='{"title":"Picture in Picture","is-floating":true,"is-sticky":true}' \
  "$MODULE_DIR/bin/tile-pip-window"
if grep -Fxq -- '-m window 42 --toggle sticky' "$TEMP_DIR/pip.log" \
  && grep -Fxq -- '-m window 42 --toggle float' "$TEMP_DIR/pip.log" \
  && grep -Fxq -- '-m window 42 --sub-layer auto' "$TEMP_DIR/pip.log"; then
  pass "PiP helper converts sticky floating PiP into a managed tile"
else
  fail "PiP helper converts sticky floating PiP into a managed tile" "sticky/float toggles and automatic sub-layer" "$(cat "$TEMP_DIR/pip.log")"
fi

: >"$TEMP_DIR/pip.log"
env "${PIP_ENV[@]}" YABAI_WINDOW_ID=42 \
  FAKE_PIP_WINDOW_JSON='{"title":"Picture in Picture","is-floating":false,"is-sticky":false}' \
  "$MODULE_DIR/bin/tile-pip-window"
if [[ ! -s "$TEMP_DIR/pip.log" ]]; then
  pass "PiP helper leaves an already managed tile unchanged"
else
  fail "PiP helper leaves an already managed tile unchanged" "no yabai mutations" "$(cat "$TEMP_DIR/pip.log")"
fi

: >"$TEMP_DIR/pip.log"
env "${PIP_ENV[@]}" YABAI_WINDOW_ID=42 \
  FAKE_PIP_WINDOW_JSON='{"title":"Ordinary Window","is-floating":true,"is-sticky":true}' \
  "$MODULE_DIR/bin/tile-pip-window"
if [[ ! -s "$TEMP_DIR/pip.log" ]]; then
  pass "PiP helper ignores non-PiP windows"
else
  fail "PiP helper ignores non-PiP windows" "no yabai mutations" "$(cat "$TEMP_DIR/pip.log")"
fi

if render_profile true; then
  pass "enabled profile renders in a cold home"
else
  fail "enabled profile renders in a cold home" "successful chezmoi apply" "apply failed"
fi
assert_executable "$DESTINATION/bin/tmux-border-accent" "enabled profile installs border command"
assert_executable "$DESTINATION/.config/yabai/tile-pip-window" "enabled profile installs PiP helper"
assert_contains "$DESTINATION/.yabairc" 'BORDER_WIDTH=4.0' "enabled profile preserves four-point borders"
assert_contains "$DESTINATION/.yabairc" 'BORDER_RESERVE=2' "enabled profile preserves two-point tile reserve"
assert_contains "$DESTINATION/.yabairc" 'BORDER_COLOR=0xff000000' "enabled profile preserves black inactive border"
assert_contains "$DESTINATION/.yabairc" 'tile_pip_on_create event=window_created' "enabled profile registers PiP creation signal"
assert_contains "$DESTINATION/.yabairc" 'tile_pip_on_title_change event=window_title_changed' "enabled profile registers PiP title signal"
assert_contains "$DESTINATION/.yabairc" 'tile_pip_windows" title="^Picture in Picture$" manage=on sticky=off sub-layer=auto' "enabled profile preserves managed PiP rule"
assert_contains "$DESTINATION/.yabairc" 'tmux-border-accent" start "$BORDER_WIDTH" "$BORDER_COLOR"' "enabled profile launches complete border configuration"
assert_contains "$DESTINATION/.tmux.conf" 'client-focus-in[60]' "enabled profile installs tmux focus hook"
assert_contains "$DESTINATION/.tmux.conf" 'tmux-border-accent update' "enabled profile updates borders from tmux events"

if render_profile false; then
  pass "disabled profile re-renders in the same cold home"
else
  fail "disabled profile re-renders in the same cold home" "successful chezmoi apply" "apply failed"
fi
assert_absent "$DESTINATION/bin/tmux-border-accent" "disabled profile removes border command"
assert_absent "$DESTINATION/.config/yabai/tile-pip-window" "disabled profile removes PiP helper"
assert_not_contains "$DESTINATION/.yabairc" 'BORDER_WIDTH=4.0' "disabled profile removes appearance policy"
assert_not_contains "$DESTINATION/.yabairc" 'signal --add label=tile_pip_' "disabled profile removes PiP signal registration"
assert_not_contains "$DESTINATION/.yabairc" 'rule --add label="tile_pip_windows"' "disabled profile removes PiP rule registration"
assert_not_contains "$DESTINATION/.yabairc" 'tmux-border-accent" start' "disabled profile removes border launch"
assert_not_contains "$DESTINATION/.tmux.conf" 'tmux-border-accent update' "disabled profile removes tmux border hooks"
assert_contains "$DESTINATION/.yabairc" 'signal --remove "tile_pip_on_create"' "disabled profile cleans previously registered PiP signals"
assert_contains "$DESTINATION/.yabairc" 'rule --remove "tile_pip_windows"' "disabled profile cleans the PiP rule"
assert_contains "$DESTINATION/.yabairc" 'yabai -m config layout                       bsp' "disabled profile preserves window layout"
assert_contains "$DESTINATION/.yabairc" 'scratchpad_terminal' "disabled profile preserves scratchpad integration"
assert_contains "$DESTINATION/.yabairc" 'space 1 --label "browser"' "disabled profile preserves space labels"

# Model disable followed by physical child-folder removal.
REMOVAL_SOURCE="$TEMP_DIR/removal-source"
REMOVAL_HOME="$TEMP_DIR/removal-home"
mkdir -p "$REMOVAL_SOURCE" "$REMOVAL_HOME"
cp -R "$DOTFILES_DIR/home" "$REMOVAL_SOURCE/home"
cp -R "$DOTFILES_DIR/modules" "$REMOVAL_SOURCE/modules"
cp "$DOTFILES_DIR/.chezmoiroot" "$REMOVAL_SOURCE/.chezmoiroot"
rm -rf "$REMOVAL_SOURCE/modules/appearance-pip"
if chezmoi -S "$REMOVAL_SOURCE" -D "$REMOVAL_HOME" \
  --persistent-state "$TEMP_DIR/removal-state.db" \
  --override-data '{"modules":{"appearancePip":{"enabled":false}}}' \
  apply --exclude=scripts,externals --force >/dev/null 2>&1; then
  pass "parent renders after the disabled module folder is removed"
else
  fail "parent renders after the disabled module folder is removed" "successful render" "render failed"
fi
assert_absent "$REMOVAL_HOME/bin/tmux-border-accent" "physical removal leaves no border command"
assert_absent "$REMOVAL_HOME/.config/yabai/tile-pip-window" "physical removal leaves no PiP helper"
assert_contains "$REMOVAL_HOME/.yabairc" 'yabai -m config layout                       bsp' "physical removal preserves window layout"
assert_contains "$REMOVAL_HOME/.yabairc" 'space 1 --label "browser"' "physical removal preserves space management"
assert_contains "$REMOVAL_HOME/.tmux.conf" 'tmux-session-template cycle' "physical removal preserves typed tmux controls"

printf '\n================================\n'
printf 'Results: %s passed, %s failed\n' "$PASSED" "$FAILED"
printf '================================\n'
exit "$FAILED"
