#!/usr/bin/env bash
# man-me: name=notify.sh
# man-me: category=Desktop Helper Paths
# man-me: usage=~/.config/skhd/notify.sh TITLE MESSAGE
# man-me: description=Show macOS notifications from helper scripts.
# man-me: tags=hotkeys skhd notification terminal-notifier

title="${1:-Notification}"
message="${2:-}"

[ -n "$message" ] || exit 0

if command -v terminal-notifier >/dev/null 2>&1; then
  terminal-notifier \
    -title "$title" \
    -message "$message" \
    -group "dotfiles.skhd" \
    -ignoreDnD
  exit 0
fi

/usr/bin/osascript - "$title" "$message" <<'APPLESCRIPT'
on run argv
  set noticeTitle to item 1 of argv
  set noticeBody to item 2 of argv
  if noticeBody contains return then
    set AppleScript's text item delimiters to return
    set noticeBody to text items of noticeBody as string using " · "
    set AppleScript's text item delimiters to ""
  end if
  display notification noticeBody with title noticeTitle
end run
APPLESCRIPT
