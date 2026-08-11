#!/usr/bin/env bash

set -uo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$TEST_DIR")"
DOTFILES_DIR="$(cd "$MODULE_DIR/../.." && pwd)"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-settings-module.XXXXXX")"
DESTINATION="$TEMP_DIR/home"
STATE="$TEMP_DIR/state.db"
FAKE_BIN="$TEMP_DIR/bin"
CLI="$MODULE_DIR/bin/dotfiles-settings"
PASSED=0
FAILED=0

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

pass() {
  printf '  ✓ %s\n' "$1"
  PASSED=$((PASSED + 1))
}

fail() {
  printf '  ✗ %s\n    Expected: %s\n    Actual:   %s\n' "$1" "$2" "$3"
  FAILED=$((FAILED + 1))
}

assert_file() {
  if [[ -f "$1" ]]; then
    pass "$2"
  else
    fail "$2" "$1" "missing"
  fi
}

assert_executable() {
  if [[ -x "$1" ]]; then
    pass "$2"
  else
    fail "$2" "$1" "missing or not executable"
  fi
}

assert_contains() {
  if grep -Fq -- "$2" "$1"; then
    pass "$3"
  else
    fail "$3" "text containing $2" "$1"
  fi
}

assert_equals() {
  if [[ "$1" == "$2" ]]; then
    pass "$3"
  else
    fail "$3" "$1" "$2"
  fi
}

render_profile() {
  local override_data="${1:-}"
  mkdir -p "$DESTINATION"
  local -a args=(
    -S "$DOTFILES_DIR"
    -D "$DESTINATION"
    --persistent-state "$STATE"
  )
  if [[ -n "$override_data" ]]; then
    args+=(--override-data "$override_data")
  fi
  chezmoi "${args[@]}" apply --exclude=scripts,externals --force >/dev/null
}

echo "================================"
echo "Settings Module Tests"
echo "================================"

echo ""
echo "Testing module contract..."
assert_file "$MODULE_DIR/module.yaml" "module manifest exists"
if yq -e '.id == "settings" and .dataKey == "modules.settings"' "$MODULE_DIR/module.yaml" >/dev/null 2>&1; then
  pass "manifest declares the settings id and dataKey"
else
  fail "manifest declares the settings id and dataKey" "id settings / modules.settings" "$(yq -r '.id' "$MODULE_DIR/module.yaml")"
fi
assert_file "$MODULE_DIR/registry.yaml" "settings registry exists"
assert_file "$DOTFILES_DIR/home/bin/executable_dotfiles-settings.tmpl" "command bridge exists"
assert_file "$DOTFILES_DIR/home/dot_config/dotfiles/preferences.toml.tmpl" "preferences bridge exists"
assert_file "$DOTFILES_DIR/home/dot_local/lib/dotfiles/prefs.sh" "shared prefs library exists"

echo ""
echo "Testing registry validation..."
if DOTFILES_DIR="$DOTFILES_DIR" "$CLI" validate --json | jq -e '.valid == true' >/dev/null 2>&1; then
  pass "registry validates against the repository"
else
  fail "registry validates against the repository" "valid: true" "validate failed"
fi

echo ""
echo "Testing default rendering..."
render_profile
assert_executable "$DESTINATION/bin/dotfiles-settings" "dotfiles-settings command renders"
assert_contains "$DESTINATION/.config/dotfiles/preferences.toml" 'assistant = "codex"' "preferences render the default assistant"
assert_contains "$DESTINATION/.config/dotfiles/preferences.toml" 'terminal_editor = "nvim"' "preferences render the default terminal editor"
assert_contains "$DESTINATION/.zshrc" "export EDITOR=nvim" "zshrc renders the default EDITOR"
assert_contains "$DESTINATION/.skhdrc" 'alt - 1 : ~/bin/hotkeys app-focus 1 "@browser"' "skhd renders the default slot1"
assert_contains "$DESTINATION/.skhdrc" 'alt - 3 : ~/bin/hotkeys app-focus 3 "Microsoft Teams"' "skhd renders the default slot3"
assert_contains "$DESTINATION/.skhdrc" '~/.config/skhd/focus_app.sh "Ghostty"' "skhd renders the default terminal app"
assert_contains "$DESTINATION/.tmux.conf" '@catppuccin_flavor "mocha"' "tmux renders the default flavor"
assert_contains "$DESTINATION/.config/app-focus/config.toml" 'editor = "VSCodium"' "app-focus renders the default GUI editor"
assert_equals "catppuccin-mocha.sh" "$(readlink "$DESTINATION/.config/colorschemes/colors.sh")" "colorscheme symlink targets the default scheme"

