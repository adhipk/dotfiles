#!/usr/bin/env bash

# Test suite for configuration files

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(dirname "$TEST_DIR")"
SKHDRC="$DOTFILES_DIR/skhdrc"
YABAIRC="$DOTFILES_DIR/yabairc"

PASSED=0
FAILED=0

# Test helper functions
assert_file_exists() {
    local file="$1"
    local test_name="$2"

    if [ -f "$file" ]; then
        echo "  ✓ $test_name"
        ((PASSED++))
        return 0
    else
        echo "  ✗ $test_name"
        echo "    File does not exist: $file"
        ((FAILED++))
        return 1
    fi
}

assert_contains() {
    local file="$1"
    local pattern="$2"
    local test_name="$3"

    if grep -q "$pattern" "$file"; then
        echo "  ✓ $test_name"
        ((PASSED++))
        return 0
    else
        echo "  ✗ $test_name"
        echo "    Pattern not found: $pattern"
        ((FAILED++))
        return 1
    fi
}

assert_not_contains() {
    local file="$1"
    local pattern="$2"
    local test_name="$3"

    if ! grep -q "$pattern" "$file"; then
        echo "  ✓ $test_name"
        ((PASSED++))
        return 0
    else
        echo "  ✗ $test_name"
        echo "    Pattern should not exist: $pattern"
        ((FAILED++))
        return 1
    fi
}

assert_count() {
    local file="$1"
    local pattern="$2"
    local expected="$3"
    local test_name="$4"

    local count=$(grep -c "$pattern" "$file" || true)
    if [ "$count" -eq "$expected" ]; then
        echo "  ✓ $test_name"
        ((PASSED++))
        return 0
    else
        echo "  ✗ $test_name"
        echo "    Expected $expected occurrences, found $count"
        ((FAILED++))
        return 1
    fi
}

echo "================================"
echo "Configuration Files Tests"
echo "================================"

echo ""
echo "Testing config files exist..."
assert_file_exists "$SKHDRC" "skhdrc exists"
assert_file_exists "$YABAIRC" "yabairc exists"

echo ""
echo "Testing skhdrc configuration..."

# Test all border shortcuts exist
assert_contains "$SKHDRC" "fn - 0.*mark_window.sh clear" "fn+0 clears border"
assert_contains "$SKHDRC" "fn - 1.*mark_window.sh 1" "fn+1 marks with color 1"
assert_contains "$SKHDRC" "fn - 2.*mark_window.sh 2" "fn+2 marks with color 2"
assert_contains "$SKHDRC" "fn - 3.*mark_window.sh 3" "fn+3 marks with color 3"
assert_contains "$SKHDRC" "fn - 4.*mark_window.sh 4" "fn+4 marks with color 4"
assert_contains "$SKHDRC" "fn - 5.*mark_window.sh 5" "fn+5 marks with color 5"
assert_contains "$SKHDRC" "fn - 6.*mark_window.sh 6" "fn+6 marks with color 6"
assert_contains "$SKHDRC" "fn - 7.*mark_window.sh 7" "fn+7 marks with color 7"
assert_contains "$SKHDRC" "fn - 8.*mark_window.sh 8" "fn+8 marks with color 8"
assert_contains "$SKHDRC" "fn - 9.*mark_window.sh 9" "fn+9 marks with color 9"

# Test no old color name shortcuts remain
assert_not_contains "$SKHDRC" "mark_window.sh red" "No legacy 'red' shortcut"
assert_not_contains "$SKHDRC" "mark_window.sh green" "No legacy 'green' shortcut"
assert_not_contains "$SKHDRC" "mark_window.sh blue" "No legacy 'blue' shortcut"
assert_not_contains "$SKHDRC" "mark_window.sh yellow" "No legacy 'yellow' shortcut"

