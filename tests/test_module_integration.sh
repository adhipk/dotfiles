#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d "${TMPDIR:-/tmp}/module-integration-test.XXXXXX")"
FIXTURE="$TEMP/repo"
FAKE_BIN="$TEMP/bin"
LOG="$TEMP/events.log"
PASSED=0
FAILED=0
trap 'rm -rf "$TEMP"' EXIT

pass() { printf '  ok - %s\n' "$1"; PASSED=$((PASSED + 1)); }
fail() { printf '  not ok - %s: %s\n' "$1" "$2"; FAILED=$((FAILED + 1)); }

mkdir -p "$FIXTURE/home/bin" "$FIXTURE/modules/module-lifecycle/bin" "$FAKE_BIN"
printf 'home\n' >"$FIXTURE/.chezmoiroot"
cp "$ROOT/home/bin/executable_watch-sync" "$FIXTURE/home/bin/watch-sync"

cat >"$FIXTURE/modules/module-lifecycle/bin/dotfiles-module" <<'EOF'
#!/usr/bin/env bash
printf 'validate:%s:%s\n' "$DOTFILES_DIR" "$*" >>"$MODULE_INTEGRATION_LOG"
EOF

cat >"$FAKE_BIN/fswatch" <<'EOF'
#!/usr/bin/env bash
printf 'fswatch:%s\n' "$*" >>"$MODULE_INTEGRATION_LOG"
printf '1\n'
EOF

cat >"$FAKE_BIN/chezmoi" <<'EOF'
#!/usr/bin/env bash
printf 'chezmoi:%s\n' "$*" >>"$MODULE_INTEGRATION_LOG"
EOF

chmod +x \
  "$FIXTURE/home/bin/watch-sync" \
  "$FIXTURE/modules/module-lifecycle/bin/dotfiles-module" \
  "$FAKE_BIN/fswatch" \
  "$FAKE_BIN/chezmoi"

if HOME="$TEMP/home" \
  PATH="$FAKE_BIN:/usr/bin:/bin" \
  DOTFILES_DIR="$FIXTURE" \
  MODULE_INTEGRATION_LOG="$LOG" \
  "$FIXTURE/home/bin/watch-sync" >/dev/null; then
  pass "module-aware watcher completes one disposable event"
else
  fail "module-aware watcher completes one disposable event" "watch-sync failed"
fi

if grep -Fq "fswatch:-o $FIXTURE/home $FIXTURE/modules" "$LOG"; then
  pass "watcher observes both ChezMoi source state and module folders"
else
  fail "watcher observes both ChezMoi source state and module folders" "$(cat "$LOG")"
fi

if [[ "$(grep -c '^validate:' "$LOG" || true)" -eq 2 ]]; then
  pass "watcher validates manifests before watching and before applying"
else
  fail "watcher validates manifests before watching and before applying" "$(cat "$LOG")"
fi

if grep -Fq "chezmoi:-S $FIXTURE apply" "$LOG"; then
  pass "watcher applies through the existing ChezMoi source root"
else
  fail "watcher applies through the existing ChezMoi source root" "$(cat "$LOG")"
fi

if grep -Fq 'validate_modules' "$ROOT/install.sh" \
  && grep -Fq 'MODULE_CONTROLLER' "$ROOT/install.sh"; then
  pass "installer validates module manifests before apply"
else
  fail "installer validates module manifests before apply" "validation hook missing"
fi

printf '%s passed, %s failed\n' "$PASSED" "$FAILED"
[[ "$FAILED" -eq 0 ]]
