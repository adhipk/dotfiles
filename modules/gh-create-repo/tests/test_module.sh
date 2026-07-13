#!/usr/bin/env bash

set -uo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$TEST_DIR")"
DOTFILES_DIR="$(cd "$MODULE_DIR/../.." && pwd)"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-gh-create-repo-module.XXXXXX")"
TEMP_DIR="$(cd "$TEMP_DIR" && pwd -P)"
DESTINATION="$TEMP_DIR/home"
STATE="$TEMP_DIR/state.db"
EXPECTED_TARGET="$DESTINATION/projects/gh-create-repo/bin/gh-create-repo"
PASSED=0
FAILED=0

cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT

pass() { echo "  ok - $1"; PASSED=$((PASSED + 1)); }
fail() { echo "  not ok - $1"; echo "    $2"; FAILED=$((FAILED + 1)); }

assert_file() {
    [[ -f "$1" ]] && pass "$2" || fail "$2" "missing: $1"
}

assert_contains() {
    grep -Fq -- "$2" "$1" && pass "$3" || fail "$3" "missing '$2' in $1"
}

echo "gh-create-repo module adapter"

assert_file "$MODULE_DIR/module.yaml" "module manifest exists"
assert_file "$MODULE_DIR/targets/gh-create-repo-path.tmpl" "module owns its external path template"
assert_contains "$DOTFILES_DIR/home/bin/symlink_gh-create-repo.tmpl" \
    'if .modules.ghCreateRepo.enabled' "bridge follows module enablement"
assert_contains "$DOTFILES_DIR/home/bin/symlink_gh-create-repo.tmpl" \
    'includeTemplate "../../modules/gh-create-repo/targets/gh-create-repo-path.tmpl"' \
    "bridge delegates to the module path template"

if yq eval '.' "$MODULE_DIR/module.yaml" >/dev/null 2>&1; then
    pass "module manifest parses as YAML"
else
    fail "module manifest parses as YAML" "parse error"
fi

mkdir -p "$(dirname "$EXPECTED_TARGET")"
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\\n" gh-create-repo-adapter' >"$EXPECTED_TARGET"
chmod +x "$EXPECTED_TARGET"

if HOME="$DESTINATION" chezmoi -S "$DOTFILES_DIR" -D "$DESTINATION" --persistent-state "$STATE" \
    apply --exclude=scripts,externals --force >/dev/null; then
    pass "enabled profile applies"
else
    fail "enabled profile applies" "chezmoi apply failed"
fi

if [[ -L "$DESTINATION/bin/gh-create-repo" ]]; then
    pass "enabled profile installs a symlink"
else
    fail "enabled profile installs a symlink" "missing symlink"
fi

actual_target="$(readlink "$DESTINATION/bin/gh-create-repo" 2>/dev/null || true)"
[[ "$actual_target" == "$EXPECTED_TARGET" ]] \
    && pass "symlink targets the pinned project checkout" \
    || fail "symlink targets the pinned project checkout" "expected $EXPECTED_TARGET, got $actual_target"

actual_output="$("$DESTINATION/bin/gh-create-repo" 2>/dev/null || true)"
[[ "$actual_output" == "gh-create-repo-adapter" ]] \
    && pass "installed adapter executes the external command" \
    || fail "installed adapter executes the external command" "got: $actual_output"

if HOME="$DESTINATION" chezmoi -S "$DOTFILES_DIR" -D "$DESTINATION" --persistent-state "$STATE" \
    --override-data '{"modules":{"ghCreateRepo":{"enabled":false}}}' \
    apply --exclude=scripts,externals --force >/dev/null; then
    pass "disabled profile applies"
else
    fail "disabled profile applies" "chezmoi apply failed"
fi

[[ ! -e "$DESTINATION/bin/gh-create-repo" && ! -L "$DESTINATION/bin/gh-create-repo" ]] \
    && pass "disabled profile removes only the stable adapter" \
    || fail "disabled profile removes only the stable adapter" "adapter remains"
[[ -x "$EXPECTED_TARGET" ]] \
    && pass "disabled profile preserves the external checkout" \
    || fail "disabled profile preserves the external checkout" "external command was removed"

echo "Results: $PASSED passed, $FAILED failed"
exit "$FAILED"
