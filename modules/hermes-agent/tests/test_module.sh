#!/usr/bin/env bash

set -uo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$TEST_DIR")"
DOTFILES_DIR="$(cd "$MODULE_DIR/../.." && pwd)"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-hermes-agent-module.XXXXXX")"
TEMP_DIR="$(cd "$TEMP_DIR" && pwd -P)"
DESTINATION="$TEMP_DIR/home"
STATE="$TEMP_DIR/state.db"
LAUNCHER="$DESTINATION/bin/hermes-dotfiles"
FAKE_BIN="$TEMP_DIR/fake-bin"
PASSED=0
FAILED=0

cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT
pass() { printf '  ok - %s\n' "$1"; PASSED=$((PASSED + 1)); }
fail() { printf '  not ok - %s: %s\n' "$1" "$2"; FAILED=$((FAILED + 1)); }

assert_file() {
  [[ -f "$1" ]] && pass "$2" || fail "$2" "missing $1"
}

render_launcher() {
  local enabled="$1"
  mkdir -p "$DESTINATION/bin"
  HOME="$DESTINATION" chezmoi -S "$DOTFILES_DIR" -D "$DESTINATION" \
    --persistent-state "$STATE" --override-data "{\"modules\":{\"hermesAgent\":{\"enabled\":$enabled}}}" \
    apply --exclude=scripts,externals --force -- "$LAUNCHER" >/dev/null
}

printf '%s\n' 'Hermes Agent Adapter Contract Tests'

assert_file "$MODULE_DIR/module.yaml" "module manifest exists"
assert_file "$MODULE_DIR/bin/hermes-dotfiles" "profile launcher exists"
assert_file "$DOTFILES_DIR/home/bin/executable_hermes-dotfiles.tmpl" "ChezMoi bridge exists"

if yq eval '.' "$MODULE_DIR/module.yaml" >/dev/null 2>&1; then
  pass "module manifest parses as YAML"
else
  fail "module manifest parses as YAML" "parse error"
fi

if render_launcher true && [[ -x "$LAUNCHER" ]]; then
  pass "enabled profile installs the launcher"
else
  fail "enabled profile installs the launcher" "render failed"
fi

mkdir -p "$FAKE_BIN" "$DESTINATION/.hermes/profiles/dotfiles"
cat >"$FAKE_BIN/hermes" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "profile" && "${2:-}" == "show" ]]; then
  [[ "${3:-}" == "dotfiles" ]]
  exit $?
fi
[[ -z "${HERMES_TEST_ENV_FILE:-}" ]] || printf '%s\n' "$AGENT_TODO_DIR" >"$HERMES_TEST_ENV_FILE"
printf '%s\n' "$*"
EOF
chmod +x "$FAKE_BIN/hermes"

default_output="$(HERMES_DOTFILES_BIN="$FAKE_BIN/hermes" "$LAUNCHER")"
[[ "$default_output" == "-p dotfiles --tui" ]] \
  && pass "launcher opens the dotfiles profile TUI by default" \
  || fail "launcher opens the dotfiles profile TUI by default" "got $default_output"

passthrough_output="$(HERMES_DOTFILES_BIN="$FAKE_BIN/hermes" "$LAUNCHER" config get model)"
[[ "$passthrough_output" == "-p dotfiles config get model" ]] \
  && pass "launcher passes explicit commands through" \
  || fail "launcher passes explicit commands through" "got $passthrough_output"

HOME="$DESTINATION" HERMES_TEST_ENV_FILE="$TEMP_DIR/todo-dir" HERMES_DOTFILES_BIN="$FAKE_BIN/hermes" "$LAUNCHER" status >/dev/null
[[ "$(cat "$TEMP_DIR/todo-dir")" == "$DESTINATION/.hermes/profiles/dotfiles/tasks" ]] \
  && pass "launcher isolates todo in the dotfiles profile" \
  || fail "launcher isolates todo in the dotfiles profile" "got $(cat "$TEMP_DIR/todo-dir")"

override_output="$(HERMES_DOTFILES_PROFILE=review HERMES_DOTFILES_BIN="$FAKE_BIN/hermes" "$LAUNCHER" status 2>"$TEMP_DIR/missing.err" || true)"
[[ -z "$override_output" ]] && grep -Fq "profile review is missing" "$TEMP_DIR/missing.err" \
  && pass "missing profile fails with actionable setup guidance" \
  || fail "missing profile fails with actionable setup guidance" "unexpected output"

mkdir -p "$DESTINATION/.hermes/profiles/dotfiles"
printf 'preserve\n' >"$DESTINATION/.hermes/profiles/dotfiles/sentinel"
if render_launcher false; then
  pass "disabled profile renders successfully"
else
  fail "disabled profile renders successfully" "render failed"
fi
[[ ! -e "$LAUNCHER" ]] \
  && pass "disabled profile removes the launcher" \
  || fail "disabled profile removes the launcher" "launcher remains"
[[ -f "$DESTINATION/.hermes/profiles/dotfiles/sentinel" ]] \
  && pass "disabled profile preserves Hermes state" \
  || fail "disabled profile preserves Hermes state" "profile state changed"

printf 'Results: %s passed, %s failed\n' "$PASSED" "$FAILED"
exit "$FAILED"
