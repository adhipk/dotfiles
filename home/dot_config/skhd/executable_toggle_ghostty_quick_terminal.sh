#!/usr/bin/env bash
set -euo pipefail

scratchpad_label="quick_terminal"

# Check if scratchpad window exists and is visible
scratchpad_win=$(yabai -m query --windows | \
    jq -r --arg label "$scratchpad_label" 'map(select(.scratchpad==$label)) | .[0] // empty')

if [[ -n "$scratchpad_win" ]]; then
    # Scratchpad exists - toggle it
    yabai -m window --scratchpad "$scratchpad_label" --toggle "$scratchpad_label"
else
    # Create new scratchpad window
    # First open Ghostty
    open -n -a Ghostty

    # Wait for window to appear
    sleep 0.4

    # Get the newest Ghostty window
    win_id=$(yabai -m query --windows | \
        jq -r 'map(select(.app=="Ghostty")) | max_by(.id) | .id // empty')

    if [[ -n "$win_id" ]]; then
        # Assign it as a scratchpad
        yabai -m window "$win_id" --scratchpad "$scratchpad_label"

        # Position at bottom third of screen (floating)
        yabai -m window "$win_id" --grid 6:1:0:4:1:2
    fi
fi
