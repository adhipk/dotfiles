#!/usr/bin/env bash

# Script to close all empty desktops/spaces
# Usage: close_empty_spaces.sh

# Get all spaces and their window counts
SPACES=$(yabai -m query --spaces)

# Count total spaces
TOTAL_SPACES=$(echo "$SPACES" | jq 'length')

# Get empty space indices (sorted in descending order to delete from highest to lowest)
EMPTY_SPACES=$(echo "$SPACES" | jq -r '.[] | select(.windows | length == 0) | .index' | sort -rn)

# Count empty spaces
if [ -z "$EMPTY_SPACES" ]; then
    EMPTY_COUNT=0
else
    EMPTY_COUNT=$(echo "$EMPTY_SPACES" | wc -l | tr -d ' ')
fi

if [ "$EMPTY_COUNT" -eq 0 ]; then
    echo "No empty spaces to close"
    exit 0
fi

# Don't close all spaces - keep at least one
if [ "$EMPTY_COUNT" -eq "$TOTAL_SPACES" ]; then
    echo "Cannot close all spaces - keeping at least one"
    exit 0
fi

# Close empty spaces (from highest index to lowest to avoid index shifting issues)
CLOSED=0
for space_index in $EMPTY_SPACES; do
    # Double check we're not closing the last space
    REMAINING=$(yabai -m query --spaces | jq 'length')
    if [ "$REMAINING" -le 1 ]; then
        echo "Stopped - cannot close the last space"
        break
    fi

    if yabai -m space "$space_index" --destroy 2>/dev/null; then
        ((CLOSED++))
    fi
done

if [ "$CLOSED" -gt 0 ]; then
    echo "Closed $CLOSED empty space(s)"
else
    echo "No spaces were closed"
fi
