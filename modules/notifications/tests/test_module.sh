#!/usr/bin/env bash

set -uo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$TEST_DIR")"
DOTFILES_DIR="$(cd "$MODULE_DIR/../.." && pwd)"
COMMAND="$MODULE_DIR/bin/desktop-notify"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-notifications-module.XXXXXX")"
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

echo "notifications module"

assert_file "$MODULE_DIR/module.yaml" "module manifest exists"
assert_file "$MODULE_DIR/README.md" "module documentation exists"
assert_file "$MODULE_DIR/docs/system-context.md" "shared system context exists"
assert_file "$COMMAND" "module owns the notification command"
assert_file "$MODULE_DIR/config/defaults.toml" "module owns standalone defaults"
assert_file "$MODULE_DIR/config/config.toml.tmpl" "module owns rendered configuration"
assert_file "$MODULE_DIR/lib/config.sh" "module owns its configuration adapter"
assert_file "$MODULE_DIR/settings.yaml" "module owns its settings fragment"
assert_contains "$DOTFILES_DIR/home/bin/executable_desktop-notify.tmpl" \
  'includeTemplate "../modules/notifications/bin/desktop-notify"' \
  "primary command bridge delegates to the module"
assert_contains "$DOTFILES_DIR/home/dot_config/skhd/executable_notify.sh.tmpl" \
  'includeTemplate "../modules/notifications/bin/desktop-notify"' \
  "legacy skhd bridge delegates to the module"
assert_contains "$DOTFILES_DIR/home/dot_agents/docs/system/notifications.md.tmpl" \
  'includeTemplate "../modules/notifications/docs/system-context.md"' \
  "shared context bridge delegates to the module"
assert_contains "$DOTFILES_DIR/home/dot_config/notifications/config.toml.tmpl" \
  'includeTemplate "../modules/notifications/config/config.toml.tmpl"' \
  "configuration bridge delegates to the module"
assert_contains "$DOTFILES_DIR/home/dot_config/notifications/config.sh.tmpl" \
  'includeTemplate "../modules/notifications/lib/config.sh"' \
  "configuration adapter bridge delegates to the module"

if bash -n "$COMMAND"; then
  pass "notification command parses as Bash"
else
  fail "notification command parses as Bash" "bash -n failed"
fi

if yq eval '.' "$MODULE_DIR/module.yaml" >/dev/null 2>&1; then
  pass "module manifest parses as YAML"
else
  fail "module manifest parses as YAML" "parse error"
fi

if yq eval '.' "$MODULE_DIR/settings.yaml" >/dev/null 2>&1; then
  pass "settings fragment parses as YAML"
else
  fail "settings fragment parses as YAML" "parse error"
fi

if yq -p=toml eval '.' "$MODULE_DIR/config/defaults.toml" >/dev/null 2>&1; then
  pass "standalone defaults parse as TOML"
else
  fail "standalone defaults parse as TOML" "parse error"
fi

cat >"$TEMP_DIR/terminal-notifier" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$NOTIFY_TEST_TERMINAL_LOG"
[[ "${NOTIFY_TEST_TERMINAL_FAIL:-0}" != "1" ]]
EOF

cat >"$TEMP_DIR/osascript" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$NOTIFY_TEST_OSASCRIPT_LOG"
cat >/dev/null
EOF

chmod +x "$TEMP_DIR/terminal-notifier" "$TEMP_DIR/osascript"

TERMINAL_LOG="$TEMP_DIR/terminal.log"
OSASCRIPT_LOG="$TEMP_DIR/osascript.log"

if PATH="$TEMP_DIR:/usr/bin:/bin" \
  NOTIFY_TEST_TERMINAL_LOG="$TERMINAL_LOG" \
  DESKTOP_NOTIFY_OSASCRIPT="$TEMP_DIR/osascript" \
  bash "$COMMAND" "Zen Mode" "Enabled"; then
  pass "auto backend delivers through terminal-notifier"
else
  fail "auto backend delivers through terminal-notifier" "command failed"
fi

if grep -Fxq -- '-title' "$TERMINAL_LOG" \
  && grep -Fxq -- 'Zen Mode' "$TERMINAL_LOG" \
  && grep -Fxq -- '-ignoreDnD' "$TERMINAL_LOG" \
  && grep -Fxq -- 'dotfiles.zen-mode' "$TERMINAL_LOG"; then
  pass "terminal-notifier receives title, Focus bypass, and scoped group"
else
  fail "terminal-notifier receives title, Focus bypass, and scoped group" "$(cat "$TERMINAL_LOG")"
fi

rm -f "$TERMINAL_LOG" "$OSASCRIPT_LOG"
if PATH="/usr/bin:/bin" \
  DESKTOP_NOTIFY_TERMINAL_NOTIFIER="$TEMP_DIR/missing" \
  DESKTOP_NOTIFY_OSASCRIPT="$TEMP_DIR/osascript" \
  NOTIFY_TEST_OSASCRIPT_LOG="$OSASCRIPT_LOG" \
  bash "$COMMAND" "Fallback" $'line one\nline two'; then
  pass "minimal PATH uses the AppleScript fallback"
else
  fail "minimal PATH uses the AppleScript fallback" "command failed"
fi

if grep -Fxq -- 'Fallback' "$OSASCRIPT_LOG" \
  && grep -Fxq -- 'line one · line two' "$OSASCRIPT_LOG"; then
  pass "AppleScript fallback receives a normalized multiline body"
