#!/usr/bin/env bash

# Script to update border color when window focus changes
# This is triggered by yabai signals

# Source centralized colorscheme
source "$HOME/dotfiles/colorschemes/colors.sh"

COLOR_MAP="$HOME/.config/borders/window_colors.json"
BORDER_WIDTH="5.0"

# Get current focused window ID
WINDOW_ID=$(yabai -m query --windows --window | jq -r '.id')

if [ -z "$WINDOW_ID" ] || [ "$WINDOW_ID" == "null" ]; then
    # No window focused, do nothing (let borders handle default behavior)
    exit 0
fi

# Check if this window has a color assigned
if [ -f "$COLOR_MAP" ]; then
    COLOR=$(jq -r ".\"$WINDOW_ID\" // \"null\"" "$COLOR_MAP")

    if [ "$COLOR" != "null" ]; then
        # Window is marked with a specific color
        borders active_color="$COLOR" width="$BORDER_WIDTH"
    fi
    # If COLOR is null, do nothing - let borders use default active/inactive colors
fi
