#!/usr/bin/env bash

# Script to mark the currently focused window with a specific border color
# Usage: mark_window.sh <color> or mark_window.sh clear

# Source centralized colorscheme
source "$HOME/dotfiles/colorschemes/colors.sh"

COLOR_MAP="$HOME/.config/borders/window_colors.json"
BORDER_WIDTH="5.0"

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
        default) echo "$BORDER_COLOR_ACTIVE" ;;  # Default active color
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

# Get current focused window info
WINDOW_INFO=$(yabai -m query --windows --window)
WINDOW_ID=$(echo "$WINDOW_INFO" | jq -r '.id')
WINDOW_APP=$(echo "$WINDOW_INFO" | jq -r '.app')

if [ -z "$WINDOW_ID" ] || [ "$WINDOW_ID" == "null" ]; then
    echo "No window focused"
    exit 1
fi

# Count non-minimized windows of the same app across all spaces
WINDOW_COUNT=$(yabai -m query --windows | jq --arg app "$WINDOW_APP" '[.[] | select(.app == $app and ."is-minimized" == false)] | length')
SINGLE_WINDOW=false
[ "$WINDOW_COUNT" -le 1 ] && SINGLE_WINDOW=true

# Initialize color map file if it doesn't exist
if [ ! -f "$COLOR_MAP" ]; then
    echo '{}' > "$COLOR_MAP"
fi

# Handle the command
case "$1" in
    clear)
        echo "Cleared border for window $WINDOW_ID"
        borders active_color="$BORDER_COLOR_INACTIVE" inactive_color="$BORDER_COLOR_INACTIVE" width="$BORDER_WIDTH"
        ;;
    default)
        echo "default border for window $WINDOW_ID"
        jq "del(.\"$WINDOW_ID\")" "$COLOR_MAP" > "${COLOR_MAP}.tmp" && mv "${COLOR_MAP}.tmp" "$COLOR_MAP"
        borders active_color="$BORDER_COLOR_INACTIVE" inactive_color="$BORDER_COLOR_INACTIVE" width="$BORDER_WIDTH"
        ;;
    [1-9])
        COLOR=$(get_color "$1")
        COLOR_NAME=$(get_color_name "$1")
        jq ". + {\"$WINDOW_ID\": \"$COLOR\"}" "$COLOR_MAP" > "${COLOR_MAP}.tmp" && mv "${COLOR_MAP}.tmp" "$COLOR_MAP"
        echo "Marked window $WINDOW_ID with $COLOR_NAME border ($COLOR)"
        if [ "$SINGLE_WINDOW" = true ]; then
            borders active_color="$BORDER_COLOR_INACTIVE" width="$BORDER_WIDTH"
        else
            borders active_color="$COLOR" width="$BORDER_WIDTH"
        fi
        ;;
    *)
        echo "Usage: $0 {1-9|clear|default}"
        echo "Colors: 1=red, 2=peach, 3=yellow, 4=green, 5=teal, 6=sky, 7=blue, 8=mauve, 9=pink"
        exit 1
        ;;
esac
