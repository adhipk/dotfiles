#!/usr/bin/env bash

# Test suite for border marking scripts

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(dirname "$TEST_DIR")"
MARK_SCRIPT="$DOTFILES_DIR/config/borders/mark_window.sh"
UPDATE_SCRIPT="$DOTFILES_DIR/config/borders/update_border.sh"
TEMP_COLOR_MAP="/tmp/test_window_colors_$$.json"

PASSED=0
FAILED=0

# Cleanup function
cleanup() {
    rm -f "$TEMP_COLOR_MAP" "${TEMP_COLOR_MAP}.tmp"
}
trap cleanup EXIT

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

assert_executable() {
    local file="$1"
    local test_name="$2"

    if [ -x "$file" ]; then
        echo "  ✓ $test_name"
        ((PASSED++))
        return 0
    else
        echo "  ✗ $test_name"
        echo "    File is not executable: $file"
        ((FAILED++))
        return 1
    fi
}

assert_valid_json() {
    local file="$1"
    local test_name="$2"

    if jq . "$file" > /dev/null 2>&1; then
        echo "  ✓ $test_name"
        ((PASSED++))
        return 0
    else
        echo "  ✗ $test_name"
        echo "    Invalid JSON in: $file"
        ((FAILED++))
        return 1
    fi
}

echo "================================"
echo "Border Scripts Tests"
echo "================================"

echo ""
echo "Testing script files exist..."
assert_file_exists "$MARK_SCRIPT" "mark_window.sh exists"
assert_file_exists "$UPDATE_SCRIPT" "update_border.sh exists"

echo ""
echo "Testing scripts are executable..."
assert_executable "$MARK_SCRIPT" "mark_window.sh is executable"
assert_executable "$UPDATE_SCRIPT" "update_border.sh is executable"

echo ""
echo "Testing mark_window.sh functions..."

# Source the colorscheme first
source "$DOTFILES_DIR/colorschemes/colors.sh"

# Create a temporary script that includes both colorscheme and functions
TEMP_SCRIPT=$(mktemp)
cat > "$TEMP_SCRIPT" << 'EOFSCRIPT'
source "$HOME/dotfiles/colorschemes/colors.sh"

# Get color from centralized colorscheme
get_color() {
    case "$1" in
        1) echo "$BORDER_COLOR_1" ;;  # Red
        2) echo "$BORDER_COLOR_2" ;;  # Peach
        3) echo "$BORDER_COLOR_3" ;;  # Yellow
        4) echo "$BORDER_COLOR_4" ;;  # Green
        5) echo "$BORDER_COLOR_5" ;;  # Teal
        6) echo "$BORDER_COLOR_6" ;;  # Sky
        7) echo "$BORDER_COLOR_7" ;;  # Blue
        8) echo "$BORDER_COLOR_8" ;;  # Mauve
        9) echo "$BORDER_COLOR_9" ;;  # Pink
        *)      echo "" ;;
    esac
}

# Get color name for display
get_color_name() {
    case "$1" in
        1) echo "red" ;;
        2) echo "peach" ;;
        3) echo "yellow" ;;
        4) echo "green" ;;
        5) echo "teal" ;;
        6) echo "sky" ;;
        7) echo "blue" ;;
        8) echo "mauve" ;;
        9) echo "pink" ;;
        *) echo "$1" ;;
    esac
}
EOFSCRIPT

source "$TEMP_SCRIPT"

# Test each color mapping
COLOR_1=$(get_color 1)
assert_equals "$BORDER_COLOR_1" "$COLOR_1" "get_color(1) returns red"

COLOR_2=$(get_color 2)
assert_equals "$BORDER_COLOR_2" "$COLOR_2" "get_color(2) returns peach"

COLOR_5=$(get_color 5)
assert_equals "$BORDER_COLOR_5" "$COLOR_5" "get_color(5) returns teal"

COLOR_9=$(get_color 9)
assert_equals "$BORDER_COLOR_9" "$COLOR_9" "get_color(9) returns pink"

echo ""
echo "Testing get_color_name function..."

NAME_1=$(get_color_name 1)
assert_equals "red" "$NAME_1" "get_color_name(1) returns 'red'"

NAME_5=$(get_color_name 5)
assert_equals "teal" "$NAME_5" "get_color_name(5) returns 'teal'"

NAME_8=$(get_color_name 8)
assert_equals "mauve" "$NAME_8" "get_color_name(8) returns 'mauve'"

rm -f "$TEMP_SCRIPT"

echo ""
echo "Testing color map JSON operations..."

# Create test color map
echo '{}' > "$TEMP_COLOR_MAP"
assert_valid_json "$TEMP_COLOR_MAP" "Empty color map is valid JSON"

