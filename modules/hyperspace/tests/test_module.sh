#!/usr/bin/env bash
set -u

MODULE="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$MODULE/../.." && pwd)"
TEMP="$(mktemp -d "${TMPDIR:-/tmp}/hyperspace-module-test.XXXXXX")"
PASSED=0
FAILED=0
trap 'rm -rf "$TEMP"' EXIT

pass() { printf '  ok - %s\n' "$1"; PASSED=$((PASSED + 1)); }
fail() { printf '  not ok - %s: %s\n' "$1" "$2"; FAILED=$((FAILED + 1)); }
assert_contains() { [[ "$1" == *"$2"* ]] && pass "$3" || fail "$3" "missing [$2]"; }

printf 'Testing Hyperspace module boundary...\n'
[[ "$(yq -r '.modules.hyperspace.enabled' "$ROOT/home/.chezmoidata/10-modules.yaml")" == false ]] \
  && pass "Hyperspace is explicitly disabled" || fail "Hyperspace is explicitly disabled" "data flag is not false"
[[ "$(yq -r '.distribution.standalone' "$MODULE/module.yaml")" == true ]] \
  && pass "Hyperspace declares its standalone source CLI" || fail "Hyperspace declares its standalone source CLI" "manifest mismatch"
[[ "$(yq -r '.state.preserved | length' "$MODULE/module.yaml")" == 2 ]] \
  && pass "pin database and environment are preserved" || fail "pin database and environment are preserved" "state mismatch"

disabled=$(chezmoi -S "$ROOT" cat "$HOME/.config/skhd/modules/hyperspace/hyperspace")
[[ -z "$disabled" ]] && pass "disabled profile renders no parked CLI" || fail "disabled profile renders no parked CLI" "$disabled"
disabled_keys=$(chezmoi -S "$ROOT" cat "$HOME/.config/skhd/modules/hyperspace.skhdrc")
[[ -z "$disabled_keys" ]] && pass "disabled profile renders no experimental bindings" || fail "disabled profile renders no experimental bindings" "$disabled_keys"
enabled=$(chezmoi -S "$ROOT" --override-data '{"modules":{"hyperspace":{"enabled":true}}}' cat "$HOME/.config/skhd/modules/hyperspace/hyperspace")
assert_contains "$enabled" 'hyperspace pin <slot>' "enabled profile renders the parked CLI"

APPLY_HOME="$TEMP/disabled-home"
mkdir -p "$APPLY_HOME/.config/skhd/modules/hyperspace" "$APPLY_HOME/.config/sesh"
for target in hyperspace open_spotlight_scratchpad spotlight-zsh .zshrc; do touch "$APPLY_HOME/.config/skhd/modules/hyperspace/$target"; done
touch "$APPLY_HOME/.config/skhd/modules/hyperspace.skhdrc"
printf '{"2":"demo"}\n' >"$APPLY_HOME/.config/sesh/hyperspaces.json"
if chezmoi -S "$ROOT" -D "$APPLY_HOME" --persistent-state "$TEMP/hyperspace-state.boltdb" \
    apply --exclude=scripts,externals --force -- "$APPLY_HOME/.config/skhd/modules/hyperspace" "$APPLY_HOME/.config/skhd/modules/hyperspace.skhdrc"; then
  remaining=$(find "$APPLY_HOME/.config/skhd/modules/hyperspace" -type f 2>/dev/null | wc -l | tr -d ' ')
  [[ "$remaining" == 0 && ! -e "$APPLY_HOME/.config/skhd/modules/hyperspace.skhdrc" ]] \
    && pass "disabled apply removes only parked targets" || fail "disabled apply removes only parked targets" "target remains"
else
  fail "disabled apply removes only parked targets" "chezmoi apply failed"
fi
[[ -f "$APPLY_HOME/.config/sesh/hyperspaces.json" ]] \
  && pass "disabled apply preserves the pin database" || fail "disabled apply preserves the pin database" "state missing"

printf '\nTesting source CLI without desktop activation...\n'
PIN_FILE="$TEMP/hyperspaces.json"
ENV_FILE="$TEMP/missing.env"
if HYPERSPACE_NOTIFY=0 HYPERSPACE_PIN_FILE="$PIN_FILE" HYPERSPACE_CONFIG_FILE="$ENV_FILE" \
    "$MODULE/bin/hyperspace" pin 3 demo; then
  pass "source CLI pins an explicit session"
else
  fail "source CLI pins an explicit session" "pin failed"
