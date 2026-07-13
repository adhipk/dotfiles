#!/usr/bin/env bash

set -uo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$TEST_DIR")"
DOTFILES_DIR="$(cd "$MODULE_DIR/../.." && pwd)"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-space-display-module.XXXXXX")"
DESTINATION="$TEMP_DIR/home"
STATE="$TEMP_DIR/state.db"
FAKE_BIN="$TEMP_DIR/bin"
PASSED=0
FAILED=0

cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT
pass() { printf '  ✓ %s\n' "$1"; PASSED=$((PASSED + 1)); }
fail() { printf '  ✗ %s\n    Expected: %s\n    Actual:   %s\n' "$1" "$2" "$3"; FAILED=$((FAILED + 1)); }
assert_file() { [[ -f "$1" ]] && pass "$2" || fail "$2" "$1" "missing"; }
assert_executable() { [[ -x "$1" ]] && pass "$2" || fail "$2" "executable $1" "missing or not executable"; }
assert_absent() { [[ ! -e "$1" ]] && pass "$2" || fail "$2" "absent" "$1 exists"; }
assert_contains() { grep -Fq -- "$2" "$1" && pass "$3" || fail "$3" "text containing $2" "$1"; }
assert_not_contains() { ! grep -Fq -- "$2" "$1" && pass "$3" || fail "$3" "text excluding $2" "$1"; }

render_profile() {
  local enabled="$1"
  mkdir -p "$DESTINATION"
  chezmoi -S "$DOTFILES_DIR" -D "$DESTINATION" --persistent-state "$STATE" \
    --override-data "{\"modules\":{\"spaceDisplay\":{\"enabled\":$enabled}}}" \
    apply --exclude=scripts,externals --force >/dev/null
}

printf '================================\nSpace and Display Module Contract Tests\n================================\n'

assert_file "$MODULE_DIR/module.yaml" "module manifest exists"
for helper in bookmarks bookmarks-store create-space close-empty-spaces display-move setup-yabai-sa reset-yabai; do
  assert_executable "$MODULE_DIR/bin/$helper" "module owns $helper"
done
assert_file "$MODULE_DIR/targets/skhdrc.tmpl" "module owns space/display bindings"
assert_file "$MODULE_DIR/targets/yabairc-scripting-addition.tmpl" "module owns scripting-addition policy"
assert_file "$MODULE_DIR/targets/yabairc-spaces.tmpl" "module owns fixed-space policy"

if yq eval '.' "$MODULE_DIR/module.yaml" >/dev/null 2>&1; then pass "module manifest parses as YAML"; else fail "module manifest parses as YAML" "valid YAML" "parse error"; fi
if bash -n "$MODULE_DIR/bin/create-space" \
  && bash -n "$MODULE_DIR/bin/close-empty-spaces" \
  && bash -n "$MODULE_DIR/bin/display-move" \
  && bash -n "$MODULE_DIR/bin/bookmarks-store" \
  && zsh -n "$MODULE_DIR/bin/setup-yabai-sa" \
  && zsh -n "$MODULE_DIR/bin/reset-yabai"; then
  pass "module shell entrypoints parse"
else
  fail "module shell entrypoints parse" "valid shell" "syntax error"
fi

assert_contains "$DOTFILES_DIR/home/dot_skhdrc.tmpl" 'includeTemplate "../modules/space-display/targets/skhdrc.tmpl"' "skhd has one guarded module mount"
assert_contains "$DOTFILES_DIR/home/dot_yabairc.tmpl" 'includeTemplate "../modules/space-display/targets/yabairc-spaces.tmpl"' "yabai mounts fixed-space policy"
assert_contains "$DOTFILES_DIR/home/bin/executable_reset-yabai.tmpl" 'includeTemplate "../modules/space-display/bin/reset-yabai"' "reset-yabai has a thin stable bridge"
assert_contains "$DOTFILES_DIR/home/dot_config/yabai/executable_create-space.tmpl" 'includeTemplate "../modules/space-display/bin/create-space"' "create-space has a thin stable bridge"

mkdir -p "$FAKE_BIN"

# Adjacent display movement preserves the focused window identity.
cat >"$FAKE_BIN/yabai" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == '-m query --windows --window' ]]; then
  printf '%s\n' '{"id":42}'
