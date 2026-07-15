#!/usr/bin/env bash

# Test suite for disposable install behavior

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(dirname "$TEST_DIR")"
TEMP_HOME="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install-test.XXXXXX")"
TEMP_HOME="$(cd "$TEMP_HOME" && pwd -P)"
FAKE_BIN="$TEMP_HOME/bin"
ARGS_FILE="$TEMP_HOME/chezmoi-args"
TMUX_ARGS_FILE="$TEMP_HOME/tmux-args"
TMUX_PLUGIN_ARGS_FILE="$TEMP_HOME/tmux-plugin-args"
PIN_ARGS_FILE="$TEMP_HOME/dependency-pin-args"
SERVICE_ARGS_FILE="$TEMP_HOME/service-args"
PKILL_ARGS_FILE="$TEMP_HOME/pkill-args"

PASSED=0
FAILED=0

cleanup() {
    rm -rf "$TEMP_HOME"
}
trap cleanup EXIT

assert_contains() {
    local file="$1"
    local pattern="$2"
    local test_name="$3"

    if grep -q "$pattern" "$file"; then
        echo "  ✓ $test_name"
        ((PASSED++))
    else
        echo "  ✗ $test_name"
        echo "    Pattern not found: $pattern"
        ((FAILED++))
    fi
}

assert_not_contains() {
    local file="$1"
    local pattern="$2"
    local test_name="$3"

    if ! grep -q "$pattern" "$file"; then
        echo "  ✓ $test_name"
        ((PASSED++))
    else
        echo "  ✗ $test_name"
        echo "    Pattern should not exist: $pattern"
        ((FAILED++))
    fi
}

assert_executable() {
    local file="$1"
    local test_name="$2"

    if [[ -x "$file" ]]; then
        echo "  ✓ $test_name"
        ((PASSED++))
    else
        echo "  ✗ $test_name"
        echo "    Missing executable: $file"
        ((FAILED++))
    fi
}

assert_missing() {
    local file="$1"
    local test_name="$2"

    if [[ ! -e "$file" ]]; then
        echo "  ✓ $test_name"
        ((PASSED++))
    else
        echo "  ✗ $test_name"
        echo "    Unexpected path: $file"
        ((FAILED++))
    fi
}

assert_path_absent() {
    local path="$1"
    local test_name="$2"

    if [[ ! -e "$path" && ! -L "$path" ]]; then
        echo "  ✓ $test_name"
        ((PASSED++))
    else
        echo "  ✗ $test_name"
        echo "    Unexpected path: $path"
        ((FAILED++))
    fi
}

assert_directory() {
    local directory="$1"
    local test_name="$2"

    if [[ -d "$directory" ]]; then
        echo "  ✓ $test_name"
        ((PASSED++))
    else
        echo "  ✗ $test_name"
        echo "    Missing directory: $directory"
        ((FAILED++))
    fi
}

assert_symlink_target() {
    local link="$1"
    local expected="$2"
    local test_name="$3"
    local actual

    actual=$(readlink "$link" 2>/dev/null || true)
    if [[ -L "$link" && "$actual" == "$expected" ]]; then
        echo "  ✓ $test_name"
        ((PASSED++))
    else
        echo "  ✗ $test_name"
        echo "    Expected symlink: $link -> $expected"
        echo "    Actual: $actual"
        ((FAILED++))
    fi
}

echo "================================"
echo "Installer Tests"
echo "================================"

mkdir -p "$FAKE_BIN"
for declared_dependency in jq yq; do
    dependency_path="$(command -v "$declared_dependency" 2>/dev/null || true)"
    if [[ -z "$dependency_path" ]]; then
        echo "Missing declared test dependency: $declared_dependency" >&2
        exit 1
    fi
    ln -s "$dependency_path" "$FAKE_BIN/$declared_dependency"
done
printf '#!/usr/bin/env bash\nprintf \"%%s\\\\n\" \"$*\" >> \"$CHEZMOI_ARGS_FILE\"\n' > "$FAKE_BIN/chezmoi"
printf '#!/usr/bin/env bash\nexit 0\n' > "$FAKE_BIN/brew"
cat > "$FAKE_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  list-sessions)
    exit 0
    ;;
  source-file)
    printf '%s\n' "$*" >> "$TMUX_ARGS_FILE"
    ;;
esac
EOF
cat > "$FAKE_BIN/yabai" <<'EOF'
#!/usr/bin/env bash
printf '%s %s\n' "${0##*/}" "$*" >> "$SERVICE_ARGS_FILE"
EOF
cat > "$FAKE_BIN/skhd" <<'EOF'
#!/usr/bin/env bash
printf '%s %s\n' "${0##*/}" "$*" >> "$SERVICE_ARGS_FILE"
EOF
cat > "$FAKE_BIN/pkill" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$PKILL_ARGS_FILE"
EOF
cat > "$FAKE_BIN/dotfiles-deps" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$PIN_ARGS_FILE"
EOF
chmod +x "$FAKE_BIN/chezmoi" "$FAKE_BIN/brew" "$FAKE_BIN/tmux" "$FAKE_BIN/yabai" "$FAKE_BIN/skhd" "$FAKE_BIN/pkill" "$FAKE_BIN/dotfiles-deps"

