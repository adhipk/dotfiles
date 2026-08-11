#!/usr/bin/env bash

set -uo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMAND="$(dirname "$TEST_DIR")/bin/daemon"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-daemon-test.XXXXXX")"
FAKE_BIN="$TEMP_DIR/bin"
TMUX_LOG="$TEMP_DIR/tmux.log"
PASSED=0
FAILED=0

cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT
mkdir -p "$FAKE_BIN" "$TEMP_DIR/logs"

pass() { printf '  ✓ %s\n' "$1"; PASSED=$((PASSED + 1)); }
fail() { printf '  ✗ %s\n    Expected: %s\n    Actual:   %s\n' "$1" "$2" "$3"; FAILED=$((FAILED + 1)); }

if "$COMMAND" >/dev/null 2>&1; then
  fail "missing arguments fail" "nonzero" "zero"
else
  pass "missing arguments fail"
fi

if "$COMMAND" '../unsafe' printf nope >/dev/null 2>&1; then
  fail "unsafe names fail" "nonzero" "zero"
else
  pass "unsafe names fail"
fi

cat >"$FAKE_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == has-session ]]; then exit 1; fi
printf '%s\n' "$*" >>"$DAEMON_TEST_TMUX_LOG"
EOF
chmod +x "$FAKE_BIN/tmux"

OUTPUT=$(DAEMON_LOG_DIR="$TEMP_DIR/logs" DAEMON_TMUX_BIN="$FAKE_BIN/tmux" \
  DAEMON_TEST_TMUX_LOG="$TMUX_LOG" "$COMMAND" smoke printf 'daemon-ok\n')

for _ in {1..20}; do
  [[ -s "$TEMP_DIR/logs/smoke.log" ]] && break
  sleep 0.05
done

[[ "$(cat "$TEMP_DIR/logs/smoke.log" 2>/dev/null)" == daemon-ok ]] \
  && pass "background command writes its log" \
  || fail "background command writes its log" daemon-ok "$(cat "$TEMP_DIR/logs/smoke.log" 2>/dev/null)"
[[ "$(cat "$TEMP_DIR/logs/smoke.pid" 2>/dev/null)" =~ ^[0-9]+$ ]] \
  && pass "background command writes its pid" \
  || fail "background command writes its pid" "numeric pid" "$(cat "$TEMP_DIR/logs/smoke.pid" 2>/dev/null)"
grep -Fq 'new-session -d -e DOTFILES_TMUX_TEMPLATE=skip -s daemon-smoke' "$TMUX_LOG" \
  && pass "log session skips the standard template" \
  || fail "log session skips the standard template" "skip environment" "$(cat "$TMUX_LOG" 2>/dev/null)"
grep -Fq -- "-c $(pwd) -n logs" "$TMUX_LOG" \
  && pass "log session starts in the invoking directory" \
  || fail "log session starts in the invoking directory" "cwd and logs window" "$(cat "$TMUX_LOG" 2>/dev/null)"
grep -Fq "Started PID" <<<"$OUTPUT" \
  && pass "command reports startup" \
  || fail "command reports startup" "Started PID" "$OUTPUT"

printf '\nResults: %s passed, %s failed\n' "$PASSED" "$FAILED"
exit "$FAILED"
