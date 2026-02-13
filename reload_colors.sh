#!/usr/bin/env bash

# Script to reload all configurations after changing colorscheme
# Usage: ./reload_colors.sh

set -e

# Source the colorscheme
source "$HOME/dotfiles/colorschemes/colors.sh"

echo "Reloading configurations with new colorscheme..."

# Update borders
echo "  ✓ Updating borders..."
borders active_color="$BORDER_COLOR_ACTIVE" inactive_color="$BORDER_COLOR_INACTIVE" width=5.0

# Restart yabai and skhd to pick up any config changes
echo "  ✓ Restarting yabai and skhd..."
yabai --restart-service
skhd --restart-service

# Clear any marked window colors to force re-evaluation
echo "  ✓ Clearing cached window colors..."
echo '{}' > "$HOME/.config/borders/window_colors.json"

echo ""
echo "✓ All configurations reloaded!"
echo "  Active border: #$COLOR_ACTIVE_BORDER"
echo "  Inactive border: #$COLOR_BASE"
echo ""
