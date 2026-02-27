#!/usr/bin/env bash
set -euo pipefail

terminal_app=${TERMINAL_APP:-Ghostty}
current_space=$(yabai -m query --spaces --space | jq -r '.index')

open -na "$terminal_app"

# Wait briefly for the window to exist, then move/focus it in the current space.
win_id=""
for _ in {1..12}; do
  win_id=$(yabai -m query --windows | jq -r --arg app "$terminal_app" 'map(select(.app==$app)) | max_by(.id) | .id // empty')
  if [[ -n "$win_id" ]]; then
    break
  fi
  sleep 0.1
done

if [[ -n "$win_id" ]]; then
  yabai -m window "$win_id" --space "$current_space" >/dev/null 2>&1 || true
  yabai -m space --focus "$current_space" >/dev/null 2>&1 || true
  yabai -m window --focus "$win_id" >/dev/null 2>&1 || true
fi