echo ""
echo "Testing install wrapper..."
if HOME="$TEMP_HOME" PATH="$FAKE_BIN:/usr/bin:/bin" CHEZMOI_ARGS_FILE="$ARGS_FILE" TMUX_ARGS_FILE="$TMUX_ARGS_FILE" DOTFILES_DIR="$DOTFILES_DIR" "$DOTFILES_DIR/install.sh" --dry-run >/dev/null; then
    echo "  ✓ install.sh delegates to chezmoi"
    ((PASSED++))
else
    echo "  ✗ install.sh failed"
    ((FAILED++))
fi
assert_contains "$ARGS_FILE" "^-S $DOTFILES_DIR apply --dry-run$" "install.sh passes source directory and arguments"

echo ""
echo "Testing bootstrap wrapper..."
mkdir -p \
    "$TEMP_HOME/.tmux/plugins/tpm/bin" \
    "$TEMP_HOME/.tmux/plugins/tmux-which-key" \
    "$TEMP_HOME/.config/tmux"
chezmoi \
    -S "$DOTFILES_DIR" \
    -D "$TEMP_HOME" \
    cat "$TEMP_HOME/.config/tmux/which-key.yaml" \
    > "$TEMP_HOME/.config/tmux/which-key.yaml"
cat > "$TEMP_HOME/.tmux/plugins/tpm/bin/install_plugins" <<'EOF'
#!/usr/bin/env bash
printf '%s|%s\n' "$HOME" "$TMUX_PLUGIN_MANAGER_PATH" >> "$TMUX_PLUGIN_ARGS_FILE"
EOF
chmod +x "$TEMP_HOME/.tmux/plugins/tpm/bin/install_plugins"
if HOME="$TEMP_HOME" \
    PATH="$FAKE_BIN:/usr/bin:/bin" \
    CHEZMOI_ARGS_FILE="$ARGS_FILE" \
    TMUX_ARGS_FILE="$TMUX_ARGS_FILE" \
    TMUX_PLUGIN_ARGS_FILE="$TMUX_PLUGIN_ARGS_FILE" \
    PIN_ARGS_FILE="$PIN_ARGS_FILE" \
    DOTFILES_DEPS_BIN="$FAKE_BIN/dotfiles-deps" \
    SERVICE_ARGS_FILE="$SERVICE_ARGS_FILE" \
    PKILL_ARGS_FILE="$PKILL_ARGS_FILE" \
    DOTFILES_DIR="$DOTFILES_DIR" \
    "$DOTFILES_DIR/bootstrap.sh" >/dev/null; then
    echo "  ✓ bootstrap.sh delegates to install.sh"
    ((PASSED++))
else
    echo "  ✗ bootstrap.sh failed"
    ((FAILED++))
fi
assert_contains "$ARGS_FILE" "^-S $DOTFILES_DIR apply$" "bootstrap applies the chezmoi source state"
assert_contains "$TMUX_ARGS_FILE" "^source-file $TEMP_HOME/.tmux.conf$" "bootstrap reloads a running tmux server"
assert_contains "$PKILL_ARGS_FILE" "^-USR2 -f /Ghostty" "bootstrap reloads every running Ghostty process with SIGUSR2"
assert_contains "$TMUX_PLUGIN_ARGS_FILE" "^$TEMP_HOME|$TEMP_HOME/.tmux/plugins/$" "bootstrap installs tmux plugins into the destination home"
assert_contains "$PIN_ARGS_FILE" '^pins apply --manager tpm$' "bootstrap enforces immutable TPM pins after plugin installation"
assert_symlink_target \
    "$TEMP_HOME/.tmux/plugins/tmux-which-key/config.yaml" \
    "$TEMP_HOME/.config/tmux/which-key.yaml" \
    "bootstrap links the repo-owned tmux command center"
assert_contains "$SERVICE_ARGS_FILE" "^yabai --start-service$" "bootstrap starts yabai on a clean client"
assert_contains "$SERVICE_ARGS_FILE" "^skhd --start-service$" "bootstrap starts skhd on a clean client"
assert_directory "$TEMP_HOME/projects" "bootstrap creates the projects scratchpad root"
assert_missing "$TEMP_HOME/.todo" "bootstrap does not create a global task directory"
assert_missing "$TEMP_HOME/.config/yabai/projectdeck" "bootstrap leaves dormant ProjectDeck unbuilt"
assert_executable "$TEMP_HOME/.config/skhd/whichkey" "bootstrap builds the shortcut guide for the destination home"

echo ""
echo "Testing a clean destination apply..."
COLD_HOME="$TEMP_HOME/cold-home"
mkdir -p "$COLD_HOME"
if HOME="$COLD_HOME" chezmoi \
    -S "$DOTFILES_DIR" \
    -D "$COLD_HOME" \
    --persistent-state "$COLD_HOME/state.db" \
    apply --exclude=scripts,externals --force >/dev/null; then
    echo "  ✓ chezmoi applies the source state to an empty home"
    ((PASSED++))
else
    echo "  ✗ chezmoi could not apply the source state to an empty home"
    ((FAILED++))
