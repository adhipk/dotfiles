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
