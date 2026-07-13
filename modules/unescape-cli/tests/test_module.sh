#!/usr/bin/env bash

set -uo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$TEST_DIR")"
DOTFILES_DIR="$(cd "$MODULE_DIR/../.." && pwd)"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-unescape-cli-module.XXXXXX")"
TEMP_DIR="$(cd "$TEMP_DIR" && pwd -P)"
DESTINATION="$TEMP_DIR/home"
STATE="$TEMP_DIR/state.db"
CHECKOUT="$DESTINATION/projects/unescape-cli"
PASSED=0
FAILED=0

cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT
pass() { printf '  ok - %s\n' "$1"; PASSED=$((PASSED + 1)); }
fail() { printf '  not ok - %s: expected %s; got %s\n' "$1" "$2" "$3"; FAILED=$((FAILED + 1)); }

assert_symlink() {
  local path="$1"
  local target="$2"
  local name="$3"

  if [[ -L "$path" && "$(readlink "$path")" == "$target" ]]; then
    pass "$name"
  else
    fail "$name" "$target" "$(readlink "$path" 2>/dev/null || printf missing)"
  fi
}

assert_absent() {
  if [[ ! -e "$1" && ! -L "$1" ]]; then pass "$2"; else fail "$2" absent "$1 exists"; fi
}

render_parent() {
  local enabled="$1"
  HOME="$DESTINATION" chezmoi -S "$DOTFILES_DIR" -D "$DESTINATION" --persistent-state "$STATE" \
    --override-data "{\"modules\":{\"unescapeCli\":{\"enabled\":$enabled}}}" \
    apply --exclude=scripts,externals --force \
    "$DESTINATION/bin/unescape-buffer" "$DESTINATION/bin/unescape-string" >/dev/null
}

printf '%s\n' '===================================' 'unescape-cli Module Contract Tests' '==================================='

if yq eval '.' "$MODULE_DIR/module.yaml" >/dev/null 2>&1 \
  && grep -Fq 'dataKey: modules.unescapeCli' "$MODULE_DIR/module.yaml"; then
  pass "manifest parses and declares one unescapeCli data key"
else
  fail "manifest parses and declares one unescapeCli data key" "valid manifest" "invalid or wrong data key"
fi

BUFFER_TARGET="$CHECKOUT/bin/unescape-buffer"
STRING_TARGET="$CHECKOUT/bin/unescape-string"
rendered_buffer="$(HOME="$DESTINATION" chezmoi -S "$DOTFILES_DIR" -D "$DESTINATION" execute-template <"$MODULE_DIR/targets/unescape-buffer-path.tmpl")"
rendered_string="$(HOME="$DESTINATION" chezmoi -S "$DOTFILES_DIR" -D "$DESTINATION" execute-template <"$MODULE_DIR/targets/unescape-string-path.tmpl")"
if [[ "$rendered_buffer" == "$BUFFER_TARGET" && "$rendered_string" == "$STRING_TARGET" ]]; then
  pass "path templates resolve both external checkout commands"
else
  fail "path templates resolve both external checkout commands" "$BUFFER_TARGET and $STRING_TARGET" "$rendered_buffer and $rendered_string"
fi

if grep -Fq '.modules.unescapeCli.enabled' "$DOTFILES_DIR/home/bin/symlink_unescape-buffer.tmpl" \
  && grep -Fq '../../modules/unescape-cli/targets/unescape-buffer-path.tmpl' "$DOTFILES_DIR/home/bin/symlink_unescape-buffer.tmpl" \
  && grep -Fq '.modules.unescapeCli.enabled' "$DOTFILES_DIR/home/bin/symlink_unescape-string.tmpl" \
  && grep -Fq '../../modules/unescape-cli/targets/unescape-string-path.tmpl' "$DOTFILES_DIR/home/bin/symlink_unescape-string.tmpl"; then
  pass "parent exposes two gated in-module path adapters"
else
  fail "parent exposes two gated in-module path adapters" "two unescapeCli symlink adapters" "adapter missing or miswired"
fi

mkdir -p "$CHECKOUT/bin" "$DESTINATION/bin"
printf '#!/usr/bin/env bash\nprintf buffer\n' >"$BUFFER_TARGET"
printf '#!/usr/bin/env bash\nprintf string\n' >"$STRING_TARGET"
chmod +x "$BUFFER_TARGET" "$STRING_TARGET"

if render_parent true; then
  pass "enabled parent render succeeds"
else
  fail "enabled parent render succeeds" "successful targeted apply" "apply failed"
fi
assert_symlink "$DESTINATION/bin/unescape-buffer" "$BUFFER_TARGET" "enabled module links unescape-buffer"
assert_symlink "$DESTINATION/bin/unescape-string" "$STRING_TARGET" "enabled module links unescape-string"

if render_parent false; then
  pass "disabled parent render succeeds"
else
  fail "disabled parent render succeeds" "successful targeted apply" "apply failed"
fi
assert_absent "$DESTINATION/bin/unescape-buffer" "disabled module removes unescape-buffer link"
assert_absent "$DESTINATION/bin/unescape-string" "disabled module removes unescape-string link"
if [[ -x "$BUFFER_TARGET" && -x "$STRING_TARGET" ]]; then
  pass "disabled module preserves the external checkout"
else
  fail "disabled module preserves the external checkout" "both external commands" "checkout command missing"
fi

REMOVAL_REPO="$TEMP_DIR/removal-repo"
REMOVAL_HOME="$TEMP_DIR/removal-home"
mkdir -p "$REMOVAL_HOME" "$REMOVAL_REPO/home/bin" "$REMOVAL_REPO/home/.chezmoidata" "$REMOVAL_REPO/modules"
printf 'home\n' >"$REMOVAL_REPO/.chezmoiroot"
cp "$DOTFILES_DIR/home/bin/symlink_unescape-buffer.tmpl" "$REMOVAL_REPO/home/bin/"
cp "$DOTFILES_DIR/home/bin/symlink_unescape-string.tmpl" "$REMOVAL_REPO/home/bin/"
cp -R "$MODULE_DIR" "$REMOVAL_REPO/modules/unescape-cli"
printf 'modules:\n  unescapeCli:\n    enabled: false\n' >"$REMOVAL_REPO/home/.chezmoidata/10-modules.yaml"
printf 'parent survives\n' >"$REMOVAL_REPO/home/dot_parent-sentinel"
rm -rf "$REMOVAL_REPO/modules/unescape-cli"
if HOME="$REMOVAL_HOME" chezmoi -S "$REMOVAL_REPO" -D "$REMOVAL_HOME" \
  --persistent-state "$TEMP_DIR/removal-state.db" apply --exclude=scripts,externals --force >/dev/null \
  && [[ "$(cat "$REMOVAL_HOME/.parent-sentinel")" == "parent survives" ]] \
  && [[ ! -e "$REMOVAL_HOME/bin/unescape-buffer" && ! -e "$REMOVAL_HOME/bin/unescape-string" ]]; then
  pass "disabled parent renders after the adapter module is removed"
else
  fail "disabled parent renders after the adapter module is removed" "healthy unrelated target" "removal contract failed"
fi

printf '\nResults: %s passed, %s failed\n' "$PASSED" "$FAILED"
exit "$FAILED"
