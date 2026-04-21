#!/usr/bin/env bash

# Script to reload all configurations after changing colorscheme
# Usage: ./reload_colors.sh

set -e

echo "Reloading configurations with new colorscheme..."

# Restart yabai and skhd to pick up any config changes
echo "  ✓ Restarting yabai and skhd..."
yabai --restart-service
skhd --restart-service

echo ""
echo "✓ All configurations reloaded!"
echo ""
