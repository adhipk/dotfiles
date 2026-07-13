#!/usr/bin/env bash

# Contract tests for the policy-free runtime shell library.

set -u

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(dirname "$TEST_DIR")"
LIB_DIR="$DOTFILES_DIR/home/dot_local/lib/dotfiles"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-lib-test.XXXXXX")"
FAKE_BIN="$TEMP_ROOT/bin"

PASSED=0
FAILED=0

cleanup() {
  rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT

pass() {
  printf '  ✓ %s\n' "$1"
  PASSED=$((PASSED + 1))
}

fail() {
  local name="$1"
  local expected="${2:-}"
  local actual="${3:-}"

  printf '  ✗ %s\n' "$name"
  if [ -n "$expected" ] || [ -n "$actual" ]; then
    printf '    Expected: %s\n' "$expected"
    printf '    Actual:   %s\n' "$actual"
  fi
  FAILED=$((FAILED + 1))
}

assert_equals() {
  local name="$1"
  local expected="$2"
  local actual="$3"

  if [ "$actual" = "$expected" ]; then
    pass "$name"
  else
    fail "$name" "$expected" "$actual"
  fi
}

assert_status() {
  local name="$1"
  local expected="$2"
  local actual="$3"

  assert_equals "$name" "$expected" "$actual"
}

assert_contains() {
  local name="$1"
  local haystack="$2"
  local needle="$3"

  case "$haystack" in
    *"$needle"*) pass "$name" ;;
    *) fail "$name" "contains: $needle" "$haystack" ;;
  esac
}

mkdir -p "$FAKE_BIN"

for library in core locks state tmux yabai ghostty; do
  if bash -n "$LIB_DIR/$library.sh" && zsh -n "$LIB_DIR/$library.sh"; then
    pass "$library.sh parses in the managed bash and zsh shells"
  else
    fail "$library.sh parses in the managed bash and zsh shells"
  fi
done

# shellcheck source=/dev/null
source "$LIB_DIR/core.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/locks.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/state.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/tmux.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/yabai.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/ghostty.sh"

printf '\nCore contracts\n'
DOTFILES_PROGRAM_NAME="dotfiles-lib-test"
assert_equals \
  "errors include a stable program and severity prefix" \
  "dotfiles-lib-test: error: broken" \
  "$(dotfiles_error broken 2>&1)"

STATUS=0
dotfiles_require_command "dotfiles-command-that-does-not-exist" "install it" >/dev/null 2>&1 || STATUS=$?
assert_status "missing commands return the conventional not-found status" "127" "$STATUS"
assert_status "an available command satisfies require-command" "0" "$(dotfiles_require_command sh; printf '%s' "$?")"

STATUS=0
dotfiles_die "stop" >/dev/null 2>&1 || STATUS=$?
assert_status "dotfiles_die reports failure without exiting its caller" "1" "$STATUS"
case "$(dotfiles_now_ms)" in
  *[!0-9]*|'') fail "millisecond clock returns an integer" "integer" "$(dotfiles_now_ms)" ;;
  *) pass "millisecond clock returns an integer" ;;
esac

printf '\nFilesystem lock contracts\n'
LOCK_DIR="$TEMP_ROOT/locks/primary.lock"
if dotfiles_lock_acquire "$LOCK_DIR"; then
  pass "a free filesystem lock is acquired"
else
  fail "a free filesystem lock is acquired"
fi
assert_equals "the lock records its owner PID" "$$" "$(cat "$LOCK_DIR/pid")"

STATUS=0
dotfiles_lock_acquire "$LOCK_DIR" 20 0.005 >/dev/null 2>&1 || STATUS=$?
assert_status "a live owner cannot be reaped while a contender waits" "1" "$STATUS"
assert_equals "timed-out contention leaves the live lock intact" "$$" "$(cat "$LOCK_DIR/pid")"
dotfiles_lock_release "$LOCK_DIR"
assert_equals "release removes the owned lock directory" "missing" "$(test -d "$LOCK_DIR" && printf present || printf missing)"

