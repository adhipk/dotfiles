#!/usr/bin/env bash

# Test suite for colorscheme configuration

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(dirname "$TEST_DIR")"
COLORSCHEME="$DOTFILES_DIR/colorschemes/catppuccin-mocha.sh"

PASSED=0
FAILED=0

# Test helper functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    if [ "$expected" = "$actual" ]; then
        echo "  ✓ $test_name"
        ((PASSED++))
        return 0
    else
        echo "  ✗ $test_name"
        echo "    Expected: $expected"
        echo "    Got: $actual"
        ((FAILED++))
        return 1
    fi
}

assert_not_empty() {
    local value="$1"
    local test_name="$2"

    if [ -n "$value" ]; then
        echo "  ✓ $test_name"
        ((PASSED++))
        return 0
    else
        echo "  ✗ $test_name"
        echo "    Value is empty"
        ((FAILED++))
        return 1
    fi
}

assert_hex_color() {
    local value="$1"
    local test_name="$2"

    if [[ "$value" =~ ^[0-9a-fA-F]{6}$ ]]; then
        echo "  ✓ $test_name"
        ((PASSED++))
        return 0
    else
        echo "  ✗ $test_name"
        echo "    Invalid hex color: $value"
        ((FAILED++))
        return 1
    fi
}

assert_border_color() {
    local value="$1"
    local test_name="$2"

    if [[ "$value" =~ ^0xff[0-9a-fA-F]{6}$ ]]; then
        echo "  ✓ $test_name"
        ((PASSED++))
        return 0
    else
        echo "  ✗ $test_name"
        echo "    Invalid border color format: $value"
        ((FAILED++))
        return 1
    fi
}

echo "================================"
echo "Colorscheme Tests"
echo "================================"

# Source the colorscheme
source "$COLORSCHEME"

echo ""
echo "Testing base color exports..."
assert_hex_color "$COLOR_BASE" "COLOR_BASE is valid hex"
assert_hex_color "$COLOR_TEXT" "COLOR_TEXT is valid hex"
assert_hex_color "$COLOR_RED" "COLOR_RED is valid hex"
assert_hex_color "$COLOR_GREEN" "COLOR_GREEN is valid hex"
assert_hex_color "$COLOR_BLUE" "COLOR_BLUE is valid hex"
assert_hex_color "$COLOR_YELLOW" "COLOR_YELLOW is valid hex"
assert_hex_color "$COLOR_MAUVE" "COLOR_MAUVE is valid hex"
assert_hex_color "$COLOR_PINK" "COLOR_PINK is valid hex"
assert_hex_color "$COLOR_TEAL" "COLOR_TEAL is valid hex"
assert_hex_color "$COLOR_SKY" "COLOR_SKY is valid hex"
assert_hex_color "$COLOR_PEACH" "COLOR_PEACH is valid hex"

echo ""
echo "Testing border color formats..."
assert_border_color "$BORDER_COLOR_1" "BORDER_COLOR_1 format"
assert_border_color "$BORDER_COLOR_2" "BORDER_COLOR_2 format"
assert_border_color "$BORDER_COLOR_3" "BORDER_COLOR_3 format"
assert_border_color "$BORDER_COLOR_4" "BORDER_COLOR_4 format"
assert_border_color "$BORDER_COLOR_5" "BORDER_COLOR_5 format"
assert_border_color "$BORDER_COLOR_6" "BORDER_COLOR_6 format"
assert_border_color "$BORDER_COLOR_7" "BORDER_COLOR_7 format"
assert_border_color "$BORDER_COLOR_8" "BORDER_COLOR_8 format"
assert_border_color "$BORDER_COLOR_9" "BORDER_COLOR_9 format"

echo ""
echo "Testing special border colors..."
assert_border_color "$BORDER_COLOR_ACTIVE" "BORDER_COLOR_ACTIVE format"
assert_border_color "$BORDER_COLOR_INACTIVE" "BORDER_COLOR_INACTIVE format"
assert_border_color "$BORDER_COLOR_BASE" "BORDER_COLOR_BASE format"

echo ""
echo "Testing color values match expected Catppuccin Mocha..."
assert_equals "f38ba8" "$COLOR_RED" "Red is Catppuccin red"
assert_equals "a6e3a1" "$COLOR_GREEN" "Green is Catppuccin green"
assert_equals "89b4fa" "$COLOR_BLUE" "Blue is Catppuccin blue"
assert_equals "f9e2af" "$COLOR_YELLOW" "Yellow is Catppuccin yellow"
assert_equals "cba6f7" "$COLOR_MAUVE" "Mauve is Catppuccin mauve"
assert_equals "f5c2e7" "$COLOR_PINK" "Pink is Catppuccin pink"
assert_equals "94e2d5" "$COLOR_TEAL" "Teal is Catppuccin teal"
assert_equals "89dceb" "$COLOR_SKY" "Sky is Catppuccin sky"
assert_equals "fab387" "$COLOR_PEACH" "Peach is Catppuccin peach"
assert_equals "1e1e2e" "$COLOR_BASE" "Base is Catppuccin base"

echo ""
echo "Testing border color mappings..."
assert_equals "0xff$COLOR_RED" "$BORDER_COLOR_1" "Color 1 maps to red"
assert_equals "0xff$COLOR_PEACH" "$BORDER_COLOR_2" "Color 2 maps to peach"
assert_equals "0xff$COLOR_YELLOW" "$BORDER_COLOR_3" "Color 3 maps to yellow"
assert_equals "0xff$COLOR_GREEN" "$BORDER_COLOR_4" "Color 4 maps to green"
assert_equals "0xff$COLOR_TEAL" "$BORDER_COLOR_5" "Color 5 maps to teal"
assert_equals "0xff$COLOR_SKY" "$BORDER_COLOR_6" "Color 6 maps to sky"
assert_equals "0xff$COLOR_BLUE" "$BORDER_COLOR_7" "Color 7 maps to blue"
assert_equals "0xff$COLOR_MAUVE" "$BORDER_COLOR_8" "Color 8 maps to mauve"
assert_equals "0xff$COLOR_PINK" "$BORDER_COLOR_9" "Color 9 maps to pink"

echo ""
echo "Testing JSON export..."
assert_not_empty "$COLORS_JSON" "COLORS_JSON is exported"

# Validate JSON structure if jq is available
if command -v jq &> /dev/null; then
    echo "$COLORS_JSON" | jq . > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "  ✓ COLORS_JSON is valid JSON"
        ((PASSED++))
    else
        echo "  ✗ COLORS_JSON is invalid JSON"
        ((FAILED++))
    fi

    # Test specific JSON fields
    RED_FROM_JSON=$(echo "$COLORS_JSON" | jq -r '.red')
    assert_equals "$COLOR_RED" "$RED_FROM_JSON" "JSON red matches COLOR_RED"

    BORDER_1_FROM_JSON=$(echo "$COLORS_JSON" | jq -r '.border."1"')
    assert_equals "$BORDER_COLOR_1" "$BORDER_1_FROM_JSON" "JSON border.1 matches BORDER_COLOR_1"
fi

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

exit $FAILED
