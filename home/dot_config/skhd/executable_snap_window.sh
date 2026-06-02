#!/usr/bin/env bash
set -euo pipefail

direction=$1

# Get display and window dimensions
display_width=$(yabai -m query --displays --display | jq -r '.frame.w')
window_width=$(yabai -m query --windows --window | jq -r '.frame.w')

# Warp window to the edge first
if [[ "$direction" == "left" ]]; then
  # Move to leftmost position
  yabai -m window --warp west 2>/dev/null || true
else
  # Move to rightmost position
  yabai -m window --warp east 2>/dev/null || true
fi

# Calculate target: 50% of screen width
target_width=$(printf "%.0f" $(echo "$display_width / 2" | bc -l))

# Calculate difference
diff=$(echo "$target_width - $window_width" | bc)

# Resize the window by the difference
if (( $(echo "$diff > 0" | bc -l) )); then
  # Need to expand
  yabai -m window --resize right:${diff}:0 2>/dev/null || \
  yabai -m window --resize left:-${diff}:0 2>/dev/null
else
  # Need to shrink
  diff=$(echo "$diff * -1" | bc)
  yabai -m window --resize right:-${diff}:0 2>/dev/null || \
  yabai -m window --resize left:${diff}:0 2>/dev/null
fi
