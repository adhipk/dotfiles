#!/bin/bash

# jump-to-bookmark.sh <slot>
# Focus the space bookmarked in the specified slot (1-5)

SLOT=$1
BOOKMARKS_FILE="$HOME/.config/yabai/space-bookmarks.json"

# Validate slot number
if [[ ! "$SLOT" =~ ^[1-5]$ ]]; then
  osascript -e "display notification \"Invalid slot: $SLOT (use 1-5)\" with title \"yabai\""
  exit 1
fi

# Check if bookmarks file exists
if [ ! -f "$BOOKMARKS_FILE" ]; then
  osascript -e "display notification \"No bookmarks set yet\" with title \"yabai Bookmark\""
  exit 0
fi

# Get UUID for this slot
UUID=$(jq -r ".[\"$SLOT\"] // empty" "$BOOKMARKS_FILE")

if [ -z "$UUID" ] || [ "$UUID" = "null" ]; then
  osascript -e "display notification \"Bookmark slot $SLOT is empty\" with title \"yabai Bookmark\""
  exit 0
fi

# Find space with this UUID
SPACE_INDEX=$(yabai -m query --spaces | jq -r ".[] | select(.uuid == \"$UUID\") | .index")

if [ -z "$SPACE_INDEX" ]; then
  osascript -e "display notification \"Bookmarked space no longer exists\" with title \"yabai Bookmark\""
  exit 0
fi

# Focus the space
yabai -m space --focus "$SPACE_INDEX"
