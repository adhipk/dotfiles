#!/usr/bin/env bash
set -euo pipefail

scratchpad_label="quick_terminal"

scratchpad_win=$(yabai -m query --windows | \
  jq -r --arg label "$scratchpad_label" 'map(select(.scratchpad==$label)) | .[0] // empty')

if [[ -n "$scratchpad_win" ]]; then
  yabai -m window --scratchpad "$scratchpad_label" --toggle "$scratchpad_label"
else
  env -u ZDOTDIR open -n -a Ghostty

  sleep 0.4

  win_id=$(yabai -m query --windows | \
    jq -r 'map(select(.app=="Ghostty")) | max_by(.id) | .id // empty')

  if [[ -n "$win_id" ]]; then
    yabai -m window "$win_id" --scratchpad "$scratchpad_label"
    yabai -m window "$win_id" --grid 6:1:0:4:1:2
  fi
fi