echo ""
echo "Testing preference override rendering..."
render_profile '{"preferences":{"terminalEditor":"hx","guiEditor":"Zed","assistant":"claude","terminalApp":"kitty","appSlots":{"slot1":"@browser","slot2":"@editor","slot3":"Calendar","slot4":"Slack"},"theme":{"tmuxFlavor":"latte","colorscheme":"catppuccin-mocha"}}}'
assert_contains "$DESTINATION/.config/dotfiles/preferences.toml" 'assistant = "claude"' "assistant override reaches preferences"
assert_contains "$DESTINATION/.zshrc" "export EDITOR=hx" "terminal editor override reaches zshrc"
assert_contains "$DESTINATION/.skhdrc" 'alt - 3 : ~/bin/hotkeys app-focus 3 "Calendar"' "slot3 override reaches skhd"
assert_contains "$DESTINATION/.skhdrc" '~/.config/skhd/focus_app.sh "kitty"' "terminal app override reaches skhd"
assert_contains "$DESTINATION/.tmux.conf" '@catppuccin_flavor "latte"' "flavor override reaches tmux"
assert_contains "$DESTINATION/.config/app-focus/config.toml" 'editor = "Zed"' "GUI editor override reaches app-focus"
render_profile

echo ""
echo "Testing CLI behavior against an isolated data file..."
mkdir -p "$FAKE_BIN"
TEST_DATA="$TEMP_DIR/data.yaml"
TEST_REGISTRY="$TEMP_DIR/registry.yaml"
cat >"$TEST_DATA" <<'EOF'
preferences:
  assistant: codex
  theme:
    tmuxFlavor: mocha
modules:
  agentTimer:
    autoStart: false
    defaultSeconds: 600
EOF
cat >"$TEST_REGISTRY" <<'EOF'
apiVersion: dotfiles/v1
kind: SettingsRegistry
schemaVersion: 1
settings:
  - key: assistant
    description: test assistant
    dataPath: preferences.assistant
    file: home/.chezmoidata/20-preferences.yaml
    type: string
    values:
      provider: path-commands
      candidates: [codex]
      freeText: true
    bridges:
      - home/dot_config/dotfiles/preferences.toml.tmpl
    reload: []
  - key: theme.tmuxFlavor
    description: test flavor
    dataPath: preferences.theme.tmuxFlavor
    file: home/.chezmoidata/20-preferences.yaml
    type: string
    values:
      enum: [mocha, latte]
    bridges:
      - home/dot_tmux.conf.tmpl
    reload: []
  - key: agent-timer.autoStart
    description: test boolean
    dataPath: modules.agentTimer.autoStart
    file: home/.chezmoidata/10-modules.yaml
    type: boolean
    bridges:
      - home/dot_config/agent-timer/config.toml.tmpl
    reload: []
  - key: agent-timer.defaultSeconds
    description: test integer
    dataPath: modules.agentTimer.defaultSeconds
    file: home/.chezmoidata/10-modules.yaml
    type: integer
    values:
      min: 60
      max: 14400
    bridges:
      - home/dot_config/agent-timer/config.toml.tmpl
    reload: []
EOF

run_cli() {
  DOTFILES_DIR="$DOTFILES_DIR" \
  DOTFILES_SETTINGS_REGISTRY="$TEST_REGISTRY" \
  DOTFILES_SETTINGS_DATA_FILE="$TEST_DATA" \
  "$CLI" "$@"
}

