#!/usr/bin/env bash

# Integration tests - test how components work together

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(dirname "$TEST_DIR")"

PASSED=0
FAILED=0

# Test helper functions
assert_success() {
    local test_name="$1"
    local command="$2"

    if eval "$command" > /dev/null 2>&1; then
        echo "  ✓ $test_name"
        ((PASSED++))
        return 0
    else
        echo "  ✗ $test_name"
        echo "    Command failed: $command"
        ((FAILED++))
        return 1
    fi
}

assert_command_exists() {
    local cmd="$1"
    local test_name="$2"

    if command -v "$cmd" &> /dev/null; then
        echo "  ✓ $test_name"
        ((PASSED++))
        return 0
    else
        echo "  ✗ $test_name"
        echo "    Command not found: $cmd"
        ((FAILED++))
        return 1
    fi
}

echo "================================"
echo "Integration Tests"
echo "================================"

echo ""
echo "Testing required system tools..."
assert_command_exists "yabai" "yabai is installed"
assert_command_exists "skhd" "skhd is installed"
assert_command_exists "borders" "borders (JankyBorders) is installed"
assert_command_exists "jq" "jq is installed"

echo ""
echo "Testing colorscheme can be sourced..."
if source "$DOTFILES_DIR/colorschemes/colors.sh" 2>/dev/null; then
    echo "  ✓ Colorscheme sources without errors"
    ((PASSED++))

    # Test exports are available
    if [ -n "$BORDER_COLOR_1" ] && [ -n "$BORDER_COLOR_ACTIVE" ]; then
        echo "  ✓ Color variables are exported"
        ((PASSED++))
    else
        echo "  ✗ Color variables not exported"
        ((FAILED++))
    fi
else
    echo "  ✗ Colorscheme has errors"
    ((FAILED++))
fi

echo ""
echo "Testing border scripts can source colorscheme..."

# Test mark_window.sh
MARK_SCRIPT="$DOTFILES_DIR/config/borders/mark_window.sh"
if bash -c "source '$MARK_SCRIPT' 2>&1" | grep -q "No window focused\|Usage:"; then
    echo "  ✓ mark_window.sh runs (expected to fail without window)"
    ((PASSED++))
else
    ERRORS=$(bash -c "source '$MARK_SCRIPT' 2>&1" | head -5)
    echo "  ✗ mark_window.sh has unexpected errors"
    echo "$ERRORS" | sed 's/^/    /'
    ((FAILED++))
fi

# Test update_border.sh
UPDATE_SCRIPT="$DOTFILES_DIR/config/borders/update_border.sh"
TEMP_OUTPUT=$(mktemp)
bash "$UPDATE_SCRIPT" > "$TEMP_OUTPUT" 2>&1
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo "  ✓ update_border.sh runs without errors"
    ((PASSED++))
else
    echo "  ✗ update_border.sh exits with error code $EXIT_CODE"
    cat "$TEMP_OUTPUT" | sed 's/^/    /'
    ((FAILED++))
fi
rm -f "$TEMP_OUTPUT"

echo ""
echo "Testing reload_colors.sh script..."
if [ -x "$DOTFILES_DIR/reload_colors.sh" ]; then
    echo "  ✓ reload_colors.sh is executable"
    ((PASSED++))

    # Check it sources colorscheme
    if grep -q "source.*colorschemes/colors.sh" "$DOTFILES_DIR/reload_colors.sh"; then
        echo "  ✓ reload_colors.sh sources colorscheme"
        ((PASSED++))
    else
        echo "  ✗ reload_colors.sh doesn't source colorscheme"
        ((FAILED++))
    fi

    # Check it updates borders
    if grep -q "borders active_color" "$DOTFILES_DIR/reload_colors.sh"; then
        echo "  ✓ reload_colors.sh updates borders"
        ((PASSED++))
    else
        echo "  ✗ reload_colors.sh doesn't update borders"
        ((FAILED++))
    fi
else
    echo "  ✗ reload_colors.sh is not executable"
    ((FAILED++))
fi

echo ""
echo "Testing install.sh script..."
if [ -x "$DOTFILES_DIR/install.sh" ]; then
    echo "  ✓ install.sh is executable"
    ((PASSED++))

    # Check it creates necessary directories
    if grep -q "mkdir.*config/borders" "$DOTFILES_DIR/install.sh"; then
        echo "  ✓ install.sh creates border directories"
        ((PASSED++))
    else
        echo "  ✗ install.sh doesn't create border directories"
        ((FAILED++))
    fi

    # Check it creates symlinks
    if grep -q "ln -sf" "$DOTFILES_DIR/install.sh"; then
        echo "  ✓ install.sh creates symlinks"
        ((PASSED++))
    else
        echo "  ✗ install.sh doesn't create symlinks"
        ((FAILED++))
    fi