fi
assert_contains "$COLD_HOME/.agents/AGENTS.md" "Canonical Task Tracking" "clean apply installs shared agent guidance"
assert_contains "$COLD_HOME/.agents/AGENTS.md" "Time-boxed Delivery" "clean apply installs global checkpoint behavior"
assert_contains "$COLD_HOME/.agents/AGENTS.md" "Checkpoint expiry is never a termination condition" "clean apply installs recurring checkpoint behavior"
assert_contains "$COLD_HOME/.agents/AGENTS.md" "ordinary untimed agent behavior" "clean apply makes the optional timer fail open"
assert_symlink_target "$COLD_HOME/.codex/AGENTS.md" "$COLD_HOME/.agents/AGENTS.md" "clean apply links Codex to shared agent guidance"
assert_symlink_target "$COLD_HOME/.claude/CLAUDE.md" "$COLD_HOME/.agents/AGENTS.md" "clean apply links Claude to shared agent guidance"
assert_symlink_target "$COLD_HOME/.config/opencode/AGENTS.md" "$COLD_HOME/.agents/AGENTS.md" "clean apply links OpenCode to shared agent guidance"
assert_contains "$COLD_HOME/.config/opencode/opencode.json" "active project's todo\\.txt" "clean apply configures the OpenCode personal agent for project-local todo.txt"
assert_not_contains "$COLD_HOME/.config/opencode/opencode.json" 'Todoist' "clean apply removes OpenCode's Todoist task guidance"
assert_symlink_target "$COLD_HOME/bin/todo" "$COLD_HOME/projects/tuxedo-project-todo/bin/todo" "clean apply links the canonical todo wrapper to its pinned project"
assert_symlink_target "$COLD_HOME/bin/chezmoi-todo" "$COLD_HOME/projects/tuxedo-project-todo/bin/todo" "clean apply links chezmoi plugin dispatch to the pinned todo project"
assert_symlink_target "$COLD_HOME/bin/kit" "$COLD_HOME/projects/kittentts-cli/kit" "clean apply links kit to its pinned project"
assert_symlink_target "$COLD_HOME/bin/kit-watch" "$COLD_HOME/projects/kittentts-cli/kit-watch" "clean apply links kit-watch to its pinned project"
assert_symlink_target "$COLD_HOME/bin/gh-create-repo" "$COLD_HOME/projects/gh-create-repo/bin/gh-create-repo" "clean apply links gh-create-repo to its pinned project"
assert_symlink_target "$COLD_HOME/bin/default-apps" "$COLD_HOME/projects/macos-default-apps/bin/default-apps" "clean apply links default-apps to its pinned project"
assert_symlink_target "$COLD_HOME/bin/unescape-buffer" "$COLD_HOME/projects/unescape-cli/bin/unescape-buffer" "clean apply links unescape-buffer to its pinned project"
assert_symlink_target "$COLD_HOME/bin/unescape-string" "$COLD_HOME/projects/unescape-cli/bin/unescape-string" "clean apply links unescape-string to its pinned project"
assert_executable "$COLD_HOME/bin/agent-timer" "clean apply installs the global agent timer"
assert_executable "$COLD_HOME/bin/dotfiles-module" "clean apply installs the module lifecycle controller"
assert_executable "$COLD_HOME/bin/dotfiles-deps" "clean apply installs the dependency inventory command"
assert_executable "$COLD_HOME/bin/dotfiles-control-center" "clean apply installs the native control-center launcher"
assert_executable "$COLD_HOME/bin/shortcut-catalog" "clean apply installs the generated shortcut catalog command"
assert_executable "$COLD_HOME/.config/skhd/show_keys.sh" "clean apply installs the module-owned shortcut launcher"
assert_contains "$COLD_HOME/.config/agent-timer/config.toml" '^auto_start = false$' "clean apply disables automatic agent timing by default"
assert_contains "$COLD_HOME/.config/agent-timer/config.toml" '^default_seconds = 600$' "clean apply installs the 600-second default budget"
assert_contains "$COLD_HOME/.config/agent-timer/config.toml" '^expiry_sound = "Ping"$' "clean apply installs the expiry beep"
assert_contains "$COLD_HOME/.config/agent-timer/config.toml" '^preferred_agents = \["codex", "claude", "opencode"\]$' "clean apply prefers Codex as the default terminal agent"
assert_contains "$COLD_HOME/.config/agent-timer/config.toml" '^warning_seconds = 60$' "clean apply installs the timer warning lead time"
assert_contains "$COLD_HOME/.config/agent-timer/config.toml" '^report_timeout_seconds = 120$' "clean apply installs the bounded detached-report timeout"
assert_contains "$COLD_HOME/.config/agent-timer/config.toml" '^retention_seconds = 604800$' "clean apply installs timer record retention"
assert_contains "$COLD_HOME/.codex/hooks.json" 'UserPromptSubmit' "clean apply installs the Codex timer hook"
assert_contains "$COLD_HOME/.codex/hooks.json" 'PreToolUse' "clean apply installs checkpoint re-arming at tool boundaries"
assert_contains "$COLD_HOME/.codex/hooks.json" 'cat >\/dev\/null' "clean apply makes cached hooks tolerate a missing timer command"
assert_not_contains "$COLD_HOME/.codex/hooks.json" 'Arming recurring task checkpoint' "clean apply keeps disabled automatic timing silent"
assert_executable "$COLD_HOME/bin/tmux-session-template" "clean apply installs the tmux session helper"
assert_executable "$COLD_HOME/bin/tmux-session-picker" "clean apply installs the sesh tmux-session picker"
assert_executable "$COLD_HOME/bin/tmux-sessionizer" "clean apply installs the general sesh sessionizer"
assert_executable "$COLD_HOME/bin/tmux-sessionizer-zoxide" "clean apply installs the project-aware sesh sessionizer"
assert_executable "$COLD_HOME/bin/tmux-workspace" "clean apply installs the declarative tmux workspace helper"
assert_executable "$COLD_HOME/bin/tmux-border-accent" "clean apply installs the tmux border helper"
assert_executable "$COLD_HOME/bin/tmux-yazi-pane" "clean apply installs the tmux Yazi helper"
assert_executable "$COLD_HOME/bin/setup-yabai-sa" "clean apply installs the yabai scripting-addition setup helper"
assert_contains "$COLD_HOME/.tmux.conf" "tmux-session-template cycle" "clean apply installs typed tmux bindings"
assert_contains "$COLD_HOME/.tmux.conf" "C-3.*tmux-session-template cycle.*tuxedo" "clean apply installs Tuxedo type cycling"
assert_contains "$COLD_HOME/.tmux.conf" "C-S-3.*tmux-session-template new.*tuxedo" "clean apply installs Tuxedo type creation"
assert_contains "$COLD_HOME/.tmux.conf" '^set-option -gu allow-passthrough$' "clean apply clears legacy graphics passthrough on warm reload"
assert_not_contains "$COLD_HOME/.tmux.conf" 'allow-passthrough on' "clean apply never enables graphics passthrough"
assert_contains "$COLD_HOME/bin/tmux-session-template" "ensure_standard_tmux_window.*tuxedo 3 todo" "clean apply installs the canonical Tuxedo window"
assert_not_contains "$COLD_HOME/bin/tmux-session-template" "[Aa]writ" "clean apply omits the Awrit window type"
assert_missing "$COLD_HOME/bin/awrit" "clean apply does not install an Awrit launcher"
assert_contains "$COLD_HOME/bin/tmux-session-template" "duplicate_window_type" "clean apply installs typed tmux duplication"
assert_contains "$COLD_HOME/.tmux.conf" 'S-F4.*tmux-session-template duplicate' "clean apply installs the Right Command duplicate bridge"
assert_contains "$COLD_HOME/.tmux.conf" '^set-option -g detach-on-destroy off$' "clean apply keeps tmux attached across session destruction"
assert_contains "$COLD_HOME/.tmux.conf" 'L switch-client -l' "clean apply keeps last-session selection local to each tmux client"
assert_contains "$COLD_HOME/.tmux.conf" 'Rename #S · #{b:pane_current_path}' "clean apply installs the contextual session rename prompt"
assert_contains "$COLD_HOME/.tmux.conf" 'command-prompt -F -l' "clean apply installs literal contextual rename input"
assert_contains "$COLD_HOME/.tmux.conf" 'rename-session -t "#{session_id}" -- "%%%"' "clean apply installs punctuation-safe session rename forwarding"
assert_contains "$COLD_HOME/.tmux.conf" "tmux-plugins/tmux-resurrect" "clean apply installs tmux persistence config"
assert_contains "$COLD_HOME/.tmux.conf" "@resurrect-processes 'codex tuxedo yazi'" "clean apply restores Tuxedo sessions"
assert_contains "$COLD_HOME/.tmux.conf" 'agent-timer manage' "clean apply exposes timer/session management in tmux"
assert_contains "$COLD_HOME/.config/tmux/which-key.yaml" 'Agent timers and durable sessions' "clean apply exposes sesh-backed timer inventory in the command center"
assert_contains "$COLD_HOME/.config/tmux/layouts/project.tmux.tsx" "<Session root=\"\$PROJECT_ROOT\">" "clean apply installs the React-like project layout"
assert_contains "$COLD_HOME/.config/tmux/which-key.yaml" "tmux-workspace pick" "clean apply installs the tmux command-center layout action"
assert_contains "$COLD_HOME/.config/tmux/which-key.yaml" "tmux-session-template duplicate" "clean apply installs command-center window duplication"
assert_contains "$COLD_HOME/.config/tmux/which-key.yaml" "cycle.*tuxedo" "clean apply installs command-center Tuxedo cycling"
assert_contains "$COLD_HOME/.config/tmux/which-key.yaml" "new.*tuxedo" "clean apply installs command-center Tuxedo creation"
assert_not_contains "$COLD_HOME/.config/tmux/which-key.yaml" "[Aa]writ" "clean apply omits command-center Awrit actions"
assert_contains "$COLD_HOME/.config/tmux/which-key.yaml" "tmux-sessionizer-zoxide" "clean apply points the command center at the built-in sesh picker"
assert_contains "$COLD_HOME/.config/sesh/sesh.toml" '^\[tui\]$' "clean apply installs the managed sesh picker config"
assert_contains "$COLD_HOME/.config/sesh/sesh.toml" '^strict_mode = true$' "clean apply installs strict sesh config validation"
assert_not_contains "$COLD_HOME/.config/sesh/sesh.toml" '^\[default_session\]$' "clean apply does not install a default sesh layout"
assert_not_contains "$COLD_HOME/.config/sesh/sesh.toml" '^\[\[window\]\]$' "clean apply does not install mutable sesh window templates"
assert_not_contains "$COLD_HOME/.config/sesh/sesh.toml" '^\[\[session\]\]$' "clean apply does not install sessions that can mutate the caller"
assert_contains "$COLD_HOME/.skhdrc" "scratchpads open projects" "clean apply installs project scratchpad bindings"
assert_contains "$COLD_HOME/.skhdrc" 'rcmd - d \[' "clean apply installs the Ghostty-only Right Command layer"
assert_contains "$COLD_HOME/.skhdrc" '^[[:space:]]*\* ~$' "clean apply preserves Right Command passthrough outside Ghostty"
assert_not_contains "$COLD_HOME/.skhdrc" '^ctrl + alt + cmd' "clean apply reserves the global Hyper layer"
assert_not_contains "$COLD_HOME/.skhdrc" '\.config/yabai/projects ' "clean apply leaves project contexts dormant"
assert_contains "$COLD_HOME/Library/Application Support/com.mitchellh.ghostty/config" "cmd+backquote=csi:48;5u" "clean apply installs Cmd+Backtick terminal cycling"
assert_contains "$COLD_HOME/Library/Application Support/com.mitchellh.ghostty/config" "cmd+digit_1=csi:49;5u" "clean apply installs Cmd+1 Codex cycling"
assert_contains "$COLD_HOME/Library/Application Support/com.mitchellh.ghostty/config" "cmd+digit_2=csi:50;5u" "clean apply installs Cmd+2 Neovim cycling"
assert_contains "$COLD_HOME/Library/Application Support/com.mitchellh.ghostty/config" "cmd+digit_3=csi:51;5u" "clean apply installs Cmd+3 Tuxedo cycling"
assert_contains "$COLD_HOME/Library/Application Support/com.mitchellh.ghostty/config" "ctrl+shift+digit_3=csi:51;6u" "clean apply installs Ctrl+Shift+3 Tuxedo creation input"
assert_contains "$COLD_HOME/Library/Application Support/com.mitchellh.ghostty/config" "cmd+b=text:\\\\x01\\\\x62" "clean apply installs the Cmd+B Yazi side pane"
assert_contains "$COLD_HOME/Library/Application Support/com.mitchellh.ghostty/config" "cmd+shift+b=text:\\\\x01\\\\x42" "clean apply installs the Cmd+Shift+B Yazi window"
assert_not_contains "$COLD_HOME/Library/Application Support/com.mitchellh.ghostty/config" '^keybind = ctrl+alt+cmd' "clean apply reserves Hyper in Ghostty"
assert_not_contains "$COLD_HOME/.config/karabiner/karabiner.json" 'nvim_caps_lock_control' "clean apply installs no Neovim-specific Karabiner state"
assert_not_contains "$COLD_HOME/.config/nvim/init.lua" 'karabiner_cli' "clean apply leaves Neovim independent of Karabiner"

