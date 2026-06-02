#!/usr/bin/env bash

# Test suite for disposable install behavior

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(dirname "$TEST_DIR")"
TEMP_HOME="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install-test.XXXXXX")"
FAKE_BIN="$TEMP_HOME/bin"
ARGS_FILE="$TEMP_HOME/chezmoi-args"

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

echo "================================"
echo "Installer Tests"
echo "================================"

mkdir -p "$FAKE_BIN"
printf '#!/usr/bin/env bash\nprintf \"%%s\\\\n\" \"$*\" > \"$CHEZMOI_ARGS_FILE\"\n' > "$FAKE_BIN/chezmoi"
printf '#!/usr/bin/env bash\nexit 0\n' > "$FAKE_BIN/brew"
chmod +x "$FAKE_BIN/chezmoi" "$FAKE_BIN/brew"

echo ""
echo "Testing install wrapper..."
if HOME="$TEMP_HOME" PATH="$FAKE_BIN:/usr/bin:/bin" CHEZMOI_ARGS_FILE="$ARGS_FILE" DOTFILES_DIR="$DOTFILES_DIR" "$DOTFILES_DIR/install.sh" --dry-run >/dev/null; then
    echo "  ✓ install.sh delegates to chezmoi"
    ((PASSED++))
else
    echo "  ✗ install.sh failed"
    ((FAILED++))
fi
assert_contains "$ARGS_FILE" "^-S $DOTFILES_DIR apply --dry-run$" "install.sh passes source directory and arguments"

echo ""
echo "Testing bootstrap wrapper..."
if HOME="$TEMP_HOME" PATH="$FAKE_BIN:/usr/bin:/bin" CHEZMOI_ARGS_FILE="$ARGS_FILE" DOTFILES_DIR="$DOTFILES_DIR" "$DOTFILES_DIR/bootstrap.sh" >/dev/null; then
    echo "  ✓ bootstrap.sh delegates to install.sh"
    ((PASSED++))
else
    echo "  ✗ bootstrap.sh failed"
    ((FAILED++))
fi
assert_contains "$ARGS_FILE" "^-S $DOTFILES_DIR apply$" "bootstrap applies the chezmoi source state"

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

exit $FAILED