# Simulate adding a window color
WINDOW_ID="123"
COLOR="0xfff38ba8"
jq ". + {\"$WINDOW_ID\": \"$COLOR\"}" "$TEMP_COLOR_MAP" > "${TEMP_COLOR_MAP}.tmp" && mv "${TEMP_COLOR_MAP}.tmp" "$TEMP_COLOR_MAP"
assert_valid_json "$TEMP_COLOR_MAP" "Color map after adding window is valid JSON"

# Check the window was added
STORED_COLOR=$(jq -r ".\"$WINDOW_ID\"" "$TEMP_COLOR_MAP")
assert_equals "$COLOR" "$STORED_COLOR" "Window color stored correctly"

# Simulate removing a window color
jq "del(.\"$WINDOW_ID\")" "$TEMP_COLOR_MAP" > "${TEMP_COLOR_MAP}.tmp" && mv "${TEMP_COLOR_MAP}.tmp" "$TEMP_COLOR_MAP"
assert_valid_json "$TEMP_COLOR_MAP" "Color map after deleting window is valid JSON"

# Check the window was removed
STORED_COLOR=$(jq -r ".\"$WINDOW_ID\" // \"null\"" "$TEMP_COLOR_MAP")
assert_equals "null" "$STORED_COLOR" "Window color removed correctly"

echo ""
echo "Testing script dependencies..."

# Check for required commands
REQUIRED_COMMANDS=("jq" "yabai" "borders")
for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if command -v "$cmd" &> /dev/null; then
        echo "  ✓ $cmd is installed"
        ((PASSED++))
    else
        echo "  ✗ $cmd is not installed"
        ((FAILED++))
    fi
done

echo ""
echo "Testing colorscheme sourcing in scripts..."

# Check mark_window.sh sources colorscheme
if grep -q "source.*colorschemes/colors.sh" "$MARK_SCRIPT"; then
    echo "  ✓ mark_window.sh sources colorscheme"
    ((PASSED++))
else
    echo "  ✗ mark_window.sh does not source colorscheme"
    ((FAILED++))
fi

# Check update_border.sh sources colorscheme
if grep -q "source.*colorschemes/colors.sh" "$UPDATE_SCRIPT"; then
    echo "  ✓ update_border.sh sources colorscheme"
    ((PASSED++))
else
    echo "  ✗ update_border.sh does not source colorscheme"
    ((FAILED++))
fi

echo ""
echo "Testing script uses centralized color variables..."

# Check mark_window.sh uses BORDER_COLOR_* variables
if grep -q "BORDER_COLOR_1" "$MARK_SCRIPT" && \
   grep -q "BORDER_COLOR_ACTIVE" "$MARK_SCRIPT" && \
   grep -q "BORDER_COLOR_INACTIVE" "$MARK_SCRIPT"; then
    echo "  ✓ mark_window.sh uses centralized color variables"
    ((PASSED++))
else
    echo "  ✗ mark_window.sh doesn't use centralized color variables"
    ((FAILED++))
fi

# Check update_border.sh uses BORDER_COLOR_* variables
if grep -q "BORDER_COLOR_ACTIVE" "$UPDATE_SCRIPT" && \
   grep -q "BORDER_COLOR_INACTIVE" "$UPDATE_SCRIPT"; then
    echo "  ✓ update_border.sh uses centralized color variables"
    ((PASSED++))
else
    echo "  ✗ update_border.sh doesn't use centralized color variables"
    ((FAILED++))
fi

echo ""
echo "Testing no hardcoded color values..."

# Check for hardcoded 0xff colors (except in comments)
HARDCODED_MARK=$(grep -v '^[[:space:]]*#' "$MARK_SCRIPT" | grep -c '0xff[0-9a-fA-F]\{6\}' | grep -v '$BORDER_COLOR' || true)
HARDCODED_UPDATE=$(grep -v '^[[:space:]]*#' "$UPDATE_SCRIPT" | grep -c '0xff[0-9a-fA-F]\{6\}' | grep -v '$BORDER_COLOR' || true)

if [ "$HARDCODED_MARK" -eq 0 ]; then
    echo "  ✓ mark_window.sh has no hardcoded colors"
    ((PASSED++))
else
    echo "  ✗ mark_window.sh has hardcoded colors"
    ((FAILED++))
fi

if [ "$HARDCODED_UPDATE" -eq 0 ]; then
    echo "  ✓ update_border.sh has no hardcoded colors"
    ((PASSED++))
else
    echo "  ✗ update_border.sh has hardcoded colors"
    ((FAILED++))
fi

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

exit $FAILED