else
    echo "  ✗ install.sh is not executable"
    ((FAILED++))
fi

echo ""
echo "Testing git repository..."
if [ -d "$DOTFILES_DIR/.git" ]; then
    echo "  ✓ Dotfiles is a git repository"
    ((PASSED++))

    # Check if there are commits
    if git -C "$DOTFILES_DIR" log --oneline -1 > /dev/null 2>&1; then
        echo "  ✓ Git repository has commits"
        ((PASSED++))
    else
        echo "  ✗ Git repository has no commits"
        ((FAILED++))
    fi

    # Check if .gitignore exists
    if [ -f "$DOTFILES_DIR/.gitignore" ]; then
        echo "  ✓ .gitignore exists"
        ((PASSED++))

        # Check it ignores window_colors.json
        if grep -q "window_colors.json" "$DOTFILES_DIR/.gitignore"; then
            echo "  ✓ .gitignore ignores window_colors.json"
            ((PASSED++))
        else
            echo "  ✗ .gitignore doesn't ignore window_colors.json"
            ((FAILED++))
        fi
    else
        echo "  ✗ .gitignore doesn't exist"
        ((FAILED++))
    fi
else
    echo "  ✗ Dotfiles is not a git repository"
    ((FAILED++))
fi

echo ""
echo "Testing README documentation..."
if [ -f "$DOTFILES_DIR/README.md" ]; then
    echo "  ✓ README.md exists"
    ((PASSED++))

    # Check it documents the 9 colors
    COLOR_COUNT=$(grep -c "fn + [1-9]" "$DOTFILES_DIR/README.md" || true)
    if [ "$COLOR_COUNT" -ge 9 ]; then
        echo "  ✓ README documents all 9 border colors"
        ((PASSED++))
    else
        echo "  ✗ README doesn't document all 9 colors (found $COLOR_COUNT)"
        ((FAILED++))
    fi

    # Check it has installation instructions
    if grep -q "install.sh" "$DOTFILES_DIR/README.md"; then
        echo "  ✓ README has installation instructions"
        ((PASSED++))
    else
        echo "  ✗ README missing installation instructions"
        ((FAILED++))
    fi
else
    echo "  ✗ README.md doesn't exist"
    ((FAILED++))
fi

echo ""
echo "Testing yabai and skhd are running..."
if pgrep -x "yabai" > /dev/null; then
    echo "  ✓ yabai is running"
    ((PASSED++))

    # Test yabai can be queried
    if yabai -m query --windows > /dev/null 2>&1; then
        echo "  ✓ yabai responds to queries"
        ((PASSED++))
    else
        echo "  ✗ yabai doesn't respond to queries"
        ((FAILED++))
    fi
else
    echo "  ⚠ yabai is not running (skipping query test)"
fi

if pgrep -x "skhd" > /dev/null; then
    echo "  ✓ skhd is running"
    ((PASSED++))
else
    echo "  ⚠ skhd is not running"
fi

if pgrep -f "borders" > /dev/null; then
    echo "  ✓ borders is running"
    ((PASSED++))
else
    echo "  ⚠ borders is not running"
fi

echo ""
echo "Testing end-to-end color flow..."
# Source colorscheme
source "$DOTFILES_DIR/colorschemes/colors.sh"

# Check color 1 flows through correctly
EXPECTED_COLOR_1="0xff${COLOR_RED}"
if [ "$BORDER_COLOR_1" = "$EXPECTED_COLOR_1" ]; then
    echo "  ✓ Color 1 (red) flows from base to border format"
    ((PASSED++))
else
    echo "  ✗ Color 1 doesn't match"
    echo "    Expected: $EXPECTED_COLOR_1"
    echo "    Got: $BORDER_COLOR_1"
    ((FAILED++))
fi

# Check active color
EXPECTED_ACTIVE="0xff${COLOR_ACTIVE_BORDER}"
if [ "$BORDER_COLOR_ACTIVE" = "$EXPECTED_ACTIVE" ]; then
    echo "  ✓ Active color flows from base to border format"
    ((PASSED++))
else
    echo "  ✗ Active color doesn't match"
    echo "    Expected: $EXPECTED_ACTIVE"
    echo "    Got: $BORDER_COLOR_ACTIVE"
    ((FAILED++))
fi

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

exit $FAILED