echo ""
echo "Testing the legacy Awrit launcher migration..."
WARM_HOME="$TEMP_HOME/warm-awrit-home"
WARM_BASELINE_SOURCE="$TEMP_HOME/warm-awrit-baseline"
WARM_STATE="$WARM_HOME/state.db"
mkdir -p "$WARM_HOME/awrit" "$WARM_BASELINE_SOURCE/home/bin"
printf 'home\n' > "$WARM_BASELINE_SOURCE/.chezmoiroot"
printf '{{ .chezmoi.homeDir }}/awrit/awrit\n' > "$WARM_BASELINE_SOURCE/home/bin/symlink_awrit.tmpl"
printf '#!/usr/bin/env bash\nexit 0\n' > "$WARM_HOME/awrit/awrit"
printf 'preserved\n' > "$WARM_HOME/awrit/preserved"
chmod +x "$WARM_HOME/awrit/awrit"

if HOME="$WARM_HOME" chezmoi \
    -S "$WARM_BASELINE_SOURCE" \
    -D "$WARM_HOME" \
    --persistent-state "$WARM_STATE" \
    apply --exclude=scripts,externals --force >/dev/null; then
    echo "  ✓ legacy source installs the former managed Awrit launcher"
    ((PASSED++))
else
    echo "  ✗ legacy source could not install the former managed Awrit launcher"
    ((FAILED++))
