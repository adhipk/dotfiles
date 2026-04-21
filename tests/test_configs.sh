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

# Test window management shortcuts
assert_contains "$SKHDRC" "ctrl + alt - h.*focus west" "Focus left (h) works"
assert_contains "$SKHDRC" "ctrl + alt - j.*focus south" "Focus down (j) works"
assert_contains "$SKHDRC" "ctrl + alt - k.*focus north" "Focus up (k) works"
assert_contains "$SKHDRC" "ctrl + alt - l.*focus east" "Focus right (l) works"

# Test window cycling shortcuts
assert_contains "$SKHDRC" "alt - tab.*focus" "Alt+tab cycles windows forward"
assert_contains "$SKHDRC" "shift + alt - tab.*focus" "Shift+alt+tab cycles windows backward"

# Test space management shortcuts
assert_contains "$SKHDRC" "alt - k.*close_empty_spaces.sh" "Alt+k closes empty spaces"

# Test reload shortcut
assert_contains "$SKHDRC" "alt - r.*restart-service" "Reload shortcut exists"

# Border shortcuts should be removed
assert_not_contains "$SKHDRC" "mark_window.sh" "No border keybindings remain"

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

# Border signals should be removed
assert_not_contains "$YABAIRC" "update_border.sh" "No border signals remain"
assert_not_contains "$YABAIRC" "auto_mark.sh" "No auto mark signal remains"
assert_not_contains "$YABAIRC" "cleanup_marks.sh" "No cleanup mark signal remains"

# Test common window rules exist
assert_contains "$YABAIRC" "System Settings.*manage=off" "System Settings rule exists"
assert_contains "$YABAIRC" "Calculator.*manage=off" "Calculator rule exists"

echo ""
echo "Testing configuration consistency..."

# Ensure no border references remain
assert_not_contains "$SKHDRC" "fn - [0-9].*mark_window.sh" "No fn border mappings remain"
assert_not_contains "$YABAIRC" "config/borders" "No borders path in yabairc"

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