else
  printf '%s\n' "$*" >>"$SPACE_DISPLAY_LOG"
fi
EOF
chmod +x "$FAKE_BIN/yabai"
: >"$TEMP_DIR/display.log"
HOME="$TEMP_DIR/runtime-home" PATH="$FAKE_BIN:$PATH" SPACE_DISPLAY_LOG="$TEMP_DIR/display.log" \
  "$MODULE_DIR/bin/display-move" next
if [[ "$(cat "$TEMP_DIR/display.log")" == $'-m window --display next\n-m display --focus next\n-m window --focus 42' ]]; then
  pass "display move preserves move, display focus, and window focus order"
else
  fail "display move preserves move, display focus, and window focus order" "three ordered yabai calls" "$(cat "$TEMP_DIR/display.log")"
fi

# Space creation identifies the new UUID/index rather than assuming index order.
cat >"$FAKE_BIN/yabai" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  '-m query --displays --display') printf '%s\n' '{"index":1}' ;;
  '-m query --spaces')
    if [[ -f "$SPACE_CREATED_STATE" ]]; then
      printf '%s\n' '[{"uuid":"old","index":1,"display":1},{"uuid":"new","index":2,"display":1}]'
    else
      printf '%s\n' '[{"uuid":"old","index":1,"display":1}]'
    fi
    ;;
  '-m space --create') : >"$SPACE_CREATED_STATE"; printf '%s\n' "$*" >>"$SPACE_DISPLAY_LOG" ;;
  *) printf '%s\n' "$*" >>"$SPACE_DISPLAY_LOG" ;;
esac
EOF
chmod +x "$FAKE_BIN/yabai"
: >"$TEMP_DIR/create.log"
HOME="$TEMP_DIR/runtime-home" PATH="$FAKE_BIN:$PATH" SPACE_DISPLAY_LOG="$TEMP_DIR/create.log" SPACE_CREATED_STATE="$TEMP_DIR/created" \
  "$MODULE_DIR/bin/create-space" focus
if grep -Fxq -- '-m space --create' "$TEMP_DIR/create.log" \
  && grep -Fxq -- '-m display --focus 1' "$TEMP_DIR/create.log" \
  && grep -Fxq -- '-m space --focus 2' "$TEMP_DIR/create.log"; then
  pass "create-space finds and focuses the newly created space"
else
  fail "create-space finds and focuses the newly created space" "create, display focus, space 2 focus" "$(cat "$TEMP_DIR/create.log")"
fi

# Empty-space cleanup deletes high indices first while keeping one occupied space.
cat >"$FAKE_BIN/yabai" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == '-m query --spaces' ]]; then
  printf '%s\n' "$FAKE_SPACES_JSON"
elif [[ "$*" == *'--destroy' ]]; then
  printf '%s\n' "$*" >>"$SPACE_DISPLAY_LOG"
else
  exit 0
fi
EOF
chmod +x "$FAKE_BIN/yabai"
: >"$TEMP_DIR/close.log"
PATH="$FAKE_BIN:$PATH" SPACE_DISPLAY_LOG="$TEMP_DIR/close.log" \
  FAKE_SPACES_JSON='[{"index":1,"windows":[10]},{"index":2,"windows":[]},{"index":3,"windows":[]}]' \
  "$MODULE_DIR/bin/close-empty-spaces" >/dev/null
if [[ "$(cat "$TEMP_DIR/close.log")" == $'-m space 3 --destroy\n-m space 2 --destroy' ]]; then
  pass "empty-space cleanup destroys from highest index downward"
else
  fail "empty-space cleanup destroys from highest index downward" "3 then 2" "$(cat "$TEMP_DIR/close.log")"
fi
: >"$TEMP_DIR/close.log"
PATH="$FAKE_BIN:$PATH" SPACE_DISPLAY_LOG="$TEMP_DIR/close.log" \
  FAKE_SPACES_JSON='[{"index":1,"windows":[]},{"index":2,"windows":[]}]' \
  "$MODULE_DIR/bin/close-empty-spaces" >/dev/null