mkdir -p "$LOCK_DIR"
printf '%s\n' 99999999 > "$LOCK_DIR/pid"
if dotfiles_lock_acquire "$LOCK_DIR"; then
  pass "a dead-PID lock is atomically reaped"
else
  fail "a dead-PID lock is atomically reaped"
fi
assert_equals "stale-lock replacement records the new owner" "$$" "$(cat "$LOCK_DIR/pid")"
dotfiles_lock_release "$LOCK_DIR"

dotfiles_lock_acquire "$LOCK_DIR"
printf '%s\n' 1 > "$LOCK_DIR/pid"
STATUS=0
dotfiles_lock_release "$LOCK_DIR" >/dev/null 2>&1 || STATUS=$?
assert_status "release refuses to remove another process's lock" "1" "$STATUS"
printf '%s\n' "$$" > "$LOCK_DIR/pid"
dotfiles_lock_release "$LOCK_DIR"

dotfiles_test_lock_failure() {
  test -d "$LOCK_DIR" || return 98
  return 23
}
STATUS=0
dotfiles_lock_with "$LOCK_DIR" 0 -- dotfiles_test_lock_failure || STATUS=$?
assert_status "lock-with preserves the protected command status" "23" "$STATUS"
assert_equals "lock-with releases after command failure" "missing" "$(test -d "$LOCK_DIR" && printf present || printf missing)"

STATUS=0
dotfiles_lock_acquire "$LOCK_DIR" nope >/dev/null 2>&1 || STATUS=$?
assert_status "invalid lock timeouts are rejected as usage errors" "2" "$STATUS"
STATUS=0
dotfiles_lock_acquire "$LOCK_DIR" 10 0 >/dev/null 2>&1 || STATUS=$?
assert_status "zero lock polling intervals are rejected" "2" "$STATUS"

mkdir -p "$LOCK_DIR"
STATUS=0
dotfiles_lock_acquire "$LOCK_DIR" >/dev/null 2>&1 || STATUS=$?
assert_status "a newly-created pidless lock is not mistaken for stale" "1" "$STATUS"
rmdir "$LOCK_DIR"

LOCK_TARGET="$TEMP_ROOT/locks/symlink-target"
mkdir -p "$LOCK_TARGET"
ln -s "$LOCK_TARGET" "$LOCK_DIR"
STATUS=0
dotfiles_lock_acquire "$LOCK_DIR" >/dev/null 2>&1 || STATUS=$?
assert_status "lock acquisition never reaps a symbolic-link path" "1" "$STATUS"
STATUS=0
dotfiles_lock_release "$LOCK_DIR" >/dev/null 2>&1 || STATUS=$?
assert_status "lock release refuses symbolic-link paths" "1" "$STATUS"

printf '\nState and atomic-write contracts\n'
XDG_STATE_HOME="$TEMP_ROOT/state root"
export XDG_STATE_HOME
assert_equals \
  "state namespaces live below XDG_STATE_HOME" \
  "$XDG_STATE_HOME/dotfiles/desktop.test" \
  "$(dotfiles_state_dir desktop.test)"

dotfiles_state_ensure_dir desktop.test
assert_equals \
  "module state directories are private" \
  "700" \
  "$(stat -f '%Lp' "$XDG_STATE_HOME/dotfiles/desktop.test")"

printf 'first\n' | dotfiles_state_write desktop.test nested/value.txt
STATE_FILE="$XDG_STATE_HOME/dotfiles/desktop.test/nested/value.txt"
assert_equals "state writes create nested paths" "first" "$(cat "$STATE_FILE")"
assert_equals "state files default to private permissions" "600" "$(stat -f '%Lp' "$STATE_FILE")"
printf 'second\n' | dotfiles_state_write desktop.test nested/value.txt 640
assert_equals "state writes atomically replace existing content" "second" "$(cat "$STATE_FILE")"
assert_equals "callers may select an explicit output mode" "640" "$(stat -f '%Lp' "$STATE_FILE")"
assert_equals \
  "successful atomic writes leave no staging files" \
  "0" \
  "$(find "$(dirname "$STATE_FILE")" -name 'value.txt.tmp.*' | wc -l | tr -d '[:space:]')"

