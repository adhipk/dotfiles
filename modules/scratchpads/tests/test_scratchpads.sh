#!/usr/bin/env bash

set -u

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$TEST_DIR")"
SCRATCHPADS="$MODULE_DIR/bin/scratchpads"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/scratchpads-test.XXXXXX")"

PASSED=0
FAILED=0

pass() {
  printf '  ✓ %s\n' "$1"
  PASSED=$((PASSED + 1))
}

fail() {
  printf '  ✗ %s\n' "$1"
  FAILED=$((FAILED + 1))
}

assert_action() {
  local pattern="$1"
  local message="$2"

  if grep -Fqx -- "$pattern" "$ACTIONS_FILE"; then
    pass "$message"
  else
    fail "$message"
  fi
}

assert_no_action() {
  local pattern="$1"
  local message="$2"

  if grep -Fqx -- "$pattern" "$ACTIONS_FILE"; then
    fail "$message"
  else
    pass "$message"
  fi
}

cleanup() {
  rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT

# The helper guards main when sourced so its behavior can be exercised here.
source "$SCRATCHPADS"

printf '%s\n' '================================'
printf '%s\n' 'Scratchpad Behavior Tests'
printf '%s\n' '================================'

SCRATCHPAD_LOG_FILE="$TEMP_ROOT/scratchpads.log"
SCRATCHPAD_LOCK_ROOT="$TEMP_ROOT/scratchpads"
SCRATCHPAD_OPEN_LOCK_DIR=""

if acquire_scratchpad_open_lock terminal; then
  pass "first terminal scratchpad request acquires the launch lock"
else
  fail "first terminal scratchpad request acquires the launch lock"
fi

if acquire_scratchpad_open_lock terminal; then
  fail "concurrent terminal scratchpad request is ignored"
else
  pass "concurrent terminal scratchpad request is ignored"
fi
release_scratchpad_open_lock
trap cleanup EXIT

ACTIONS_FILE="$TEMP_ROOT/actions"
: > "$ACTIONS_FILE"

query_windows_json() {
  printf '%s\n' '[
    {"id":188,"app":"Ghostty","title":"scratchpad:terminal","scratchpad":"terminal"},
    {"id":189,"app":"Ghostty","title":"scratchpad:terminal","scratchpad":""},
    {"id":190,"app":"Ghostty","title":"normal terminal","scratchpad":""}
  ]'
}

log() {
  :
}

yabai() {
  printf '%s\n' "$*" >> "$ACTIONS_FILE"
}

close_duplicate_scratchpad_title_windows terminal 188
assert_action "-m window 189 --close" "same-title unlabeled Ghostty duplicate is closed"
assert_no_action "-m window 188 --close" "canonical labeled scratchpad is preserved"
assert_no_action "-m window 190 --close" "ordinary Ghostty windows are preserved"

: > "$ACTIONS_FILE"
CURRENT_TARGET="dotfiles"
VISIBLE_IDS="188"

ensure_tmux_target() { :; }
focused_display_index() { printf '%s\n' 1; }
focused_space_index() { printf '%s\n' 1; }
current_terminal_scratchpad_target() { printf '%s\n' "$CURRENT_TARGET"; }
scratchpad_ids() { printf '%s\n' 188; }
scratchpad_visible_ids() { printf '%s\n' "$VISIBLE_IDS"; }
close_duplicate_scratchpad_title_windows() { printf '%s\n' "reconcile $1 $2" >> "$ACTIONS_FILE"; }
hide_scratchpad_and_restore_focus() { printf '%s\n' "hide $1" >> "$ACTIONS_FILE"; }
switch_terminal_scratchpad_client() { printf '%s\n' "switch $1" >> "$ACTIONS_FILE"; }
focus_scratchpad_window() { printf '%s\n' "focus $1" >> "$ACTIONS_FILE"; }

open_terminal_tmux_scratchpad dotfiles
assert_action "hide terminal" "visible same-target scratchpad hides without requiring focus"
assert_no_action "switch dotfiles" "same-target toggle does not switch tmux context"

: > "$ACTIONS_FILE"
open_terminal_tmux_scratchpad projects
assert_action "switch projects" "visible different-target shortcut switches tmux context"
assert_action "focus 188" "different-target switch keeps the scratchpad visible and focused"
assert_no_action "hide terminal" "different-target switch does not hide the scratchpad"

: > "$ACTIONS_FILE"
VISIBLE_IDS="299"
ensure_session_manager_tmux_session() { printf '%s\n' "ensure sessions" >> "$ACTIONS_FILE"; }
hide_scratchpad_and_restore_focus() { printf '%s\n' "hide $1" >> "$ACTIONS_FILE"; }
open_session_manager_scratchpad
assert_action "ensure sessions" "session-manager scratchpad ensures its dedicated tmux template"
assert_action "hide session_manager" "Fn+P target hides an already-visible session manager"

: > "$ACTIONS_FILE"
VISIBLE_IDS=""
close_scratchpads_except_label() { printf '%s\n' "close except $1" >> "$ACTIONS_FILE"; }
close_duplicate_scratchpads_for_label() { printf '%s\n' "dedupe $1" >> "$ACTIONS_FILE"; }
open_or_focus_scratchpad_with_profile() {
  printf '%s\n' "open $1 $2 $3 $5" >> "$ACTIONS_FILE"
}
open_session_manager_scratchpad
assert_action "close except session_manager" "session manager closes other transient scratchpads"
assert_action "dedupe session_manager" "session manager removes duplicate floating windows"
assert_action "open session_manager codex $HOME $SCRATCHPADS_COMMAND tmux sessions" "session manager launches its dedicated tmux client"

printf '\n================================\n'
printf 'Results: %d passed, %d failed\n' "$PASSED" "$FAILED"
printf '%s\n' '================================'

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
