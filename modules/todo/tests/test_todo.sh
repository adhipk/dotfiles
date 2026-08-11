#!/usr/bin/env bash

set -uo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$TEST_DIR")"
DOTFILES_DIR="${TODO_TEST_REPO_ROOT:-$(cd "$MODULE_DIR/../.." && pwd)}"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-todo-adapter.XXXXXX")"
TEMP_DIR="$(cd "$TEMP_DIR" && pwd -P)"
DESTINATION="$TEMP_DIR/home"
STATE="$TEMP_DIR/state.db"
CHECKOUT="$DESTINATION/projects/tuxedo-project-todo"
EXTERNAL_COMMAND="$CHECKOUT/bin/todo"
PROJECT_DIR="$TEMP_DIR/project"
CALLS_FILE="$TEMP_DIR/todo-adapter-calls"
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
  if [[ ! -e "$1" && ! -L "$1" ]]; then
    pass "$2"
  else
    fail "$2" absent "$1 exists"
  fi
}

render_parent() {
  local enabled="$1"
  HOME="$DESTINATION" chezmoi -S "$DOTFILES_DIR" -D "$DESTINATION" --persistent-state "$STATE" \
    --override-data "{\"modules\":{\"todo\":{\"enabled\":$enabled}}}" \
    apply --exclude=scripts,externals --force \
    "$DESTINATION/bin/todo" "$DESTINATION/bin/chezmoi-todo" >/dev/null
}

printf '%s\n' '=============================' 'todo Adapter Contract Tests' '============================='

manifest_values="$(yq -r '[.id, .dataKey, .distribution.chezmoiCommand, .state.preserved[0], .state.preserved[1], .state.preserved[2], .state.ephemeral[0]] | join("|")' "$MODULE_DIR/module.yaml" 2>/dev/null || true)"
if [[ "$manifest_values" == 'todo|modules.todo|todo|~/.agents/tasks/todo.txt|~/.agents/tasks/done.txt|~/.agents/tasks/handoffs|~/.agents/tasks/.agent-write-lock' ]]; then
  pass "manifest preserves todo identity, dispatch, and state contract"
else
  fail "manifest preserves todo identity, dispatch, and state contract" \
    'todo|modules.todo|todo|~/.agents/tasks/todo.txt|~/.agents/tasks/done.txt|~/.agents/tasks/handoffs|~/.agents/tasks/.agent-write-lock' "$manifest_values"
fi

rendered_path="$(HOME="$DESTINATION" chezmoi -S "$DOTFILES_DIR" -D "$DESTINATION" execute-template <"$MODULE_DIR/targets/todo-path.tmpl")"
if [[ "$rendered_path" == "$EXTERNAL_COMMAND" ]]; then
  pass "path template resolves the external checkout command"
else
  fail "path template resolves the external checkout command" "$EXTERNAL_COMMAND" "$rendered_path"
fi

if grep -Fq '.modules.todo.enabled' "$DOTFILES_DIR/home/bin/symlink_todo.tmpl" \
  && grep -Fq '../../modules/todo/targets/todo-path.tmpl' "$DOTFILES_DIR/home/bin/symlink_todo.tmpl" \
  && grep -Fq '.modules.todo.enabled' "$DOTFILES_DIR/home/bin/symlink_chezmoi-todo.tmpl" \
  && grep -Fq '../../modules/todo/targets/todo-path.tmpl' "$DOTFILES_DIR/home/bin/symlink_chezmoi-todo.tmpl"; then
  pass "parent exposes two gated in-module path adapters"
else
  fail "parent exposes two gated in-module path adapters" "two todo symlink adapters" "adapter missing or miswired"
fi

if [[ ! -e "$MODULE_DIR/bin/todo" ]] \
  && [[ ! -e "$DOTFILES_DIR/home/bin/executable_todo.tmpl" ]] \
  && [[ ! -e "$DOTFILES_DIR/home/bin/executable_chezmoi-todo.tmpl" ]]; then
  pass "parent contains no embedded todo implementation"
else
  fail "parent contains no embedded todo implementation" "only path and symlink adapters" "embedded command or executable template remains"
fi

mkdir -p "$CHECKOUT/bin" "$DESTINATION/bin" "$PROJECT_DIR"
cat >"$EXTERNAL_COMMAND" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s|%s\n' "$PWD" "$*" >>"$TODO_ADAPTER_CALLS"
EOF
chmod +x "$EXTERNAL_COMMAND"

if render_parent true; then
  pass "enabled parent render succeeds"
else
  fail "enabled parent render succeeds" "successful targeted apply" "apply failed"
