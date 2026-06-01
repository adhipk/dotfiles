#!/usr/bin/env bash
set -euo pipefail

terminal_app=${TERMINAL_APP:-Ghostty}
current_space=$(yabai -m query --spaces --space | jq -r '.index')

# Prevent key-repeat storms from spawning many windows on long key holds.
lock_dir="/tmp/open_terminal_window.lock"
state_file="/tmp/open_terminal_window.last_ms"
cooldown_ms=1200

if ! mkdir "$lock_dir" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "$lock_dir"' EXIT

now_ms=$(perl -MTime::HiRes=time -e 'printf "%.0f\n", time()*1000')
if [[ -f "$state_file" ]]; then
  last_ms=$(cat "$state_file" 2>/dev/null || echo 0)
  if [[ "$last_ms" =~ ^[0-9]+$ ]] && (( now_ms - last_ms < cooldown_ms )); then
    exit 0
  fi
fi
printf '%s\n' "$now_ms" > "$state_file"

# Add a temporary rule to ensure the new window opens on the current space
rule_label="temp_terminal_rule_$$"
yabai -m rule --add app="^${terminal_app}$" space="$current_space" label="$rule_label"

# Open a new terminal window using the appropriate method
if [[ "$terminal_app" == "Ghostty" ]]; then
  # Ghostty: Use -n to open a new window (not a new instance)
  open -n -a "$terminal_app"
elif [[ "$terminal_app" == "iTerm2" ]]; then
  osascript -e 'tell application "iTerm2" to create window with default profile'
elif [[ "$terminal_app" == "Terminal" ]]; then
  osascript -e 'tell application "Terminal" to do script ""'
elif [[ "$terminal_app" == "kitty" ]]; then
  # kitty uses remote control
  /Applications/kitty.app/Contents/MacOS/kitty --single-instance --directory="$PWD" &
else
  # Fallback: open new instance
  open -n -a "$terminal_app"
fi

# Wait briefly for the window to exist, then focus it and remove the rule
win_id=""
for _ in {1..12}; do
  win_id=$(yabai -m query --windows | jq -r --arg app "$terminal_app" --argjson space "$current_space" 'map(select(.app==$app and .space==$space)) | max_by(.id) | .id // empty')
  if [[ -n "$win_id" ]]; then
    break
  fi
  sleep 0.1
done

# Remove the temporary rule
yabai -m rule --remove "$rule_label" >/dev/null 2>&1 || true

if [[ -n "$win_id" ]]; then
  yabai -m window --focus "$win_id" >/dev/null 2>&1 || true
fi
