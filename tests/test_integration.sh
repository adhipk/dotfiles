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
echo "Testing reload_colors.sh script..."
if [ -x "$DOTFILES_DIR/reload_colors.sh" ]; then
    echo "  ✓ reload_colors.sh is executable"
    ((PASSED++))

    # Check it restarts services
    if grep -q "restart-service" "$DOTFILES_DIR/reload_colors.sh"; then
        echo "  ✓ reload_colors.sh restarts services"
        ((PASSED++))
    else
        echo "  ✗ reload_colors.sh doesn't restart services"
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

    # Check it creates core config directories
    if grep -q "mkdir.*config/skhd" "$DOTFILES_DIR/install.sh" && grep -q "mkdir.*config/yabai" "$DOTFILES_DIR/install.sh"; then
        echo "  ✓ install.sh creates core config directories"
        ((PASSED++))
    else
        echo "  ✗ install.sh doesn't create core config directories"
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

        # Check it ignores local secrets
        if grep -q "zshrc.secrets" "$DOTFILES_DIR/.gitignore"; then
            echo "  ✓ .gitignore ignores local secrets"
            ((PASSED++))
        else
            echo "  ✗ .gitignore doesn't ignore local secrets"
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

    # Check it documents Yazi integration
    if grep -q "Yazi" "$DOTFILES_DIR/README.md"; then
        echo "  ✓ README documents Yazi integration"
        ((PASSED++))
    else
        echo "  ✗ README missing Yazi integration docs"
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

echo ""
echo "Testing no border integration remains..."
if ! grep -R "config/borders\\|mark_window.sh\\|update_border.sh" "$DOTFILES_DIR"/{install.sh,skhdrc,yabairc,README.md} > /dev/null 2>&1; then
    echo "  ✓ Border integration removed from core configs"
    ((PASSED++))
else
    echo "  ✗ Border integration references still present"
    ((FAILED++))
fi

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

exit $FAILED
