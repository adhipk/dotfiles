#!/usr/bin/env bash

# Test suite for disposable install behavior

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(dirname "$TEST_DIR")"
TEMP_HOME="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install-test.XXXXXX")"
CUSTOM_DOTFILES="$TEMP_HOME/custom-dotfiles"
BOOTSTRAP_HOME="$TEMP_HOME/bootstrap-home"
BOOTSTRAP_DOTFILES="$BOOTSTRAP_HOME/custom-dotfiles"

PASSED=0
FAILED=0

cleanup() {
    rm -rf "$TEMP_HOME"
}
trap cleanup EXIT

assert_symlink_target() {
    local link="$1"
    local expected_target="$2"
    local test_name="$3"

    if [ -L "$link" ] && [ "$(readlink "$link")" = "$expected_target" ]; then
        echo "  ✓ $test_name"
        ((PASSED++))
    else
        echo "  ✗ $test_name"
        echo "    Expected symlink: $link -> $expected_target"
        ((FAILED++))
    fi
}

assert_not_exists() {
    local path="$1"
    local test_name="$2"

    if [ ! -e "$path" ] && [ ! -L "$path" ]; then
        echo "  ✓ $test_name"
        ((PASSED++))
    else
        echo "  ✗ $test_name"
        echo "    Path still exists: $path"
        ((FAILED++))
    fi
}

echo "================================"
echo "Installer Tests"
echo "================================"

ln -s "$DOTFILES_DIR" "$CUSTOM_DOTFILES"
mkdir -p "$TEMP_HOME/bin"
ln -s "$CUSTOM_DOTFILES/scripts/removed-helper.sh" "$TEMP_HOME/bin/removed-helper"

echo ""
echo "Testing custom DOTFILES_DIR install..."
if HOME="$TEMP_HOME" DOTFILES_DIR="$CUSTOM_DOTFILES" "$DOTFILES_DIR/install.sh" >/dev/null; then
    echo "  ✓ install.sh accepts a custom DOTFILES_DIR"
    ((PASSED++))
else
    echo "  ✗ install.sh failed with a custom DOTFILES_DIR"
    ((FAILED++))
fi

assert_symlink_target "$TEMP_HOME/.zshrc" "$CUSTOM_DOTFILES/zshrc" ".zshrc uses custom DOTFILES_DIR"
assert_symlink_target "$TEMP_HOME/.tmux.conf" "$CUSTOM_DOTFILES/tmux.conf" ".tmux.conf uses custom DOTFILES_DIR"
assert_symlink_target "$TEMP_HOME/bin/watch-sync" "$CUSTOM_DOTFILES/scripts/watch-sync.sh" "Helper command is linked"
assert_not_exists "$TEMP_HOME/bin/removed-helper" "Obsolete helper command symlink is removed"

echo ""
echo "Testing bootstrap custom DOTFILES_DIR propagation..."
mkdir -p "$BOOTSTRAP_HOME/bin"
ln -s "$DOTFILES_DIR" "$BOOTSTRAP_DOTFILES"
printf '#!/usr/bin/env bash\nexit 0\n' > "$BOOTSTRAP_HOME/bin/brew"
chmod +x "$BOOTSTRAP_HOME/bin/brew"

if HOME="$BOOTSTRAP_HOME" PATH="$BOOTSTRAP_HOME/bin:/usr/bin:/bin" DOTFILES_DIR="$BOOTSTRAP_DOTFILES" "$DOTFILES_DIR/bootstrap.sh" >/dev/null; then
    echo "  ✓ bootstrap.sh passes custom DOTFILES_DIR to install.sh"
    ((PASSED++))
else
    echo "  ✗ bootstrap.sh failed with a custom DOTFILES_DIR"
    ((FAILED++))
fi

assert_symlink_target "$BOOTSTRAP_HOME/.zshrc" "$BOOTSTRAP_DOTFILES/zshrc" "bootstrap-created .zshrc uses custom DOTFILES_DIR"

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

exit $FAILED
