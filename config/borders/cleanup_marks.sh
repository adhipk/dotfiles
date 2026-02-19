#!/usr/bin/env bash

# Clean up window marks when a window is destroyed.
# Removes the destroyed window's entry and clears marks for any app
# that is back down to a single window.
# Triggered by yabai window_destroyed signal ($YABAI_WINDOW_ID is set).

source "$HOME/dotfiles/colorschemes/colors.sh"

COLOR_MAP="$HOME/.config/borders/window_colors.json"
BORDER_WIDTH="5.0"

[ ! -f "$COLOR_MAP" ] && exit 0

# Remove the destroyed window from the color map
if [ -n "$YABAI_WINDOW_ID" ]; then
  jq --arg id "$YABAI_WINDOW_ID" 'del(.[$id])' "$COLOR_MAP" > "${COLOR_MAP}.tmp" && mv "${COLOR_MAP}.tmp" "$COLOR_MAP"
fi

# Remove stale entries for windows that no longer exist
ALL_IDS=$(yabai -m query --windows | jq '[.[].id | tostring]')
jq --argjson ids "$ALL_IDS" \
  'with_entries(select(.key as $k | $ids | index($k)))' "$COLOR_MAP" > "${COLOR_MAP}.tmp" && mv "${COLOR_MAP}.tmp" "$COLOR_MAP"

# For any app now down to 1 non-minimized window, remove that window's mark
SOLO_IDS=$(yabai -m query --windows | jq \
  '[group_by(.app)[] | map(select(."is-minimized" == false)) | select(length == 1) | .[0].id | tostring]')

jq --argjson solos "$SOLO_IDS" \
  'with_entries(select(.key as $k | $solos | index($k) | not))' "$COLOR_MAP" > "${COLOR_MAP}.tmp" && mv "${COLOR_MAP}.tmp" "$COLOR_MAP"
