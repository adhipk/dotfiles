#!/usr/bin/env bash
# man-me: name=focus-open-tmux-window.sh
# man-me: category=Desktop Helper Paths
# man-me: usage=~/.config/skhd/focus-open-tmux-window.sh SLOT|cycle
# man-me: description=Focus or cycle open normal tmux terminal windows in creation order.
# man-me: tags=hotkeys hotkey keyboard shortcut fn tmux session window focus ghostty yabai

set -euo pipefail

action="${1:-}"
case "$action" in
  [1-9]|cycle) ;;
  *)
    printf 'usage: focus-open-tmux-window.sh SLOT|cycle\n' >&2
    exit 2
    ;;
esac

command -v yabai >/dev/null 2>&1 || {
  printf 'focus-open-tmux-window: yabai is not installed\n' >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || {
  printf 'focus-open-tmux-window: jq is not installed\n' >&2
  exit 1
}

windows_json="$(yabai -m query --windows)"
eligible_windows_filter='
  [
    .[]
    | select(.app == "Ghostty")
    | select((.scratchpad // "") == "")
    | select((.title // "") | test("^tmux( · .+)?$"))
  ]
  | sort_by(.id)
'

if [[ "$action" == cycle ]]; then
  current_window_id="$(
    yabai -m query --windows --window 2>/dev/null \
      | jq -r '.id // empty' 2>/dev/null \
      || true
  )"
  window_id="$(
    jq -r --argjson current "${current_window_id:-0}" "
      $eligible_windows_filter
      | if length == 0 then empty
        else (map(.id) | index(\$current)) as \$current_index
        | if \$current_index == null then .[0].id
          else .[(\$current_index + 1) % length].id
          end
        end
    " <<<"$windows_json"
  )"
else
  window_id="$(
    jq -r --argjson index "$((action - 1))" "
      $eligible_windows_filter
      | .[\$index].id // empty
    " <<<"$windows_json"
  )"
fi

if [[ -z "$window_id" ]]; then
  printf 'focus-open-tmux-window: no matching open tmux window for %s\n' "$action" >&2
  exit 1
fi

yabai -m window --focus "$window_id"
