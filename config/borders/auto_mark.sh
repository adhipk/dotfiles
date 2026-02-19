#!/usr/bin/env bash

# Auto-mark a newly created window if there are already other windows of the same app.
# Triggered by yabai window_created signal ($YABAI_WINDOW_ID is set).

source "$HOME/dotfiles/colorschemes/colors.sh"

COLOR_MAP="$HOME/.config/borders/window_colors.json"

[ -z "$YABAI_WINDOW_ID" ] && exit 0

WINDOW_APP=$(yabai -m query --windows --window "$YABAI_WINDOW_ID" 2>/dev/null | jq -r '.app')
[ -z "$WINDOW_APP" ] || [ "$WINDOW_APP" == "null" ] && exit 0

WINDOW_COUNT=$(yabai -m query --windows | jq --arg app "$WINDOW_APP" \
  '[.[] | select(.app == $app and ."is-minimized" == false)] | length')

[ "$WINDOW_COUNT" -le 1 ] && exit 0

[ ! -f "$COLOR_MAP" ] && echo '{}' > "$COLOR_MAP"

# Collect colors already assigned to other windows of the same app
SAME_APP_IDS=$(yabai -m query --windows | jq --arg app "$WINDOW_APP" \
  '[.[] | select(.app == $app and ."is-minimized" == false) | .id | tostring]')

USED_COLORS=$(jq -r --argjson ids "$SAME_APP_IDS" \
  '[to_entries[] | select(.key as $k | $ids | index($k)) | .value] | .[]' "$COLOR_MAP" 2>/dev/null)

COLORS=(
  "$BORDER_COLOR_1" "$BORDER_COLOR_2" "$BORDER_COLOR_3"
  "$BORDER_COLOR_4" "$BORDER_COLOR_5" "$BORDER_COLOR_6"
  "$BORDER_COLOR_7" "$BORDER_COLOR_8" "$BORDER_COLOR_9"
)

CHOSEN=""
for c in "${COLORS[@]}"; do
  echo "$USED_COLORS" | grep -qF "$c" && continue
  CHOSEN="$c"
  break
done

[ -z "$CHOSEN" ] && CHOSEN="$BORDER_COLOR_1"

jq --arg id "$YABAI_WINDOW_ID" --arg color "$CHOSEN" \
  '. + {($id): $color}' "$COLOR_MAP" > "${COLOR_MAP}.tmp" && mv "${COLOR_MAP}.tmp" "$COLOR_MAP"