fi
assert_symlink_target "$WARM_HOME/bin/awrit" "$WARM_HOME/awrit/awrit" "warm baseline reproduces the former launcher"

if HOME="$WARM_HOME" chezmoi \
    -S "$DOTFILES_DIR" \
    -D "$WARM_HOME" \
    --persistent-state "$WARM_STATE" \
    apply --source-path home/.chezmoiscripts/run_onchange_before_remove-legacy-awrit-link.sh.tmpl --force >/dev/null; then
    echo "  ✓ current source migrates the former managed Awrit launcher"
    ((PASSED++))
else
    echo "  ✗ current source could not migrate the former managed Awrit launcher"
    ((FAILED++))
fi
assert_path_absent "$WARM_HOME/bin/awrit" "warm upgrade removes the exact former managed launcher"
assert_executable "$WARM_HOME/awrit/awrit" "warm upgrade preserves the Awrit checkout command"
assert_contains "$WARM_HOME/awrit/preserved" '^preserved$' "warm upgrade preserves the Awrit checkout state"

mkdir -p "$WARM_HOME/bin"
ln -s "$WARM_HOME/awrit/awrit" "$WARM_HOME/bin/awrit"
HOME="$WARM_HOME" chezmoi \
    -S "$DOTFILES_DIR" \
    -D "$WARM_HOME" \
    --persistent-state "$WARM_STATE" \
    apply --source-path home/.chezmoiscripts/run_onchange_before_remove-legacy-awrit-link.sh.tmpl --force >/dev/null
