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
        red)    echo "$BORDER_COLOR_RED" ;;
        green)  echo "$BORDER_COLOR_GREEN" ;;
        blue)   echo "$BORDER_COLOR_BLUE" ;;
        yellow) echo "$BORDER_COLOR_YELLOW" ;;
        *)      echo "" ;;
    esac
}

# Get current focused window ID
WINDOW_ID=$(yabai -m query --windows --window | jq -r '.id')

if [ -z "$WINDOW_ID" ] || [ "$WINDOW_ID" == "null" ]; then
    echo "No window focused"
    exit 1
fi

# Initialize color map file if it doesn't exist
if [ ! -f "$COLOR_MAP" ]; then
    echo '{}' > "$COLOR_MAP"
fi

# Handle the command
case "$1" in
    clear)
        # Remove this window from the color map
        jq "del(.\"$WINDOW_ID\")" "$COLOR_MAP" > "${COLOR_MAP}.tmp" && mv "${COLOR_MAP}.tmp" "$COLOR_MAP"
        echo "Cleared border for window $WINDOW_ID"
        # Restore default active color for currently focused window
        borders active_color="$BORDER_COLOR_ACTIVE" inactive_color="$BORDER_COLOR_INACTIVE" width="$BORDER_WIDTH"
        ;;
    red|green|blue|yellow)
        # Get the color for this option
        COLOR=$(get_color "$1")
        # Add/update this window in the color map
        jq ". + {\"$WINDOW_ID\": \"$COLOR\"}" "$COLOR_MAP" > "${COLOR_MAP}.tmp" && mv "${COLOR_MAP}.tmp" "$COLOR_MAP"
        echo "Marked window $WINDOW_ID with $1 border ($COLOR)"
        # Apply the border immediately
        borders active_color="$COLOR" width="$BORDER_WIDTH"
        ;;
    *)
        echo "Usage: $0 {red|green|blue|yellow|clear}"
        exit 1
        ;;
esac