STATUS=0
printf 'unsafe\n' | dotfiles_atomic_write "$XDG_STATE_HOME/dotfiles/desktop.test" >/dev/null 2>&1 || STATUS=$?
assert_status "atomic writes reject directory destinations" "2" "$STATUS"

STATUS=0
dotfiles_state_file desktop.test ../escape >/dev/null 2>&1 || STATUS=$?
assert_status "state paths reject parent traversal" "2" "$STATUS"
XDG_STATE_HOME="relative/state"
STATUS=0
dotfiles_state_home >/dev/null 2>&1 || STATUS=$?
assert_status "relative XDG state roots are rejected" "2" "$STATUS"
XDG_STATE_HOME="$TEMP_ROOT/state root"

printf '\nTmux adapter contracts\n'
TMUX_LOG="$TEMP_ROOT/tmux.log"
export DOTFILES_TEST_TMUX_LOG="$TMUX_LOG"
cat > "$FAKE_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$DOTFILES_TEST_TMUX_LOG"
EOF
chmod +x "$FAKE_BIN/tmux"
DOTFILES_TMUX_BIN="$FAKE_BIN/tmux"
DOTFILES_TMUX_SOCKET_NAME="unit-socket"
DOTFILES_TMUX_SOCKET_PATH=""
dotfiles_tmux_cmd list-sessions
assert_equals "tmux socket names use the native -L selector" "-L unit-socket list-sessions" "$(tail -n 1 "$TMUX_LOG")"

DOTFILES_TMUX_SOCKET_NAME=""
DOTFILES_TMUX_SOCKET_PATH="$TEMP_ROOT/tmux.sock"
dotfiles_tmux_cmd display-message -p ok
assert_equals \
  "tmux socket paths use the native -S selector" \
  "-S $TEMP_ROOT/tmux.sock display-message -p ok" \
  "$(tail -n 1 "$TMUX_LOG")"

DOTFILES_TMUX_SOCKET_NAME="conflict"
STATUS=0
dotfiles_tmux_cmd list-sessions >/dev/null 2>&1 || STATUS=$?
assert_status "conflicting tmux socket selectors are rejected" "2" "$STATUS"

DOTFILES_TMUX_SOCKET_NAME=""
DOTFILES_TMUX_SOCKET_PATH=""
: > "$TMUX_LOG"
dotfiles_test_tmux_failure() {
  printf '%s\n' action >> "$TMUX_LOG"
  return 23
}
STATUS=0
dotfiles_tmux_with_lock "unit-channel" -- dotfiles_test_tmux_failure || STATUS=$?
assert_status "tmux lock wrappers preserve command failures" "23" "$STATUS"
assert_equals \
  "tmux lock wrappers acquire, run, and always release in order" \
  $'wait-for -L unit-channel\naction\nwait-for -U unit-channel' \
  "$(cat "$TMUX_LOG")"

