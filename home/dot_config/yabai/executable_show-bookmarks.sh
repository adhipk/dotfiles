#!/bin/bash

# show-bookmarks.sh
# Display notification with all current bookmarks

BOOKMARKS_FILE="$HOME/.config/yabai/space-bookmarks.json"

if [ ! -f "$BOOKMARKS_FILE" ]; then
  osascript -e "display notification \"No bookmarks set\" with title \"Pinned Spaces\""
  exit 0
fi

# Build notification message
MESSAGE=""
FOUND_ANY=false

for SLOT in {1..5}; do
  UUID=$(jq -r ".[\"$SLOT\"] // empty" "$BOOKMARKS_FILE")

  if [ -n "$UUID" ] && [ "$UUID" != "null" ]; then
    FOUND_ANY=true
    # Find space with this UUID
    SPACE_INFO=$(yabai -m query --spaces | jq -r ".[] | select(.uuid == \"$UUID\")")

    if [ -n "$SPACE_INFO" ]; then
      INDEX=$(echo "$SPACE_INFO" | jq -r '.index')
      LABEL=$(echo "$SPACE_INFO" | jq -r '.label // ""' | sed -E 's/^📌[0-9] ?//')

      if [ -z "$LABEL" ]; then
        MESSAGE="${MESSAGE}$SLOT: Space $INDEX\n"
      else
        MESSAGE="${MESSAGE}$SLOT: Space $INDEX ($LABEL)\n"
      fi
    else
      MESSAGE="${MESSAGE}$SLOT: (deleted)\n"
    fi
  fi
done

if [ "$FOUND_ANY" = false ]; then
  osascript -e "display notification \"No spaces pinned yet\" with title \"Pinned Spaces\""
else
  # Remove trailing newline
  MESSAGE=$(echo -e "$MESSAGE" | sed '$d')
  osascript -e "display notification \"$MESSAGE\" with title \"Pinned Spaces\""
fi