assert_symlink_target "$WARM_HOME/bin/awrit" "$WARM_HOME/awrit/awrit" "unchanged migration does not remove a later user-created launcher"

WARM_GUARD_HOME="$TEMP_HOME/warm-awrit-guard-home"
mkdir -p "$WARM_GUARD_HOME/bin" "$WARM_GUARD_HOME/custom"
printf '#!/usr/bin/env bash\nexit 0\n' > "$WARM_GUARD_HOME/custom/awrit"
chmod +x "$WARM_GUARD_HOME/custom/awrit"
ln -s "$WARM_GUARD_HOME/custom/awrit" "$WARM_GUARD_HOME/bin/awrit"
if HOME="$WARM_GUARD_HOME" chezmoi \
    -S "$DOTFILES_DIR" \
    -D "$WARM_GUARD_HOME" \
    --persistent-state "$WARM_GUARD_HOME/state.db" \
    apply --source-path home/.chezmoiscripts/run_onchange_before_remove-legacy-awrit-link.sh.tmpl --force >/dev/null 2>&1; then
    echo "  ✓ current source accepts a user-owned Awrit launcher"
    ((PASSED++))
else
    echo "  ✗ current source rejected a user-owned Awrit launcher"
    ((FAILED++))
fi
assert_symlink_target "$WARM_GUARD_HOME/bin/awrit" "$WARM_GUARD_HOME/custom/awrit" "warm upgrade preserves a non-managed Awrit launcher"

echo ""
echo "Testing agent-timer disable lifecycle..."
TIMER_DISABLE_HOME="$TEMP_HOME/timer-disable-home"
TIMER_DISABLE_SCRIPT="$TEMP_HOME/timer-disable.sh"
mkdir -p "$TIMER_DISABLE_HOME/bin" "$TIMER_DISABLE_HOME/.local/state/agent-timer"
cat > "$TIMER_DISABLE_HOME/bin/agent-timer" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$HOME/shutdown-args"
EOF
chmod +x "$TIMER_DISABLE_HOME/bin/agent-timer"
printf '%s\n' preserved > "$TIMER_DISABLE_HOME/.local/state/agent-timer/sentinel"
chezmoi \
    -S "$DOTFILES_DIR" \
    --override-data '{"modules":{"agentTimer":{"enabled":false}}}' \
    execute-template \
    < "$DOTFILES_DIR/home/.chezmoiscripts/run_onchange_before_agent-timer-disable.sh.tmpl" \
    > "$TIMER_DISABLE_SCRIPT"
if HOME="$TIMER_DISABLE_HOME" /bin/sh "$TIMER_DISABLE_SCRIPT"; then
    echo "  ✓ disabled module shuts down the installed timer before removal"
    ((PASSED++))
else
    echo "  ✗ disabled module lifecycle failed"
    ((FAILED++))
fi
assert_contains "$TIMER_DISABLE_HOME/shutdown-args" '^shutdown --reason module-disabled$' "disable lifecycle records the module-disabled reason"
assert_contains "$TIMER_DISABLE_HOME/.local/state/agent-timer/sentinel" '^preserved$' "disable lifecycle preserves timer state"

echo ""
echo "Testing agent-timer automatic-start transition..."
TIMER_AUTOSTART_HOME="$TEMP_HOME/timer-autostart-home"
TIMER_AUTOSTART_BEFORE="$TEMP_HOME/timer-autostart-before.sh"
TIMER_AUTOSTART_AFTER="$TEMP_HOME/timer-autostart-after.sh"
TIMER_AUTOSTART_BIN="$TIMER_AUTOSTART_HOME/fake-bin"
mkdir -p "$TIMER_AUTOSTART_HOME/bin" "$TIMER_AUTOSTART_HOME/.local/state/agent-timer" "$TIMER_AUTOSTART_BIN"
cat > "$TIMER_AUTOSTART_HOME/bin/agent-timer" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$HOME/timer-lifecycle-args"
case "${1:-}" in
  help)
    printf '%s\n' 'agent-timer shutdown [--reason TEXT] [--automatic-only]'
    ;;
  shutdown)
    printf 'disabled_at=1\nreason=%s\n' "${3:-unknown}" > "$HOME/.local/state/agent-timer/module-disabled"
    ;;
  enable)
    rm -f "$HOME/.local/state/agent-timer/module-disabled"
    ;;
esac
EOF
cat > "$TIMER_AUTOSTART_BIN/crontab" <<'EOF'
#!/bin/sh
case "${1:-}" in
  -l) [ ! -e "$HOME/fake-crontab" ] || cat "$HOME/fake-crontab" ;;
  *) cp "$1" "$HOME/fake-crontab" ;;
esac
EOF
chmod +x "$TIMER_AUTOSTART_HOME/bin/agent-timer" "$TIMER_AUTOSTART_BIN/crontab"
chezmoi -S "$DOTFILES_DIR" execute-template \
    < "$DOTFILES_DIR/home/.chezmoiscripts/run_onchange_before_agent-timer-disable.sh.tmpl" \
    > "$TIMER_AUTOSTART_BEFORE"