if [[ ! -s "$TEMP_DIR/close.log" ]]; then pass "empty-space cleanup refuses to remove every space"; else fail "empty-space cleanup refuses to remove every space" "no destroy calls" "$(cat "$TEMP_DIR/close.log")"; fi

# Legacy bookmarks keep their existing state schema and public notification adapter.
BOOKMARK_HOME="$TEMP_DIR/bookmark-home"
mkdir -p "$BOOKMARK_HOME/.config/skhd"
cat >"$BOOKMARK_HOME/.config/skhd/notify.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$FAKE_BIN/yabai" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  '-m query --spaces --space') printf '%s\n' '{"uuid":"space-a","label":"browser"}' ;;
  *) printf '%s\n' "$*" >>"$SPACE_DISPLAY_LOG" ;;
esac
EOF
chmod +x "$BOOKMARK_HOME/.config/skhd/notify.sh" "$FAKE_BIN/yabai"
: >"$TEMP_DIR/bookmark.log"
HOME="$BOOKMARK_HOME" PATH="$FAKE_BIN:$PATH" SPACE_DISPLAY_LOG="$TEMP_DIR/bookmark.log" \
  "$MODULE_DIR/bin/bookmarks-store" set 2
if jq -e '.["2"] == "space-a"' "$BOOKMARK_HOME/.config/yabai/space-bookmarks.json" >/dev/null \
  && grep -Fq -- '-m space --label 📌2 browser' "$TEMP_DIR/bookmark.log"; then
  pass "legacy bookmarks preserve UUID state and pin label"
else
  fail "legacy bookmarks preserve UUID state and pin label" "slot 2 and pin label" "$(cat "$TEMP_DIR/bookmark.log")"
fi

# Reset uses the Brewfile formula and delegates SA setup instead of embedding a version/tap.
cat >"$TEMP_DIR/Brewfile" <<'EOF'
tap "asmvik/formulae"
brew "asmvik/formulae/yabai"
EOF
cat >"$FAKE_BIN/brew" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$RESET_BREW_LOG"
EOF
cat >"$FAKE_BIN/yabai" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$RESET_YABAI_LOG"
EOF
cat >"$FAKE_BIN/setup-yabai-sa" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$YABAI_BIN" >>"$RESET_SETUP_LOG"
EOF
cat >"$FAKE_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$FAKE_BIN/brew" "$FAKE_BIN/yabai" "$FAKE_BIN/setup-yabai-sa" "$FAKE_BIN/sudo"
: >"$TEMP_DIR/brew.log"; : >"$TEMP_DIR/reset-yabai.log"; : >"$TEMP_DIR/setup.log"
PATH="$FAKE_BIN:$PATH" DOTFILES_BREWFILE="$TEMP_DIR/Brewfile" BREW_BIN="$FAKE_BIN/brew" \
  YABAI_BIN="$FAKE_BIN/yabai" YABAI_BIN_AFTER_INSTALL="$FAKE_BIN/yabai" SETUP_YABAI_SA_BIN="$FAKE_BIN/setup-yabai-sa" \
  RESET_BREW_LOG="$TEMP_DIR/brew.log" RESET_YABAI_LOG="$TEMP_DIR/reset-yabai.log" RESET_SETUP_LOG="$TEMP_DIR/setup.log" \
  "$MODULE_DIR/bin/reset-yabai"
if grep -Fxq 'install asmvik/formulae/yabai' "$TEMP_DIR/brew.log" \
  && grep -Fxq 'pin yabai' "$TEMP_DIR/brew.log" \
  && grep -Fxq "$FAKE_BIN/yabai" "$TEMP_DIR/setup.log"; then
  pass "reset-yabai follows Brewfile authority and delegates SA setup"
else
  fail "reset-yabai follows Brewfile authority and delegates SA setup" "Brewfile formula, pin, delegated binary" "$(cat "$TEMP_DIR/brew.log")"
fi
assert_not_contains "$MODULE_DIR/bin/reset-yabai" '7.1.16' "reset-yabai removes the hard-coded version"
assert_not_contains "$MODULE_DIR/bin/reset-yabai" 'adhipkashyap/yabai-versions' "reset-yabai removes the custom tap"
assert_contains "$MODULE_DIR/bin/setup-yabai-sa" 'sha256:$YABAI_SHA256' "SA setup remains checksum-scoped"

