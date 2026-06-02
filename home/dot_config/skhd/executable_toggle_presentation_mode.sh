#!/usr/bin/env bash

set -euo pipefail

STATE_FILE="$HOME/.config/skhd/presentation_mode"
mkdir -p "$(dirname "$STATE_FILE")"

if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE" 2>/dev/null)" = "on" ]; then
  printf '%s\n' "off" > "$STATE_FILE"
  /usr/bin/osascript -e 'display notification "Presentation mode off" with title "skhd"'
else
  printf '%s\n' "on" > "$STATE_FILE"
  /usr/bin/osascript -e 'display notification "Presentation mode on" with title "skhd"'
fi