chezmoi -S "$DOTFILES_DIR" execute-template \
    < "$DOTFILES_DIR/home/.chezmoiscripts/run_onchange_after_agent-timer-cron.sh.tmpl" \
    > "$TIMER_AUTOSTART_AFTER"
if HOME="$TIMER_AUTOSTART_HOME" /bin/bash "$TIMER_AUTOSTART_BEFORE" && \
   HOME="$TIMER_AUTOSTART_HOME" PATH="$TIMER_AUTOSTART_BIN:/usr/bin:/bin" /bin/bash "$TIMER_AUTOSTART_AFTER"; then
    echo "  ✓ enabled autoStart=false apply retires legacy timers and restores manual use"
    ((PASSED++))
else
    echo "  ✗ enabled autoStart=false lifecycle failed"
    ((FAILED++))
fi
assert_contains "$TIMER_AUTOSTART_HOME/timer-lifecycle-args" '^shutdown --reason auto-start-disabled --automatic-only$' "autoStart=false retires legacy automatic workers only"
assert_contains "$TIMER_AUTOSTART_HOME/timer-lifecycle-args" '^enable$' "post-apply lifecycle restores manual timer commands"
assert_executable "$TIMER_AUTOSTART_HOME/bin/agent-timer" "autoStart=false preserves the installed timer command"
assert_missing "$TIMER_AUTOSTART_HOME/.local/state/agent-timer/module-disabled" "migration-created lifecycle latch is cleared after apply"
if ! grep -q 'agent-timer backstop' "$TIMER_AUTOSTART_HOME/fake-crontab"; then
    echo "  ✓ autoStart=false removes the managed cron backstop"
    ((PASSED++))
else
    echo "  ✗ autoStart=false left the managed cron backstop installed"
    ((FAILED++))
fi

printf 'disabled_at=2\nreason=manual\n' > "$TIMER_AUTOSTART_HOME/.local/state/agent-timer/module-disabled"
: > "$TIMER_AUTOSTART_HOME/timer-lifecycle-args"
HOME="$TIMER_AUTOSTART_HOME" /bin/bash "$TIMER_AUTOSTART_BEFORE"
HOME="$TIMER_AUTOSTART_HOME" PATH="$TIMER_AUTOSTART_BIN:/usr/bin:/bin" /bin/bash "$TIMER_AUTOSTART_AFTER"
assert_contains "$TIMER_AUTOSTART_HOME/.local/state/agent-timer/module-disabled" '^reason=manual$' "enabled apply preserves a preexisting manual shutdown latch"
if [[ ! -s "$TIMER_AUTOSTART_HOME/timer-lifecycle-args" ]]; then
    echo "  ✓ manual shutdown latch prevents lifecycle enablement"
    ((PASSED++))
else
    echo "  ✗ manual shutdown latch unexpectedly invoked timer lifecycle"
    ((FAILED++))
fi

echo ""
echo "Testing strict legacy agent-timer warm upgrade..."
TIMER_LEGACY_HOME="$TEMP_HOME/timer-legacy-home"
TIMER_LEGACY_BEFORE="$TEMP_HOME/timer-legacy-before.sh"
TIMER_LEGACY_AFTER="$TEMP_HOME/timer-legacy-after.sh"
TIMER_LEGACY_BIN="$TIMER_LEGACY_HOME/fake-bin"
TIMER_LEGACY_STATE="$TIMER_LEGACY_HOME/.local/state/agent-timer"
TIMER_LEGACY_LIB="$TIMER_LEGACY_HOME/.local/lib/dotfiles"
mkdir -p "$TIMER_LEGACY_HOME/bin" "$TIMER_LEGACY_BIN" "$TIMER_LEGACY_STATE" "$TIMER_LEGACY_LIB"
cp "$DOTFILES_DIR/home/dot_local/lib/dotfiles/core.sh" "$TIMER_LEGACY_LIB/core.sh"
cp "$DOTFILES_DIR/home/dot_local/lib/dotfiles/locks.sh" "$TIMER_LEGACY_LIB/locks.sh"
cp "$DOTFILES_DIR/home/dot_local/lib/dotfiles/state.sh" "$TIMER_LEGACY_LIB/state.sh"
cat > "$TIMER_LEGACY_HOME/bin/agent-timer" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$HOME/legacy-timer-args"
case "${1:-}" in
  help)
    printf '%s\n' 'agent-timer shutdown [--reason TEXT]'
    ;;
  shutdown)
    case " $* " in
      *' --automatic-only '*)
        printf '%s\n' 'unsupported automatic-only flag' >&2
        exit 64
        ;;
    esac
    printf '%s\n' 'unsafe whole-runtime shutdown was invoked' >&2
    exit 65
    ;;
  cancel)
    [ "${2:-}" = "--id" ] && [ -n "${3:-}" ] || exit 2
    state_file="$HOME/.local/state/agent-timer/$3.json"
    [ -f "$state_file" ] || exit 1
    temp_file="$state_file.tmp.$$"
    jq '.status="canceled" | .canceledAt=1' "$state_file" >"$temp_file" || exit 1
    mv "$temp_file" "$state_file"
    ;;
  enable)
    rm -f "$HOME/.local/state/agent-timer/module-disabled"
    ;;
