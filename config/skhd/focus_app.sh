#!/usr/bin/env bash

ARG="$1"
LAUNCH_CMD=""

# For @browser and @editor, find the running app name from yabai
# and set a fallback launch command
ALL_WINDOWS=$(yabai -m query --windows)

case "$ARG" in
    @browser)
        # Detect default browser app name from macOS
        BUNDLE_ID=$(plutil -convert json -o - \
            ~/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist 2>/dev/null | \
            jq -r '[.LSHandlers[] | select(.LSHandlerURLScheme == "https")] | first | .LSHandlerRoleAll // empty')
        if [ -n "$BUNDLE_ID" ]; then
            APP=$(osascript -e "name of app id \"$BUNDLE_ID\"" 2>/dev/null)
        fi
        LAUNCH_CMD="open https://google.com"
        ;;
    @editor)
        EDITORS=("Cursor" "Visual Studio Code" "Zed" "Sublime Text" "Xcode")
        for e in "${EDITORS[@]}"; do
            if echo "$ALL_WINDOWS" | jq -e "[.[] | select(.app == \"$e\")] | length > 0" >/dev/null 2>&1; then
                APP="$e"
                break
            fi
        done
        # Fall back to first installed editor
        if [ -z "$APP" ]; then
            for e in "${EDITORS[@]}"; do
                if [ -d "/Applications/$e.app" ]; then
                    APP="$e"
                    break
                fi
            done
        fi
        LAUNCH_CMD="open -a \"${APP:-TextEdit}\""
        ;;
    *)
        APP="$ARG"
        LAUNCH_CMD="open -a \"$APP\""
        ;;
esac

# No running windows found — launch
if [ -z "$APP" ]; then
    eval "$LAUNCH_CMD"
    exit 0
fi

# Get visible window IDs for this app
WINDOWS=$(echo "$ALL_WINDOWS" | jq -r \
    "[.[] | select(.app == \"$APP\" and .\"is-minimized\" == false and .\"is-hidden\" == false)] | sort_by(.id) | .[].id")

if [ -z "$WINDOWS" ]; then
    eval "$LAUNCH_CMD"
    exit 0
fi

WINDOW_COUNT=$(echo "$WINDOWS" | wc -l | tr -d ' ')

# Get currently focused window info
FOCUSED_ID=$(yabai -m query --windows --window 2>/dev/null | jq -r '.id // empty')
FOCUSED_APP=$(yabai -m query --windows --window 2>/dev/null | jq -r '.app // empty')

# App is already focused
if [ "$FOCUSED_APP" = "$APP" ]; then

    # Single window — toggle off: go back to the previous window
    if [ "$WINDOW_COUNT" -eq 1 ]; then
        yabai -m window --focus recent 2>/dev/null
        exit 0
    fi

    # Multiple windows — cycle to the next one
    FIRST=""
    NEXT=""
    FOUND=0
    for WID in $WINDOWS; do
        [ -z "$FIRST" ] && FIRST="$WID"
        if [ "$FOUND" -eq 1 ]; then
            NEXT="$WID"
            break
        fi
        [ "$WID" = "$FOCUSED_ID" ] && FOUND=1
    done

    # Wrap around to first; if we cycled all the way, toggle off
    if [ -z "$NEXT" ]; then
        if [ "$FIRST" = "$FOCUSED_ID" ]; then
            yabai -m window --focus recent 2>/dev/null
        else
            yabai -m window --focus "$FIRST"
        fi
    else
        yabai -m window --focus "$NEXT"
    fi
    exit 0
fi

# App not focused — focus its most recently active window
BEST=$(echo "$ALL_WINDOWS" | jq -r \
    "[.[] | select(.app == \"$APP\" and .\"is-minimized\" == false and .\"is-hidden\" == false)] | sort_by(.\"has-focus\", .\"is-visible\") | last | .id // empty")

if [ -n "$BEST" ]; then
    yabai -m window --focus "$BEST"
else
    yabai -m window --focus "$(echo "$WINDOWS" | head -1)"
fi
