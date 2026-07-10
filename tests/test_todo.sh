#!/usr/bin/env bash

# Tests for the canonical todo.txt wrapper and its agent-write serialization.

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(dirname "$TEST_DIR")"
TODO_HELPER="$DOTFILES_DIR/home/bin/executable_todo"
TEMP_HOME="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-todo-test.XXXXXX")"
FAKE_BIN="$TEMP_HOME/bin"
PROJECT_DIR="$TEMP_HOME/project"
CALLS_FILE="$TEMP_HOME/tuxedo-calls"
OVERLAP_FILE="$TEMP_HOME/tuxedo-overlap"

PASSED=0
FAILED=0

cleanup() {
  rm -rf "$TEMP_HOME"
}
trap cleanup EXIT

pass() {
  echo "  ✓ $1"
  PASSED=$((PASSED + 1))
}

fail() {
  local name="$1"
  local expected="$2"
  local actual="$3"

  echo "  ✗ $name"
  echo "    Expected: $expected"
  echo "    Actual:   $actual"
  FAILED=$((FAILED + 1))
}

assert_equals() {
  local name="$1"
  local expected="$2"
  local actual="$3"

  if [[ "$actual" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name" "$expected" "$actual"
  fi
}

mkdir -p "$FAKE_BIN" "$PROJECT_DIR"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd -P)"
cat > "$FAKE_BIN/tuxedo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s|%s|%s|%s\n' "$TODO_DIR" "$TODO_FILE" "$DONE_FILE" "$*" >> "$TUXEDO_CALLS_FILE"

if [[ "${1:-}" == "fail" ]]; then
  exit 23
fi

if [[ "${1:-}" == "add" ]]; then
  critical="$TODO_DIR/.fake-critical-section"
  if ! mkdir "$critical" 2>/dev/null; then
    printf 'overlap\n' >> "$TUXEDO_OVERLAP_FILE"
    exit 41
  fi
  sleep 0.05
  printf '%s\n' "${2:-missing}" >> "$TODO_FILE"
  rmdir "$critical"
fi
EOF
chmod +x "$FAKE_BIN/tuxedo"
cd "$PROJECT_DIR"

echo "================================"
echo "Canonical todo.txt Tests"
echo "================================"

if [[ -x "$TODO_HELPER" ]]; then
  pass "todo helper is executable"
else
  fail "todo helper is executable" "executable" "missing or not executable"
fi

HOME="$TEMP_HOME" \
PATH="$FAKE_BIN:/usr/bin:/bin" \
TODO_DIR="/wrong" \
TODO_FILE="/wrong/todo.txt" \
DONE_FILE="/wrong/done.txt" \
TUXEDO_CALLS_FILE="$CALLS_FILE" \
TUXEDO_OVERLAP_FILE="$OVERLAP_FILE" \
  "$TODO_HELPER" ls --json

assert_equals \
  "wrapper pins every Tuxedo command to the canonical files" \
  "$PROJECT_DIR|$PROJECT_DIR/todo.txt|$PROJECT_DIR/done.txt|ls --json" \
  "$(tail -n 1 "$CALLS_FILE")"
assert_equals \
  "wrapper initializes todo.txt and done.txt in the working directory" \
  "done.txt:todo.txt" \
  "$(find "$PROJECT_DIR" -maxdepth 1 -type f -exec basename {} \; | sort | paste -sd: -)"
assert_equals \
  "wrapper does not change the project directory permissions" \
  "755" \
  "$(stat -f '%Lp' "$PROJECT_DIR")"

HOME="$TEMP_HOME" \
PATH="$FAKE_BIN:/usr/bin:/bin" \
TUXEDO_CALLS_FILE="$CALLS_FILE" \
TUXEDO_OVERLAP_FILE="$OVERLAP_FILE" \
  "$TODO_HELPER"
assert_equals \
  "interactive Tuxedo inherits cwd without a positional global file" \
  "$PROJECT_DIR|$PROJECT_DIR/todo.txt|$PROJECT_DIR/done.txt|" \
  "$(tail -n 1 "$CALLS_FILE")"

: > "$CALLS_FILE"
for index in 1 2 3 4 5 6; do
  HOME="$TEMP_HOME" \
  PATH="$FAKE_BIN:/usr/bin:/bin" \
  TUXEDO_CALLS_FILE="$CALLS_FILE" \
  TUXEDO_OVERLAP_FILE="$OVERLAP_FILE" \
    "$TODO_HELPER" add "task-$index" &
done
wait

assert_equals \
  "parallel agent mutations are serialized" \
  "6" \
  "$(grep -c '^task-' "$PROJECT_DIR/todo.txt")"
assert_equals \
  "serialized mutations never overlap Tuxedo critical sections" \
  "0" \
  "$(test -e "$OVERLAP_FILE" && wc -l < "$OVERLAP_FILE" | tr -d '[:space:]' || printf '0')"

FAIL_STATUS=0
HOME="$TEMP_HOME" \
PATH="$FAKE_BIN:/usr/bin:/bin" \
TUXEDO_CALLS_FILE="$CALLS_FILE" \
TUXEDO_OVERLAP_FILE="$OVERLAP_FILE" \
  "$TODO_HELPER" fail >/dev/null 2>&1 || FAIL_STATUS=$?
assert_equals "wrapper preserves Tuxedo failures" "23" "$FAIL_STATUS"

HOME="$TEMP_HOME" \
PATH="$FAKE_BIN:/usr/bin:/bin" \
TUXEDO_CALLS_FILE="$CALLS_FILE" \
TUXEDO_OVERLAP_FILE="$OVERLAP_FILE" \
  "$TODO_HELPER" ls >/dev/null
assert_equals \
  "a failed mutation releases the agent lock" \
  "missing" \
  "$(test -d "$PROJECT_DIR/.agent-write-lock" && printf present || printf missing)"

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

exit "$FAILED"