esac
EOF
cat > "$TIMER_LEGACY_BIN/crontab" <<'EOF'
#!/bin/sh
case "${1:-}" in
  -l) [ ! -e "$HOME/fake-crontab" ] || cat "$HOME/fake-crontab" ;;
  *) cp "$1" "$HOME/fake-crontab" ;;
esac
EOF
chmod +x "$TIMER_LEGACY_HOME/bin/agent-timer" "$TIMER_LEGACY_BIN/crontab"
cat > "$TIMER_LEGACY_STATE/automatic.json" <<'EOF'
{"id":"automatic","status":"running","origin":"automatic"}
EOF
cat > "$TIMER_LEGACY_STATE/codex-legacy.json" <<'EOF'
{"id":"codex-legacy","status":"warning"}
EOF
cat > "$TIMER_LEGACY_STATE/manual-survivor.json" <<'EOF'
{"id":"manual-survivor","status":"running","origin":"manual"}
EOF
cat > "$TIMER_LEGACY_STATE/completed-automatic.json" <<'EOF'
{"id":"completed-automatic","status":"completed","origin":"automatic"}
EOF
chezmoi -S "$DOTFILES_DIR" execute-template \
    < "$DOTFILES_DIR/home/.chezmoiscripts/run_onchange_before_agent-timer-disable.sh.tmpl" \
    > "$TIMER_LEGACY_BEFORE"
chezmoi -S "$DOTFILES_DIR" execute-template \
    < "$DOTFILES_DIR/home/.chezmoiscripts/run_onchange_after_agent-timer-cron.sh.tmpl" \
    > "$TIMER_LEGACY_AFTER"
if HOME="$TIMER_LEGACY_HOME" PATH="$TIMER_LEGACY_BIN:$PATH" /bin/bash "$TIMER_LEGACY_BEFORE"; then
    echo "  ✓ strict old CLI is migrated selectively without a whole-runtime shutdown"
    ((PASSED++))
else
    echo "  ✗ strict old CLI warm-upgrade lifecycle failed"
    ((FAILED++))
fi
assert_not_contains "$TIMER_LEGACY_HOME/legacy-timer-args" '^shutdown' "legacy upgrade never invokes the unsupported shutdown surface"
assert_contains "$TIMER_LEGACY_HOME/legacy-timer-args" '^cancel --id automatic$' "legacy upgrade cancels origin=automatic state"
assert_contains "$TIMER_LEGACY_HOME/legacy-timer-args" '^cancel --id codex-legacy$' "legacy upgrade recognizes missing-origin Codex hook state"
assert_not_contains "$TIMER_LEGACY_HOME/legacy-timer-args" '^cancel --id manual-survivor$' "legacy upgrade preserves explicit manual state"
assert_not_contains "$TIMER_LEGACY_HOME/legacy-timer-args" '^cancel --id completed-automatic$' "legacy upgrade leaves terminal automatic state unchanged"
assert_contains "$TIMER_LEGACY_STATE/automatic.json" '"status": "canceled"' "legacy automatic state is canceled"
assert_contains "$TIMER_LEGACY_STATE/codex-legacy.json" '"status": "canceled"' "legacy missing-origin Codex state is canceled"
assert_contains "$TIMER_LEGACY_STATE/manual-survivor.json" '"status":"running"' "legacy manual state remains active"
assert_contains "$TIMER_LEGACY_STATE/module-disabled" '^reason=auto-start-disabled$' "legacy migration latches automatic startup before selective cancellation"
assert_contains "$TIMER_LEGACY_STATE/restore-after-auto-start-disable" '^restore=legacy-selective$' "legacy migration leaves an explicit post-apply restore marker"
if HOME="$TIMER_LEGACY_HOME" PATH="$TIMER_LEGACY_BIN:$PATH" /bin/bash "$TIMER_LEGACY_AFTER"; then
    echo "  ✓ strict old CLI migration restores manual timer use after apply"
    ((PASSED++))
else
    echo "  ✗ strict old CLI migration failed to restore manual timer use"
    ((FAILED++))
fi
assert_missing "$TIMER_LEGACY_STATE/module-disabled" "post-apply restore clears only the migration latch"
assert_missing "$TIMER_LEGACY_STATE/restore-after-auto-start-disable" "post-apply restore consumes the migration marker"

if jq -e '
    .profiles[] | select(.selected == true)
    | [.complex_modifications.rules[].manipulators[] | select(.from.key_code == "caps_lock")] as $caps
    | ($caps | length == 1)
      and ($caps[0].to[0].key_code == "left_control")
      and ($caps[0].to[0].lazy == true)
      and ($caps[0].to[0].modifiers == ["left_option", "left_command"])
      and ($caps[0].to_if_alone[0].key_code == "escape")
      and ($caps[0] | has("conditions") | not)
' "$COLD_HOME/.config/karabiner/karabiner.json" >/dev/null; then
    echo "  ✓ clean apply installs unconditional Caps Lock Hyper hold and Escape tap"
    ((PASSED++))
else
    echo "  ✗ clean apply did not reconstruct the unconditional Caps Lock mapping"
    ((FAILED++))
fi

if HOME="$COLD_HOME" "$COLD_HOME/bin/tmux-workspace" list | grep -qx project; then
    echo "  ✓ cold-home workspace CLI discovers its managed layout"
    ((PASSED++))
else
    echo "  ✗ cold-home workspace CLI could not discover its managed layout"
    ((FAILED++))
fi

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

exit $FAILED
