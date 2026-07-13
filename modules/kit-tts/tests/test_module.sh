#!/usr/bin/env bash

set -uo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$TEST_DIR")"
DOTFILES_DIR="$(cd "$MODULE_DIR/../.." && pwd)"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-kit-tts-module.XXXXXX")"
TEMP_DIR="$(cd "$TEMP_DIR" && pwd -P)"
DESTINATION="$TEMP_DIR/home"
STATE="$TEMP_DIR/state.db"
UPSTREAM_DIR="$DESTINATION/projects/kittentts-cli"
KIT_LINK="$DESTINATION/bin/kit"
WATCH_LINK="$DESTINATION/bin/kit-watch"
PASSED=0
FAILED=0

cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT
pass() { printf '  ok - %s\n' "$1"; PASSED=$((PASSED + 1)); }
fail() { printf '  not ok - %s: expected %s; got %s\n' "$1" "$2" "$3"; FAILED=$((FAILED + 1)); }

assert_file() {
  if [[ -f "$1" ]]; then pass "$2"; else fail "$2" "$1" "missing"; fi
}

assert_absent() {
  if [[ ! -e "$1" && ! -L "$1" ]]; then pass "$2"; else fail "$2" "absent" "$1 exists"; fi
}

assert_symlink() {
  local link="$1" expected="$2" name="$3" actual=""
  [[ ! -L "$link" ]] || actual="$(readlink "$link")"
  if [[ -L "$link" && "$actual" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name" "$expected" "${actual:-not a symlink}"
  fi
}

render_parent() {
  local override_data="${1:-}"
  local -a args=(-S "$DOTFILES_DIR" -D "$DESTINATION" --persistent-state "$STATE")
  [[ -z "$override_data" ]] || args+=(--override-data "$override_data")
  HOME="$DESTINATION" chezmoi "${args[@]}" apply --exclude=scripts,externals --force \
    -- "$KIT_LINK" "$WATCH_LINK" >/dev/null
}

printf '%s\n' '================================' 'kit-tts Adapter Contract Tests' '================================'

assert_file "$MODULE_DIR/module.yaml" "module manifest exists"
assert_file "$MODULE_DIR/README.md" "module documentation exists"
assert_file "$MODULE_DIR/targets/kit-path.tmpl" "kit target template exists"
assert_file "$MODULE_DIR/targets/kit-watch-path.tmpl" "kit-watch target template exists"

if yq eval '.' "$MODULE_DIR/module.yaml" >/dev/null 2>&1; then
  pass "module manifest parses as YAML"
else
  fail "module manifest parses as YAML" "valid YAML" "parse error"
fi

if grep -Fq 'includeTemplate "../../modules/kit-tts/targets/kit-path.tmpl"' "$DOTFILES_DIR/home/bin/symlink_kit.tmpl" \
  && grep -Fq 'includeTemplate "../../modules/kit-tts/targets/kit-watch-path.tmpl"' "$DOTFILES_DIR/home/bin/symlink_kit-watch.tmpl" \
  && grep -Fq 'if .modules.kitTts.enabled' "$DOTFILES_DIR/home/bin/symlink_kit.tmpl" \
  && grep -Fq 'if .modules.kitTts.enabled' "$DOTFILES_DIR/home/bin/symlink_kit-watch.tmpl"; then
  pass "installed command paths are gated external-project adapters"
else
  fail "installed command paths are gated external-project adapters" "two conditional path-template bridges" "bridge missing"
fi

mkdir -p "$UPSTREAM_DIR" "$DESTINATION/bin"
cat >"$UPSTREAM_DIR/kit" <<'EOF'
#!/usr/bin/env bash
printf 'kit:%s\n' "$*"
EOF
cat >"$UPSTREAM_DIR/kit-watch" <<'EOF'
#!/usr/bin/env bash
printf 'kit-watch:%s\n' "$*"
EOF
chmod +x "$UPSTREAM_DIR/kit" "$UPSTREAM_DIR/kit-watch"
printf 'unrelated\n' >"$DESTINATION/bin/unrelated-command"

if render_parent; then
  pass "enabled profile renders in a disposable home"
else
  fail "enabled profile renders in a disposable home" "successful ChezMoi apply" "apply failed"
fi
assert_symlink "$KIT_LINK" "$UPSTREAM_DIR/kit" "enabled profile links kit to the external checkout"
assert_symlink "$WATCH_LINK" "$UPSTREAM_DIR/kit-watch" "enabled profile links kit-watch to the external checkout"

if [[ "$($KIT_LINK hello world)" == "kit:hello world" ]]; then
  pass "kit executes through the managed symlink"
else
  fail "kit executes through the managed symlink" "kit:hello world" "execution differed"
fi
if [[ "$($WATCH_LINK --no-initial draft.txt)" == "kit-watch:--no-initial draft.txt" ]]; then
  pass "kit-watch executes through the managed symlink"
else
  fail "kit-watch executes through the managed symlink" "kit-watch:--no-initial draft.txt" "execution differed"
fi

if render_parent '{"modules":{"kitTts":{"enabled":false}}}'; then
  pass "disabled profile re-renders successfully"
else
  fail "disabled profile re-renders successfully" "successful ChezMoi apply" "apply failed"
fi
assert_absent "$KIT_LINK" "disabled profile removes kit"
assert_absent "$WATCH_LINK" "disabled profile removes kit-watch"
assert_file "$DESTINATION/bin/unrelated-command" "disabled profile preserves unrelated targets"
assert_file "$UPSTREAM_DIR/kit" "disabled profile preserves the external project"
assert_file "$UPSTREAM_DIR/kit-watch" "disabled profile preserves both external commands"

# Build the smallest compatible parent, delete the already-disabled module,
# then render again. The false branch must not evaluate the missing templates.
REMOVAL_REPO="$TEMP_DIR/removal-repo"
REMOVAL_HOME="$TEMP_DIR/removal-home"
mkdir -p "$REMOVAL_HOME" "$REMOVAL_REPO/home/bin" "$REMOVAL_REPO/home/.chezmoidata" "$REMOVAL_REPO/modules"
printf 'home\n' >"$REMOVAL_REPO/.chezmoiroot"
cp "$DOTFILES_DIR/home/bin/symlink_kit.tmpl" "$REMOVAL_REPO/home/bin/"
cp "$DOTFILES_DIR/home/bin/symlink_kit-watch.tmpl" "$REMOVAL_REPO/home/bin/"
cp -R "$MODULE_DIR" "$REMOVAL_REPO/modules/kit-tts"
cat >"$REMOVAL_REPO/home/.chezmoidata/10-modules.yaml" <<'EOF'
modules:
  kitTts:
    enabled: false
EOF
printf 'parent survives\n' >"$REMOVAL_REPO/home/dot_parent-sentinel"
rm -rf "$REMOVAL_REPO/modules/kit-tts"
if HOME="$REMOVAL_HOME" chezmoi -S "$REMOVAL_REPO" -D "$REMOVAL_HOME" \
  --persistent-state "$TEMP_DIR/removal-state.db" \
  apply --exclude=scripts,externals --force >/dev/null \
  && [[ "$(cat "$REMOVAL_HOME/.parent-sentinel")" == "parent survives" ]] \
  && [[ ! -e "$REMOVAL_HOME/bin/kit" && ! -L "$REMOVAL_HOME/bin/kit" ]] \
  && [[ ! -e "$REMOVAL_HOME/bin/kit-watch" && ! -L "$REMOVAL_HOME/bin/kit-watch" ]]; then
  pass "disabled parent renders after the adapter module is removed"
else
  fail "disabled parent renders after the adapter module is removed" "healthy unrelated target with module absent" "removal contract failed"
fi

printf '\nResults: %s passed, %s failed\n' "$PASSED" "$FAILED"
exit "$FAILED"
