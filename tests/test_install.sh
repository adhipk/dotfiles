#!/usr/bin/env bash

# Test suite for disposable install behavior

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(dirname "$TEST_DIR")"
TEMP_HOME="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install-test.XXXXXX")"
FAKE_BIN="$TEMP_HOME/bin"
ARGS_FILE="$TEMP_HOME/chezmoi-args"
TMUX_ARGS_FILE="$TEMP_HOME/tmux-args"
TMUX_PLUGIN_ARGS_FILE="$TEMP_HOME/tmux-plugin-args"
SERVICE_ARGS_FILE="$TEMP_HOME/service-args"

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

echo "================================"
echo "Installer Tests"
echo "================================"

mkdir -p "$FAKE_BIN"
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
chmod +x "$FAKE_BIN/chezmoi" "$FAKE_BIN/brew" "$FAKE_BIN/tmux" "$FAKE_BIN/yabai" "$FAKE_BIN/skhd"

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
mkdir -p "$TEMP_HOME/.tmux/plugins/tpm/bin"
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
    SERVICE_ARGS_FILE="$SERVICE_ARGS_FILE" \
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
assert_contains "$TMUX_PLUGIN_ARGS_FILE" "^$TEMP_HOME|$TEMP_HOME/.tmux/plugins/$" "bootstrap installs tmux plugins into the destination home"
assert_contains "$SERVICE_ARGS_FILE" "^yabai --start-service$" "bootstrap starts yabai on a clean client"
assert_contains "$SERVICE_ARGS_FILE" "^skhd --start-service$" "bootstrap starts skhd on a clean client"
assert_directory "$TEMP_HOME/projects" "bootstrap creates the projects scratchpad root"
assert_executable "$TEMP_HOME/.config/yabai/projectdeck" "bootstrap builds ProjectDeck for the destination home"
assert_executable "$TEMP_HOME/.config/skhd/whichkey" "bootstrap builds the shortcut guide for the destination home"

echo ""
echo "Testing a clean destination apply..."
COLD_HOME="$TEMP_HOME/cold-home"
mkdir -p "$COLD_HOME"
if chezmoi \
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
assert_executable "$COLD_HOME/bin/tmux-session-template" "clean apply installs the tmux session helper"
assert_executable "$COLD_HOME/bin/tmux-border-accent" "clean apply installs the tmux border helper"
assert_executable "$COLD_HOME/bin/tmux-yazi-pane" "clean apply installs the tmux Yazi helper"
assert_executable "$COLD_HOME/bin/setup-yabai-sa" "clean apply installs the yabai scripting-addition setup helper"
assert_contains "$COLD_HOME/.tmux.conf" "tmux-session-template cycle" "clean apply installs typed tmux bindings"
assert_contains "$COLD_HOME/.skhdrc" "scratchpads open projects" "clean apply installs project scratchpad bindings"
assert_contains "$COLD_HOME/Library/Application Support/com.mitchellh.ghostty/config" "cmd+b=text" "clean apply installs Ghostty tmux bindings"

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

exit $FAILED
