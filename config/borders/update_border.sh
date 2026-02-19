#!/usr/bin/env bash

# Script to update border color when window focus changes
# This is triggered by yabai signals

# Source centralized colorscheme
source "$HOME/dotfiles/colorschemes/colors.sh"

COLOR_MAP="$HOME/.config/borders/window_colors.json"
BORDER_WIDTH="5.0"

# Get current focused window info
WINDOW_INFO=$(yabai -m query --windows --window)
WINDOW_ID=$(echo "$WINDOW_INFO" | jq -r '.id')
WINDOW_APP=$(echo "$WINDOW_INFO" | jq -r '.app')

if [ -z "$WINDOW_ID" ] || [ "$WINDOW_ID" == "null" ]; then
    borders active_color="$BORDER_COLOR_INACTIVE" inactive_color="$BORDER_COLOR_INACTIVE" width="$BORDER_WIDTH"
    exit 0
fi

# Count non-minimized windows of the same app across all spaces
WINDOW_COUNT=$(yabai -m query --windows | jq --arg app "$WINDOW_APP" '[.[] | select(.app == $app and ."is-minimized" == false)] | length')

if [ "$WINDOW_COUNT" -le 1 ]; then
    borders active_color="$BORDER_COLOR_INACTIVE" inactive_color="$BORDER_COLOR_INACTIVE" width="$BORDER_WIDTH"
    exit 0
fi

# Multiple windows of the same app — use mark color if assigned, otherwise active color
if [ -f "$COLOR_MAP" ]; then
    COLOR=$(jq -r ".\"$WINDOW_ID\" // \"null\"" "$COLOR_MAP")

    if [ "$COLOR" != "null" ]; then
        borders active_color="$COLOR" inactive_color="$BORDER_COLOR_INACTIVE" width="$BORDER_WIDTH"
    else
        borders active_color="$BORDER_COLOR_ACTIVE" inactive_color="$BORDER_COLOR_INACTIVE" width="$BORDER_WIDTH"
    fi
else
    borders active_color="$BORDER_COLOR_ACTIVE" inactive_color="$BORDER_COLOR_INACTIVE" width="$BORDER_WIDTH"
fi