printf '\nYabai and Ghostty adapter contracts\n'
YABAI_LOG="$TEMP_ROOT/yabai.log"
WINDOWS_JSON="$TEMP_ROOT/windows.json"
export DOTFILES_TEST_YABAI_LOG="$YABAI_LOG"
export DOTFILES_TEST_WINDOWS_JSON="$WINDOWS_JSON"
cat > "$FAKE_BIN/yabai" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  '-m query --displays --display') printf '%s\n' '{"index":2}' ;;
  '-m query --spaces --space') printf '%s\n' '{"index":7}' ;;
  '-m query --windows --window')
    if [ "${DOTFILES_TEST_NO_FOCUSED_WINDOW:-0}" = 1 ]; then
      exit 1
    fi
    printf '%s\n' '{"id":42,"app":"Editor"}'
    ;;
  '-m query --windows') cat "$DOTFILES_TEST_WINDOWS_JSON" ;;
  '-m display --focus '*|'-m space --focus '*|'-m window --focus '*)
    printf '%s\n' "$*" >> "$DOTFILES_TEST_YABAI_LOG"
    ;;
  *)
    printf 'unexpected yabai call: %s\n' "$*" >&2
    exit 90
    ;;
esac
EOF
chmod +x "$FAKE_BIN/yabai"
DOTFILES_YABAI_BIN="$FAKE_BIN/yabai"

ORIGIN=$(dotfiles_yabai_capture_focus_origin)
assert_equals \
  "focus capture produces a stable JSON contract" \
  '{"displayIndex":2,"spaceIndex":7,"windowId":42}' \
  "$ORIGIN"
: > "$YABAI_LOG"
dotfiles_yabai_restore_focus_origin "$ORIGIN"
assert_equals \
  "focus restore uses display, space, then window order" \
  $'-m display --focus 2\n-m space --focus 7\n-m window --focus 42' \
  "$(cat "$YABAI_LOG")"

: > "$YABAI_LOG"
STATUS=0
dotfiles_yabai_restore_focus_origin '{"displayIndex":2.5,"spaceIndex":7,"windowId":42}' >/dev/null 2>&1 || STATUS=$?
assert_status "focus restore rejects non-integer yabai identifiers" "2" "$STATUS"
assert_equals "invalid focus origins do not invoke yabai" "" "$(cat "$YABAI_LOG")"

DOTFILES_TEST_NO_FOCUSED_WINDOW=1
export DOTFILES_TEST_NO_FOCUSED_WINDOW
assert_equals \
  "focus capture tolerates a desktop with no focused window" \
  '{"displayIndex":2,"spaceIndex":7,"windowId":null}' \
  "$(dotfiles_yabai_capture_focus_origin)"
unset DOTFILES_TEST_NO_FOCUSED_WINDOW

cat > "$WINDOWS_JSON" <<'EOF'
[
  {"id":1,"app":"Ghostty","title":"old"},
  {"id":2,"app":"Ghostty","title":"wanted"},
  {"id":3,"app":"Ghostty","title":"fallback"},
  {"id":9,"app":"Safari","title":"wanted"}
]
EOF
assert_equals "Ghostty discovery returns only Ghostty IDs" "[1,2,3]" "$(dotfiles_ghostty_window_ids_json)"
assert_equals \
  "new-window discovery prefers a matching title among unseen IDs" \
  "2" \
  "$(dotfiles_ghostty_find_new_window_id wanted '[1]')"
assert_equals \
  "Ghostty waits return an already-observable new window immediately" \
  "2" \
  "$(dotfiles_ghostty_wait_for_window wanted '[1]' 100 0.005)"

STATUS=0
dotfiles_ghostty_wait_for_window wanted '[1,2,3]' 20 0.005 >/dev/null 2>&1 || STATUS=$?
assert_status "Ghostty waits are bounded when no new window appears" "1" "$STATUS"
STATUS=0
dotfiles_ghostty_find_new_window_id wanted '{bad json}' >/dev/null 2>&1 || STATUS=$?
assert_status "Ghostty discovery rejects malformed before-ID data" "2" "$STATUS"
STATUS=0
dotfiles_ghostty_wait_for_window wanted '{bad json}' 20 0.005 >/dev/null 2>&1 || STATUS=$?
assert_status "Ghostty waits reject malformed before-ID data before polling" "2" "$STATUS"

printf '\n================================\n'
printf 'Results: %d passed, %d failed\n' "$PASSED" "$FAILED"
printf '%s\n' '================================'

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