fi
assert_symlink "$DESTINATION/bin/todo" "$EXTERNAL_COMMAND" "enabled module links todo"
assert_symlink "$DESTINATION/bin/chezmoi-todo" "$EXTERNAL_COMMAND" "enabled module links chezmoi-todo"

(
  cd "$PROJECT_DIR"
  TODO_ADAPTER_CALLS="$CALLS_FILE" "$DESTINATION/bin/todo" direct-dispatch
)
if [[ "$(tail -n 1 "$CALLS_FILE")" == "$PROJECT_DIR|direct-dispatch" ]]; then
  pass "direct todo entrypoint dispatches to the external command"
else
  fail "direct todo entrypoint dispatches to the external command" "$PROJECT_DIR|direct-dispatch" "$(tail -n 1 "$CALLS_FILE")"
fi

CHEZMOI_BIN="$(command -v chezmoi || true)"
(
  cd "$PROJECT_DIR"
  HOME="$DESTINATION" PATH="$DESTINATION/bin:/usr/bin:/bin" TODO_ADAPTER_CALLS="$CALLS_FILE" \
    "$CHEZMOI_BIN" todo plugin-dispatch
)
if [[ "$(tail -n 1 "$CALLS_FILE")" == "$PROJECT_DIR|plugin-dispatch" ]]; then
  pass "chezmoi todo dispatches through the external command"
else
  fail "chezmoi todo dispatches through the external command" "$PROJECT_DIR|plugin-dispatch" "$(tail -n 1 "$CALLS_FILE")"
fi

SHARED_STORE="$DESTINATION/.agents/tasks"
mkdir -p "$SHARED_STORE/handoffs"
printf 'keep todo\n' >"$SHARED_STORE/todo.txt"
printf 'keep done\n' >"$SHARED_STORE/done.txt"
printf 'keep handoff\n' >"$SHARED_STORE/handoffs/task.md"
if render_parent false; then
  pass "disabled parent render succeeds"
else
  fail "disabled parent render succeeds" "successful targeted apply" "apply failed"
fi
assert_absent "$DESTINATION/bin/todo" "disabled module removes todo link"
assert_absent "$DESTINATION/bin/chezmoi-todo" "disabled module removes chezmoi-todo link"
if [[ -x "$EXTERNAL_COMMAND" ]]; then
  pass "disabled module preserves the external checkout"
else
  fail "disabled module preserves the external checkout" "external command present" "external command missing"
fi
if [[ "$(cat "$SHARED_STORE/todo.txt")" == 'keep todo' ]] \
  && [[ "$(cat "$SHARED_STORE/done.txt")" == 'keep done' ]] \
  && [[ "$(cat "$SHARED_STORE/handoffs/task.md")" == 'keep handoff' ]]; then
  pass "disabled module preserves the shared task store"
else
  fail "disabled module preserves the shared task store" "ledgers and handoff contents" "shared state missing or changed"
fi

REMOVAL_REPO="$TEMP_DIR/removal-repo"
REMOVAL_HOME="$TEMP_DIR/removal-home"
mkdir -p "$REMOVAL_HOME" "$REMOVAL_REPO/home/bin" "$REMOVAL_REPO/home/.chezmoidata" "$REMOVAL_REPO/modules"
printf 'home\n' >"$REMOVAL_REPO/.chezmoiroot"
cp "$DOTFILES_DIR/home/bin/symlink_todo.tmpl" "$REMOVAL_REPO/home/bin/"
cp "$DOTFILES_DIR/home/bin/symlink_chezmoi-todo.tmpl" "$REMOVAL_REPO/home/bin/"
cp -R "$MODULE_DIR" "$REMOVAL_REPO/modules/todo"
printf 'modules:\n  todo:\n    enabled: false\n' >"$REMOVAL_REPO/home/.chezmoidata/10-modules.yaml"
printf 'parent survives\n' >"$REMOVAL_REPO/home/dot_parent-sentinel"
rm -rf "$REMOVAL_REPO/modules/todo"
if HOME="$REMOVAL_HOME" chezmoi -S "$REMOVAL_REPO" -D "$REMOVAL_HOME" \
  --persistent-state "$TEMP_DIR/removal-state.db" apply --exclude=scripts,externals --force >/dev/null \
  && [[ "$(cat "$REMOVAL_HOME/.parent-sentinel")" == 'parent survives' ]] \
  && [[ ! -e "$REMOVAL_HOME/bin/todo" && ! -e "$REMOVAL_HOME/bin/chezmoi-todo" ]]; then
  pass "disabled parent renders after the adapter module is removed"
else
  fail "disabled parent renders after the adapter module is removed" "healthy unrelated target" "removal contract failed"
fi

printf '\nResults: %s passed, %s failed\n' "$PASSED" "$FAILED"
exit "$FAILED"