else
  fail "AppleScript fallback receives a normalized multiline body" "$(cat "$OSASCRIPT_LOG")"
fi

rm -f "$TERMINAL_LOG" "$OSASCRIPT_LOG"
if PATH="$TEMP_DIR:/usr/bin:/bin" \
  NOTIFY_TEST_TERMINAL_FAIL=1 \
  NOTIFY_TEST_TERMINAL_LOG="$TERMINAL_LOG" \
  NOTIFY_TEST_OSASCRIPT_LOG="$OSASCRIPT_LOG" \
  DESKTOP_NOTIFY_OSASCRIPT="$TEMP_DIR/osascript" \
  bash "$COMMAND" "Fallback" "after backend failure"; then
  pass "auto backend falls back after terminal-notifier failure"
else
  fail "auto backend falls back after terminal-notifier failure" "command failed"
fi

[[ -f "$OSASCRIPT_LOG" ]] \
  && pass "fallback backend was invoked" \
  || fail "fallback backend was invoked" "osascript log missing"

if ! DESKTOP_NOTIFY_BACKEND=invalid bash "$COMMAND" "Invalid" "backend" >/dev/null 2>&1; then
  pass "unknown backend fails closed"
else
  fail "unknown backend fails closed" "command unexpectedly succeeded"
fi

if rendered_command=$(chezmoi -S "$DOTFILES_DIR" cat "$HOME/bin/desktop-notify" 2>/dev/null) \
  && grep -Fq 'find_terminal_notifier()' <<<"$rendered_command"; then
  pass "primary command renders from ChezMoi"
else
  fail "primary command renders from ChezMoi" "render failed"
fi

if rendered_context=$(chezmoi -S "$DOTFILES_DIR" cat "$HOME/.agents/docs/system/notifications.md" 2>/dev/null) \
  && grep -Fq '# Desktop notifications system context' <<<"$rendered_context"; then
  pass "shared system context renders from ChezMoi"
else
  fail "shared system context renders from ChezMoi" "render failed"
fi

RUNTIME_HOME="$TEMP_DIR/runtime-home"
RUNTIME_STATE="$TEMP_DIR/runtime-state.db"
mkdir -p "$RUNTIME_HOME"

if HOME="$RUNTIME_HOME" chezmoi -S "$DOTFILES_DIR" -D "$RUNTIME_HOME" \
  --persistent-state "$RUNTIME_STATE" apply --exclude=scripts,externals --force >/dev/null; then
  pass "enabled profile applies in a cold home"
else
  fail "enabled profile applies in a cold home" "chezmoi apply failed"
fi

[[ -x "$RUNTIME_HOME/bin/desktop-notify" ]] \
  && pass "enabled profile installs the primary command" \
  || fail "enabled profile installs the primary command" "command missing"
[[ -x "$RUNTIME_HOME/.config/skhd/notify.sh" ]] \
  && pass "enabled profile installs the compatibility adapter" \
  || fail "enabled profile installs the compatibility adapter" "adapter missing"
[[ -f "$RUNTIME_HOME/.agents/docs/system/notifications.md" ]] \
  && pass "enabled profile installs shared context" \
  || fail "enabled profile installs shared context" "context missing"
[[ -f "$RUNTIME_HOME/.config/notifications/config.toml" ]] \
  && pass "enabled profile installs notification configuration" \
  || fail "enabled profile installs notification configuration" "config missing"
[[ -f "$RUNTIME_HOME/.config/notifications/config.sh" ]] \
  && pass "enabled profile installs the configuration adapter" \
  || fail "enabled profile installs the configuration adapter" "adapter missing"
assert_contains "$RUNTIME_HOME/.config/notifications/config.toml" \
  'backend = "auto"' "enabled profile renders the managed backend"
assert_contains "$RUNTIME_HOME/.config/notifications/config.toml" \
  'ignore_dnd = true' "enabled profile renders the Focus-bypass setting"

if HOME="$RUNTIME_HOME" chezmoi -S "$DOTFILES_DIR" -D "$RUNTIME_HOME" \
  --persistent-state "$RUNTIME_STATE" \
  --override-data '{"modules":{"notifications":{"enabled":false}}}' \
  apply --exclude=scripts,externals --force >/dev/null; then
  pass "disabled profile re-renders in the same cold home"
else
  fail "disabled profile re-renders in the same cold home" "chezmoi apply failed"
fi

[[ ! -e "$RUNTIME_HOME/bin/desktop-notify" ]] \
  && pass "disabled profile removes the primary command" \
  || fail "disabled profile removes the primary command" "command remains"
[[ ! -e "$RUNTIME_HOME/.config/skhd/notify.sh" ]] \
  && pass "disabled profile removes the compatibility adapter" \
  || fail "disabled profile removes the compatibility adapter" "adapter remains"
[[ ! -e "$RUNTIME_HOME/.agents/docs/system/notifications.md" ]] \
  && pass "disabled profile removes shared context" \
  || fail "disabled profile removes shared context" "context remains"
[[ ! -e "$RUNTIME_HOME/.config/notifications/config.toml" ]] \
  && pass "disabled profile removes notification configuration" \
  || fail "disabled profile removes notification configuration" "config remains"
[[ ! -e "$RUNTIME_HOME/.config/notifications/config.sh" ]] \
  && pass "disabled profile removes the configuration adapter" \
  || fail "disabled profile removes the configuration adapter" "adapter remains"

echo "Results: $PASSED passed, $FAILED failed"
exit "$FAILED"