# Test window management shortcuts
assert_contains "$SKHDRC" "ctrl + alt - h.*focus west" "Focus left (h) works"
assert_contains "$SKHDRC" "ctrl + alt - j.*focus south" "Focus down (j) works"
assert_contains "$SKHDRC" "ctrl + alt - k.*focus north" "Focus up (k) works"
assert_contains "$SKHDRC" "ctrl + alt - l.*focus east" "Focus right (l) works"

# Test window cycling shortcuts
assert_contains "$SKHDRC" "alt - tab.*focus" "Alt+tab cycles windows forward"
assert_contains "$SKHDRC" "shift + alt - tab.*focus" "Shift+alt+tab cycles windows backward"

# Test reload shortcut
assert_contains "$SKHDRC" "alt - r.*restart-service" "Reload shortcut exists"

# Test paths use correct locations
assert_contains "$SKHDRC" "~/.config/borders/mark_window.sh" "Uses correct mark_window.sh path"
assert_contains "$SKHDRC" "~/.config/skhd/" "Uses correct skhd helper path"

echo ""
echo "Testing yabairc configuration..."

# Test yabai loads scripting addition
assert_contains "$YABAIRC" "yabai --load-sa" "Loads scripting addition"

# Test layout is BSP
assert_contains "$YABAIRC" "layout.*bsp" "Uses BSP layout"

# Test padding is configured
assert_contains "$YABAIRC" "top_padding" "Top padding configured"
assert_contains "$YABAIRC" "bottom_padding" "Bottom padding configured"
assert_contains "$YABAIRC" "left_padding" "Left padding configured"
assert_contains "$YABAIRC" "right_padding" "Right padding configured"

# Test border signals are configured
assert_contains "$YABAIRC" "window_focused.*update_border.sh" "Window focus signal exists"
assert_contains "$YABAIRC" "window_destroyed.*update_border.sh" "Window destroy signal exists"
assert_contains "$YABAIRC" "application_hidden.*update_border.sh" "App hidden signal exists"

# Test update_border.sh path is correct
assert_contains "$YABAIRC" "\$HOME/.config/borders/update_border.sh" "Uses correct update_border.sh path"

# Test common window rules exist
assert_contains "$YABAIRC" "System Settings.*manage=off" "System Settings rule exists"
assert_contains "$YABAIRC" "Calculator.*manage=off" "Calculator rule exists"

echo ""
echo "Testing configuration consistency..."

# Count all border shortcuts
BORDER_SHORTCUTS=$(grep -c "fn - [0-9].*mark_window.sh" "$SKHDRC" || true)
if [ "$BORDER_SHORTCUTS" -eq 10 ]; then
    echo "  ✓ All 10 border shortcuts present (fn+0 through fn+9)"
    ((PASSED++))
else
    echo "  ✗ Expected 10 border shortcuts, found $BORDER_SHORTCUTS"
    ((FAILED++))
fi

# Check yabai has exactly 3 border update signals
BORDER_SIGNALS=$(grep -c "update_border.sh" "$YABAIRC" || true)
if [ "$BORDER_SIGNALS" -eq 3 ]; then
    echo "  ✓ All 3 border update signals present"
    ((PASSED++))
else
    echo "  ✗ Expected 3 border signals, found $BORDER_SIGNALS"
    ((FAILED++))
fi

echo ""
echo "Testing no syntax errors..."

# Test skhdrc can be parsed (basic check)
if bash -n "$SKHDRC" 2>/dev/null; then
    echo "  ✓ skhdrc has no bash syntax errors"
    ((PASSED++))
else
    echo "  ✗ skhdrc has bash syntax errors"
    ((FAILED++))
fi

# Test yabairc can be parsed
if bash -n "$YABAIRC" 2>/dev/null; then
    echo "  ✓ yabairc has no bash syntax errors"
    ((PASSED++))
else
    echo "  ✗ yabairc has bash syntax errors"
    ((FAILED++))
fi

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

exit $FAILED