assert_equals "codex" "$(run_cli get assistant)" "get reads the isolated data file"
if run_cli list --json | jq -e '.settings | length == 4' >/dev/null 2>&1; then
  pass "list --json reports every registry entry"
else
  fail "list --json reports every registry entry" "4 settings" "$(run_cli list --json 2>&1)"
fi

run_cli set assistant claude --no-apply --no-reload >/dev/null
assert_equals "claude" "$(run_cli get assistant)" "set round-trips a string value"
run_cli set agent-timer.autoStart true --no-apply --no-reload >/dev/null
assert_equals "true" "$(run_cli get agent-timer.autoStart)" "set round-trips a boolean value"
run_cli set agent-timer.defaultSeconds 900 --no-apply --no-reload >/dev/null
assert_equals "900" "$(run_cli get agent-timer.defaultSeconds)" "set round-trips an integer value"

if run_cli set theme.tmuxFlavor neon --no-apply --no-reload >/dev/null 2>&1; then
  fail "set rejects a value outside the enum" "nonzero exit" "accepted neon"
else
  pass "set rejects a value outside the enum"
fi
if run_cli set agent-timer.defaultSeconds 5 --no-apply --no-reload >/dev/null 2>&1; then
  fail "set rejects an integer below the minimum" "nonzero exit" "accepted 5"
else
  pass "set rejects an integer below the minimum"
fi
if run_cli set agent-timer.autoStart maybe --no-apply --no-reload >/dev/null 2>&1; then
  fail "set rejects a non-boolean value" "nonzero exit" "accepted maybe"
else
  pass "set rejects a non-boolean value"
fi
if run_cli set unknown.key value --no-apply --no-reload >/dev/null 2>&1; then
  fail "set rejects an unknown key" "nonzero exit" "accepted unknown.key"
else
  pass "set rejects an unknown key"
fi
if run_cli set assistant $'bad\nvalue' --no-apply --no-reload >/dev/null 2>&1; then
  fail "set rejects values with newlines" "nonzero exit" "accepted newline value"
else
  pass "set rejects values with newlines"
fi

echo ""
echo "Testing apply failure rollback..."
cat >"$FAKE_BIN/failing-chezmoi" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$FAKE_BIN/failing-chezmoi"
before=$(cat "$TEST_DATA")
if DOTFILES_SETTINGS_CHEZMOI_BIN="$FAKE_BIN/failing-chezmoi" run_cli set assistant opencode --no-reload >/dev/null 2>&1; then
  fail "set fails when chezmoi apply fails" "nonzero exit" "succeeded"
else
  pass "set fails when chezmoi apply fails"
fi
assert_equals "$before" "$(cat "$TEST_DATA")" "data file is rolled back after apply failure"

echo ""
echo "Testing the shared prefs library..."
PREFS_LIB="$DOTFILES_DIR/home/dot_local/lib/dotfiles/prefs.sh"
PREFS_FILE="$TEMP_DIR/preferences.toml"
printf 'assistant = "claude"\n' >"$PREFS_FILE"
value=$(bash -c "source '$PREFS_LIB'; DOTFILES_PREFS_FILE='$PREFS_FILE' dotfiles_pref assistant codex")
assert_equals "claude" "$value" "dotfiles_pref reads the rendered TOML"
value=$(bash -c "source '$PREFS_LIB'; DOTFILES_PREFS_FILE='$TEMP_DIR/absent.toml' dotfiles_pref assistant codex")
assert_equals "codex" "$value" "dotfiles_pref falls back when the file is missing"
value=$(bash -c "source '$PREFS_LIB'; DOTFILES_PREFS_FILE='$PREFS_FILE' DOTFILES_PREF_ASSISTANT=opencode dotfiles_pref assistant codex")
assert_equals "opencode" "$value" "environment override wins over the file"

echo ""
echo "================================"
printf 'Passed: %s, Failed: %s\n' "$PASSED" "$FAILED"
echo "================================"
exit "$FAILED"