if render_profile true; then pass "enabled profile renders in a cold home"; else fail "enabled profile renders in a cold home" "successful apply" "apply failed"; fi
for path in bin/bookmarks bin/setup-yabai-sa bin/reset-yabai .config/yabai/bookmarks .config/yabai/create-space .config/yabai/close_empty_spaces.sh .config/yabai/display-move; do
  assert_executable "$DESTINATION/$path" "enabled profile installs $path"
done
assert_contains "$DESTINATION/.skhdrc" 'display-move prev' "enabled profile preserves previous-display binding"
assert_contains "$DESTINATION/.skhdrc" 'create-space auto' "enabled profile preserves Option+n"
assert_contains "$DESTINATION/.skhdrc" 'close_empty_spaces.sh' "enabled profile preserves Option+k"
assert_contains "$DESTINATION/.yabairc" 'yabai --load-sa' "enabled profile loads the scripting addition"
assert_contains "$DESTINATION/.yabairc" 'space_display_load_sa event=dock_did_restart' "enabled profile reloads SA after Dock restart"
assert_contains "$DESTINATION/.yabairc" 'space 1 --label "browser"' "enabled profile preserves browser label"
assert_contains "$DESTINATION/.yabairc" 'space 4 --label "empty"' "enabled profile preserves empty label"

if render_profile false; then pass "disabled profile re-renders in the same cold home"; else fail "disabled profile re-renders in the same cold home" "successful apply" "apply failed"; fi
for path in bin/bookmarks bin/setup-yabai-sa bin/reset-yabai .config/yabai/bookmarks .config/yabai/create-space .config/yabai/close_empty_spaces.sh .config/yabai/display-move; do
  assert_absent "$DESTINATION/$path" "disabled profile removes $path"
done
assert_not_contains "$DESTINATION/.skhdrc" 'display-move prev' "disabled profile removes display bindings"
assert_not_contains "$DESTINATION/.skhdrc" 'create-space auto' "disabled profile removes create binding"
assert_not_contains "$DESTINATION/.yabairc" 'signal --add label=space_display_load_sa' "disabled profile removes SA signal registration"
assert_not_contains "$DESTINATION/.yabairc" 'space 1 --label "browser"' "disabled profile removes fixed labels"
assert_contains "$DESTINATION/.yabairc" 'signal --remove "space_display_load_sa"' "disabled profile cleans the prior SA signal"
assert_contains "$DESTINATION/.yabairc" 'BORDER_WIDTH=4.0' "disabled profile preserves appearance"
assert_contains "$DESTINATION/.yabairc" 'yabai -m config layout                       bsp' "disabled profile preserves window layout"

REMOVAL_SOURCE="$TEMP_DIR/removal-source"; REMOVAL_HOME="$TEMP_DIR/removal-home"
mkdir -p "$REMOVAL_SOURCE" "$REMOVAL_HOME"
cp -R "$DOTFILES_DIR/home" "$REMOVAL_SOURCE/home"
cp -R "$DOTFILES_DIR/modules" "$REMOVAL_SOURCE/modules"
cp "$DOTFILES_DIR/.chezmoiroot" "$REMOVAL_SOURCE/.chezmoiroot"
rm -rf "$REMOVAL_SOURCE/modules/space-display"
if chezmoi -S "$REMOVAL_SOURCE" -D "$REMOVAL_HOME" --persistent-state "$TEMP_DIR/removal-state.db" \
  --override-data '{"modules":{"spaceDisplay":{"enabled":false}}}' apply --exclude=scripts,externals --force >/dev/null 2>&1; then
  pass "parent renders after the disabled module folder is removed"
else
  fail "parent renders after the disabled module folder is removed" "successful render" "render failed"
fi
assert_absent "$REMOVAL_HOME/.config/yabai/create-space" "physical removal leaves no create helper"
assert_contains "$REMOVAL_HOME/.yabairc" 'BORDER_WIDTH=4.0' "physical removal preserves appearance"
assert_contains "$REMOVAL_HOME/.skhdrc" 'snap_window.sh left' "physical removal preserves window layout bindings"

printf '\n================================\nResults: %s passed, %s failed\n================================\n' "$PASSED" "$FAILED"
exit "$FAILED"
