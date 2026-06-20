#!/bin/sh
# man-me: name=media_key.sh
# man-me: category=Desktop Helper Paths
# man-me: usage=~/.config/skhd/media_key.sh ACTION
# man-me: description=Send brightness, volume, media, Mission Control, Launchpad, or Do Not Disturb key events.
# man-me: tags=hotkeys hotkey keyboard shortcut skhd media volume brightness

set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <action>" >&2
  exit 2
fi

action="$1"

case "$action" in
  brightness_down) code=144 ;;
  brightness_up) code=145 ;;
  mission_control) code=160 ;;
  launchpad) code=131 ;;
  dictation) code=180 ;;
  do_not_disturb) code=181 ;;
  previous) code=176 ;;
  play_pause) code=177 ;;
  next) code=178 ;;
  mute) code=173 ;;
  volume_down) code=174 ;;
  volume_up) code=175 ;;
  *)
    echo "unknown action: $action" >&2
    exit 2
    ;;
 esac

exec osascript -e "tell application \"System Events\" to key code $code"
