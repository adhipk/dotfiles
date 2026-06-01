#!/bin/bash

# unbookmark-space.sh <slot>
# Remove bookmark from specified slot (1-5)

SLOT=$1
BOOKMARKS_FILE="$HOME/.config/yabai/space-bookmarks.json"

# Validate slot number
if [[ ! "$SLOT" =~ ^[1-5]$ ]]; then
  osascript -e "display notification \"Invalid slot: $SLOT (use 1-5)\" with title \"yabai\""
  exit 1
fi

# Check if bookmarks file exists
if [ ! -f "$BOOKMARKS_FILE" ]; then
  osascript -e "display notification \"No bookmarks set\" with title \"yabai Bookmark\""
  exit 0
fi

# Get UUID for this slot to find the space
UUID=$(jq -r ".[\"$SLOT\"] // empty" "$BOOKMARKS_FILE")

# Clear the bookmark
jq ".[\"$SLOT\"] = null" "$BOOKMARKS_FILE" > "$BOOKMARKS_FILE.tmp"
mv "$BOOKMARKS_FILE.tmp" "$BOOKMARKS_FILE"

# If there was a UUID, find and update the space label
if [ -n "$UUID" ] && [ "$UUID" != "null" ]; then
  SPACE_INDEX=$(yabai -m query --spaces | jq -r ".[] | select(.uuid == \"$UUID\") | .index")

  if [ -n "$SPACE_INDEX" ]; then
    # Remove bookmark prefix from label
    CURRENT_LABEL=$(yabai -m query --spaces --space "$SPACE_INDEX" | jq -r '.label')
    CLEAN_LABEL=$(echo "$CURRENT_LABEL" | sed -E 's/^📌[0-9] ?//')

    if [ -z "$CLEAN_LABEL" ] || [ "$CLEAN_LABEL" = "null" ]; then
      yabai -m space "$SPACE_INDEX" --label ""
    else
      yabai -m space "$SPACE_INDEX" --label "$CLEAN_LABEL"
    fi
  fi
fi

# Notify user
osascript -e "display notification \"Bookmark slot $SLOT cleared\" with title \"yabai Bookmark\""
