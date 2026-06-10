#!/usr/bin/env bash
# tmux hook target: macOS notifications for hyperspace agent events.

set -euo pipefail

EVENT="${1:-event}"
SESSION="${2:-}"
WINDOW="${3:-}"
STATE_DIR="${HYPERSPACE_STATE_DIR:-$HOME/.local/state/hyperspaces}"
DEDUP_FILE="$STATE_DIR/notify-dedup.log"

mkdir -p "$STATE_DIR"

title="Hyperspace"
body="$SESSION"
if [ -n "$WINDOW" ]; then
  body="${body}/${WINDOW}"
fi
body="${body}: ${EVENT}"

# Dedup identical notifications within 30s
signature="${EVENT}|${SESSION}|${WINDOW}"
now=$(date +%s)
if [ -f "$DEDUP_FILE" ]; then
  while IFS='|' read -r ts sig _; do
    if [ "$sig" = "$signature" ] && [ $((now - ts)) -lt 30 ]; then
      exit 0
    fi
  done < <(tail -n 20 "$DEDUP_FILE" 2>/dev/null || true)
fi
printf '%s|%s\n' "$now" "$signature" >> "$DEDUP_FILE"

/usr/bin/osascript - "$title" "$body" <<'APPLESCRIPT'
on run argv
  display notification item 2 of argv with title item 1 of argv
end run
APPLESCRIPT
