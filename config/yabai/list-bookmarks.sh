#!/bin/bash

# list-bookmarks.sh
# Display all current bookmarks with their space indices and labels

BOOKMARKS_FILE="$HOME/.config/yabai/space-bookmarks.json"

if [ ! -f "$BOOKMARKS_FILE" ]; then
  echo "No bookmarks file found"
  exit 0
fi

echo "Current Space Bookmarks:"
echo "========================"

for SLOT in {1..5}; do
  UUID=$(jq -r ".[\"$SLOT\"] // empty" "$BOOKMARKS_FILE")

  if [ -z "$UUID" ] || [ "$UUID" = "null" ]; then
    echo "Slot $SLOT: (empty)"
  else
    # Find space with this UUID
    SPACE_INFO=$(yabai -m query --spaces | jq -r ".[] | select(.uuid == \"$UUID\") | {index, label, display}")

    if [ -z "$SPACE_INFO" ]; then
      echo "Slot $SLOT: UUID $UUID (space deleted)"
    else
      INDEX=$(echo "$SPACE_INFO" | jq -r '.index')
      LABEL=$(echo "$SPACE_INFO" | jq -r '.label // "(no label)"')
      DISPLAY=$(echo "$SPACE_INFO" | jq -r '.display')
      echo "Slot $SLOT: Space $INDEX on Display $DISPLAY - $LABEL"
    fi
  fi
done