fi
listing=$(HYPERSPACE_NOTIFY=0 HYPERSPACE_PIN_FILE="$PIN_FILE" HYPERSPACE_CONFIG_FILE="$ENV_FILE" "$MODULE/bin/hyperspace" list)
[[ "$listing" == '3: demo' ]] && pass "source CLI lists pins" || fail "source CLI lists pins" "$listing"
HYPERSPACE_NOTIFY=0 HYPERSPACE_PIN_FILE="$PIN_FILE" HYPERSPACE_CONFIG_FILE="$ENV_FILE" "$MODULE/bin/hyperspace" unpin 3
[[ "$(jq -c '.' "$PIN_FILE")" == '{}' ]] && pass "source CLI unpins without touching tmux" || fail "source CLI unpins without touching tmux" "$(cat "$PIN_FILE")"

printf '\nTesting child-folder removal safety...\n'
FIXTURE="$TEMP/source"
DEST="$TEMP/home"
mkdir -p "$FIXTURE/home/dot_config/skhd/modules/hyperspace" "$FIXTURE/home/.chezmoidata" "$FIXTURE/tests" "$DEST"
printf 'home\n' >"$FIXTURE/.chezmoiroot"
printf 'modules:\n  hyperspace:\n    enabled: false\n' >"$FIXTURE/home/.chezmoidata/10-modules.yaml"
cp "$ROOT/home/dot_config/skhd/modules/hyperspace/executable_hyperspace.tmpl" "$FIXTURE/home/dot_config/skhd/modules/hyperspace/executable_hyperspace.tmpl"
cp "$ROOT/home/dot_config/skhd/modules/hyperspace/executable_open_spotlight_scratchpad.tmpl" "$FIXTURE/home/dot_config/skhd/modules/hyperspace/executable_open_spotlight_scratchpad.tmpl"
cp "$ROOT/home/dot_config/skhd/modules/hyperspace/executable_spotlight-zsh.tmpl" "$FIXTURE/home/dot_config/skhd/modules/hyperspace/executable_spotlight-zsh.tmpl"
cp "$ROOT/home/dot_config/skhd/modules/hyperspace/dot_zshrc.tmpl" "$FIXTURE/home/dot_config/skhd/modules/hyperspace/dot_zshrc.tmpl"
cp "$ROOT/home/dot_config/skhd/modules/hyperspace.skhdrc.tmpl" "$FIXTURE/home/dot_config/skhd/modules/hyperspace.skhdrc.tmpl"
absent=""
absent_error=""
for target in \
  "$DEST/.config/skhd/modules/hyperspace/hyperspace" \
  "$DEST/.config/skhd/modules/hyperspace/open_spotlight_scratchpad" \
  "$DEST/.config/skhd/modules/hyperspace/spotlight-zsh" \
  "$DEST/.config/skhd/modules/hyperspace/.zshrc" \
  "$DEST/.config/skhd/modules/hyperspace.skhdrc"; do
  if rendered=$(chezmoi -S "$FIXTURE" -D "$DEST" cat "$target" 2>>"$TEMP/absent.err"); then
    absent="${absent}${rendered}"
  else
    absent_error="$(cat "$TEMP/absent.err")"
    break
  fi
done
if [[ -z "$absent_error" ]]; then
  [[ -z "$absent" ]] && pass "all disabled bridges render when child folder is absent" || fail "all disabled bridges render when child folder is absent" "$absent"
else
  fail "all disabled bridges render when child folder is absent" "$absent_error"
fi
cp "$ROOT/tests/test_hyperspace.sh" "$FIXTURE/tests/test_hyperspace.sh"
chmod +x "$FIXTURE/tests/test_hyperspace.sh"
if "$FIXTURE/tests/test_hyperspace.sh" >"$TEMP/parent-test.out" 2>"$TEMP/parent-test.err"; then
  pass "parent Hyperspace test remains valid when the child folder is absent"
else
  fail "parent Hyperspace test remains valid when the child folder is absent" "$(cat "$TEMP/parent-test.err")"
fi

bash -n "$MODULE/bin/hyperspace" "$MODULE/bin/open-spotlight-scratchpad" "$MODULE/bin/spotlight-zsh" \
  && pass "module shell entrypoints parse" || fail "module shell entrypoints parse" "syntax error"
zsh -n "$MODULE/config/zshrc" && pass "Spotlight zsh config parses" || fail "Spotlight zsh config parses" "syntax error"
[[ ! -e "$ROOT/home/dot_config/skhd/modules/hyperspace/executable_hyperspace" ]] \
  && pass "old non-template ownership path is gone" || fail "old non-template ownership path is gone" "stale source remains"
if rg -q 'include.*hyperspace|source.*hyperspace' "$ROOT/home/dot_skhdrc.tmpl"; then
  fail "active skhd config does not load Hyperspace" "active include found"
else
  pass "active skhd config does not load Hyperspace"
fi

printf '\n%s passed, %s failed\n' "$PASSED" "$FAILED"
[[ "$FAILED" -eq 0 ]]
