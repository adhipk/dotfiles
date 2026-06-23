#!/usr/bin/env bash

# Test suite for configuration files

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(dirname "$TEST_DIR")"
SKHDRC="$DOTFILES_DIR/home/dot_skhdrc"
YABAIRC="$DOTFILES_DIR/home/dot_yabairc"
KARABINER_CONFIG="$DOTFILES_DIR/home/dot_config/private_karabiner/karabiner.json"
HOTKEYS="$DOTFILES_DIR/home/bin/executable_hotkeys"

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
assert_file_exists "$KARABINER_CONFIG" "Karabiner config exists"

echo ""
echo "Testing Karabiner configuration..."
if jq -e '
    .profiles[]
    | select(.selected == true)
    | .complex_modifications.rules[]
    | .manipulators[]
    | select(
        .type == "basic"
        and .from.key_code == "caps_lock"
        and .to[0].key_code == "left_control"
        and .to[0].lazy == true
        and .to[0].modifiers == ["left_option", "left_command"]
        and .to_if_alone[0].key_code == "caps_lock"
    )
' "$KARABINER_CONFIG" >/dev/null; then
    echo "  ✓ Caps Lock is a hyper key on hold and Caps Lock on tap"
    ((PASSED++))
else
    echo "  ✗ Caps Lock hyper key mapping is missing or invalid"
    ((FAILED++))
fi

echo ""
echo "Testing skhdrc configuration..."

# Test window management shortcuts
assert_contains "$SKHDRC" "ctrl + alt - h.*snap_window.sh left" "Snap left (h) works"
assert_contains "$SKHDRC" "ctrl + alt - k.*snap_window.sh right" "Snap right (k) works"
assert_contains "$SKHDRC" "ctrl + alt + shift - h.*swap west" "Swap left (h) works"
assert_contains "$SKHDRC" "ctrl + alt + shift - k.*swap east" "Swap right (k) works"

# Test window cycling shortcuts
assert_contains "$SKHDRC" "alt - tab.*focus" "Alt+tab cycles windows forward"
assert_contains "$SKHDRC" "shift + alt - tab.*focus" "Shift+alt+tab cycles windows backward"

# Test space management shortcuts
assert_contains "$SKHDRC" "ctrl + alt - f.*float-prefs toggle" "Float toggle remembers preferences"
assert_contains "$SKHDRC" "alt - k.*close_empty_spaces.sh" "Alt+k closes empty spaces"
assert_contains "$SKHDRC" "space_slot_mode @.*Space Shortcut" "Space shortcut mode shows entry notification"
assert_contains "$SKHDRC" "space_slot_mode < 1.*projects set-space-slot 1" "Alt+Shift+= sets space shortcut 1"
assert_contains "$SKHDRC" "alt + shift - 1.*projects focus-space 1" "Alt+Shift+1 focuses project space slot 1"
assert_contains "$SKHDRC" "alt + shift - h.*projects cycle prev" "Alt+Shift+h cycles project spaces"
assert_contains "$SKHDRC" "alt + shift - k.*projects cycle next" "Alt+Shift+k cycles project spaces"
assert_contains "$SKHDRC" "ctrl + alt + cmd - p.*projects pick" "Hyper+p opens project hub"
assert_contains "$SKHDRC" "ctrl + alt + cmd - n.*projects new" "Hyper+n quick-creates project"
assert_contains "$SKHDRC" "ctrl + alt + cmd - e.*projects pick" "Hyper+e opens project hub"
assert_contains "$SKHDRC" "ctrl + alt + cmd - 1.*projects focus-project 1" "Hyper+1 focuses project slot 1"
assert_contains "$SKHDRC" "ctrl + alt + cmd + shift - 1.*projects adopt --project-slot 1" "Hyper+Shift+1 adopts into project slot 1"
assert_contains "$SKHDRC" "ctrl + alt + cmd + shift - 0x33.*projects detach" "Hyper+Shift+Backspace detaches current space"
assert_not_contains "$SKHDRC" "ctrl + alt + shift - 1.*window --space 1" "Mission Control index moves removed"
assert_contains "$SKHDRC" "alt - 1.*hotkeys app-focus 1.*@browser" "Alt+1 browser focus goes through hotkeys"
assert_contains "$SKHDRC" "alt - 2.*hotkeys app-focus 2.*@editor" "Alt+2 editor focus goes through zen gate"
assert_contains "$SKHDRC" "alt - 3.*hotkeys app-focus 3.*Microsoft Teams" "Alt+3 Teams focus goes through zen gate"
assert_contains "$SKHDRC" "alt - 4.*hotkeys app-focus 4.*Slack" "Alt+4 Slack focus goes through zen gate"
assert_contains "$SKHDRC" "alt + shift - 0x2A.*hotkeys zen toggle" "Alt+Shift+Backslash toggles zen mode"

assert_contains "$HOTKEYS" "ZEN_MODE_FILE=.*zen_mode" "hotkeys stores zen mode state"
assert_contains "$HOTKEYS" "2|3|4)" "hotkeys disables app slots 2-4 in zen mode"

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

# Removed in yabai 7.1.17
assert_not_contains "$YABAIRC" "window_topmost" "Removed window_topmost option is not configured"

# Test padding is configured
assert_contains "$YABAIRC" "top_padding" "Top padding configured"
assert_contains "$YABAIRC" "bottom_padding" "Bottom padding configured"
assert_contains "$YABAIRC" "left_padding" "Left padding configured"
assert_contains "$YABAIRC" "right_padding" "Right padding configured"

# Border signals should be removed
assert_not_contains "$YABAIRC" "update_border.sh" "No border signals remain"
assert_not_contains "$YABAIRC" "auto_mark.sh" "No auto mark signal remains"
assert_not_contains "$YABAIRC" "cleanup_marks.sh" "No cleanup mark signal remains"

# Floating window preferences are replayed on startup.
assert_contains "$YABAIRC" 'float-prefs" apply-rules' "yabairc restores floating window preferences"
assert_contains "$YABAIRC" 'projects record-focus' "yabairc tracks project last_space on focus"
assert_contains "$YABAIRC" 'app-mru.sh update' "yabairc tracks app MRU stacks on focus"
assert_contains "$YABAIRC" 'tile_pip_on_create.*window_created.*tile-pip-window' "yabairc tiles PiP windows when created"
assert_contains "$YABAIRC" 'tile_pip_on_title_change.*window_title_changed.*tile-pip-window' "yabairc tiles windows that become PiP"
assert_contains "$YABAIRC" 'tile_pip_windows.*manage=on.*sticky=off.*sub-layer=auto' "yabairc manages PiP windows"
assert_not_contains "$YABAIRC" 'float-prefs apply-window' "yabairc does not use float signal handlers"

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
