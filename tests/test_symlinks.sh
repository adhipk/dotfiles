#!/usr/bin/env bash

# Test suite for symlink integrity

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(dirname "$TEST_DIR")"

PASSED=0
FAILED=0

# Test helper functions
assert_symlink_exists() {
    local link="$1"
    local test_name="$2"

    if [ -L "$link" ]; then
        echo "  ✓ $test_name"
        ((PASSED++))
        return 0
    else
        echo "  ✗ $test_name"
        echo "    Symlink does not exist: $link"
        ((FAILED++))
        return 1
    fi
}

assert_symlink_target() {
    local link="$1"
    local expected_target="$2"
    local test_name="$3"

    if [ -L "$link" ]; then
        local actual_target=$(readlink "$link")
        # Expand ~ in expected target
        expected_target="${expected_target/#\~/$HOME}"

        if [ "$actual_target" = "$expected_target" ]; then
            echo "  ✓ $test_name"
            ((PASSED++))
            return 0
        else
            echo "  ✗ $test_name"
            echo "    Expected: $expected_target"
            echo "    Got: $actual_target"
            ((FAILED++))
            return 1
        fi
    else
        echo "  ✗ $test_name"
        echo "    Not a symlink: $link"
        ((FAILED++))
        return 1
    fi
}

assert_symlink_valid() {
    local link="$1"
    local test_name="$2"

    if [ -L "$link" ] && [ -e "$link" ]; then
        echo "  ✓ $test_name"
        ((PASSED++))
        return 0
    else
        echo "  ✗ $test_name"
        if [ ! -L "$link" ]; then
            echo "    Not a symlink: $link"
        else
            echo "    Broken symlink (target doesn't exist): $link"
        fi
        ((FAILED++))
        return 1
    fi
}

echo "================================"
echo "Symlink Integrity Tests"
echo "================================"

echo ""
echo "Testing top-level config symlinks..."
assert_symlink_exists "$HOME/.skhdrc" ".skhdrc is a symlink"
assert_symlink_exists "$HOME/.yabairc" ".yabairc is a symlink"

echo ""
echo "Testing symlink targets are correct..."
assert_symlink_target "$HOME/.skhdrc" "$DOTFILES_DIR/skhdrc" ".skhdrc points to dotfiles"
assert_symlink_target "$HOME/.yabairc" "$DOTFILES_DIR/yabairc" ".yabairc points to dotfiles"

echo ""
echo "Testing symlinks are not broken..."
assert_symlink_valid "$HOME/.skhdrc" ".skhdrc target exists"
assert_symlink_valid "$HOME/.yabairc" ".yabairc target exists"

echo ""
echo "Testing border script symlinks..."
if [ -L "$HOME/.config/borders/mark_window.sh" ]; then
    assert_symlink_exists "$HOME/.config/borders/mark_window.sh" "mark_window.sh is a symlink"
    assert_symlink_target "$HOME/.config/borders/mark_window.sh" "$DOTFILES_DIR/config/borders/mark_window.sh" "mark_window.sh points to dotfiles"
    assert_symlink_valid "$HOME/.config/borders/mark_window.sh" "mark_window.sh target exists"
else
    echo "  ⚠ mark_window.sh is not a symlink (may be direct file)"
fi

if [ -L "$HOME/.config/borders/update_border.sh" ]; then
    assert_symlink_exists "$HOME/.config/borders/update_border.sh" "update_border.sh is a symlink"
    assert_symlink_target "$HOME/.config/borders/update_border.sh" "$DOTFILES_DIR/config/borders/update_border.sh" "update_border.sh points to dotfiles"
    assert_symlink_valid "$HOME/.config/borders/update_border.sh" "update_border.sh target exists"
else
    echo "  ⚠ update_border.sh is not a symlink (may be direct file)"
fi

echo ""
echo "Testing colorscheme symlink..."
assert_symlink_exists "$DOTFILES_DIR/colorschemes/colors.sh" "colors.sh is a symlink"
assert_symlink_target "$DOTFILES_DIR/colorschemes/colors.sh" "catppuccin-mocha.sh" "colors.sh points to catppuccin-mocha.sh"
assert_symlink_valid "$DOTFILES_DIR/colorschemes/colors.sh" "colors.sh target exists"

echo ""
echo "Testing skhd helper scripts..."
for script in focus_app.sh show_keys.sh whichkey; do
    if [ -L "$HOME/.config/skhd/$script" ]; then
        assert_symlink_valid "$HOME/.config/skhd/$script" "$script is valid symlink"
    elif [ -f "$HOME/.config/skhd/$script" ]; then
        echo "  ⚠ $script exists but is not a symlink"
    else
        echo "  ✗ $script does not exist"
        ((FAILED++))
    fi
done

echo ""
echo "Testing yabai helper scripts..."
if [ -L "$HOME/.config/yabai/close_empty_spaces.sh" ]; then
    assert_symlink_valid "$HOME/.config/yabai/close_empty_spaces.sh" "close_empty_spaces.sh is valid symlink"
elif [ -f "$HOME/.config/yabai/close_empty_spaces.sh" ]; then
    echo "  ⚠ close_empty_spaces.sh exists but is not a symlink"
else
    echo "  ✗ close_empty_spaces.sh does not exist"
    ((FAILED++))
fi

echo ""
echo "Testing source files exist in dotfiles..."
REQUIRED_FILES=(
    "$DOTFILES_DIR/skhdrc"
    "$DOTFILES_DIR/yabairc"
    "$DOTFILES_DIR/config/borders/mark_window.sh"
    "$DOTFILES_DIR/config/borders/update_border.sh"
    "$DOTFILES_DIR/colorschemes/catppuccin-mocha.sh"
    "$DOTFILES_DIR/colorschemes/colors.sh"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -e "$file" ]; then
        echo "  ✓ $(basename "$file") exists in dotfiles"
        ((PASSED++))
    else
        echo "  ✗ $(basename "$file") missing from dotfiles"
        ((FAILED++))
    fi
done

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

exit $FAILED
