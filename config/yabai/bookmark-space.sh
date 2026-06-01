#!/bin/bash

# bookmark-space.sh <slot>
# Pin the current space to a bookmark slot (1-5)

SLOT=$1
BOOKMARKS_FILE="$HOME/.config/yabai/space-bookmarks.json"

# Validate slot number
if [[ ! "$SLOT" =~ ^[1-5]$ ]]; then
  osascript -e "display notification \"Invalid slot: $SLOT (use 1-5)\" with title \"yabai\""
  exit 1
fi

# Initialize file if doesn't exist or is empty
if [ ! -f "$BOOKMARKS_FILE" ] || [ ! -s "$BOOKMARKS_FILE" ]; then
  mkdir -p "$(dirname "$BOOKMARKS_FILE")"
  echo '{"1":null,"2":null,"3":null,"4":null,"5":null}' > "$BOOKMARKS_FILE"
fi

# Get current space UUID
UUID=$(yabai -m query --spaces --space | jq -r '.uuid')

if [ -z "$UUID" ] || [ "$UUID" = "null" ]; then
  osascript -e "display notification \"Could not get current space\" with title \"yabai\""
  exit 1
fi

# Update bookmark file using jq
jq ".[\"$SLOT\"] = \"$UUID\"" "$BOOKMARKS_FILE" > "$BOOKMARKS_FILE.tmp"
mv "$BOOKMARKS_FILE.tmp" "$BOOKMARKS_FILE"

# Update space label for visual feedback
CURRENT_LABEL=$(yabai -m query --spaces --space | jq -r '.label')

# Remove any existing bookmark prefix from label
CLEAN_LABEL=$(echo "$CURRENT_LABEL" | sed -E 's/^📌[0-9] ?//')

if [ -z "$CLEAN_LABEL" ] || [ "$CLEAN_LABEL" = "null" ]; then
  yabai -m space --label "📌$SLOT"
else
  yabai -m space --label "📌$SLOT $CLEAN_LABEL"
fi

# Notify user
osascript -e "display notification \"Space bookmarked to slot $SLOT\" with title \"yabai Bookmark\""
