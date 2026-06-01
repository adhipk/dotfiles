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

# Get all non-minimized, non-hidden window IDs for this app (including other displays)
WINDOWS=$(echo "$ALL_WINDOWS" | jq -r --arg app "$APP" \
    '[.[] | select(.app == $app and ."is-minimized" == false and ."is-hidden" == false)] | sort_by(.id) | .[].id')

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
# Prefer windows on current space/display, then fall back to any window
CURRENT_SPACE=$(yabai -m query --spaces --space | jq -r '.index')
CURRENT_DISPLAY=$(yabai -m query --displays --display | jq -r '.index')
BEST=$(echo "$ALL_WINDOWS" | jq -r --arg app "$APP" --arg space "$CURRENT_SPACE" --arg display "$CURRENT_DISPLAY" \
    '[.[] | select(.app == $app and ."is-minimized" == false and ."is-hidden" == false)] |
     sort_by(
       if .space == ($space | tonumber) then 0 else 1 end,
       if .display == ($display | tonumber) then 0 else 1 end,
       if ."has-focus" then 0 else 1 end,
       if ."is-visible" then 0 else 1 end
     ) |
     first | .id // empty')

if [ -n "$BEST" ]; then
    # Get the space and display of the target window
    TARGET_SPACE=$(echo "$ALL_WINDOWS" | jq -r --arg wid "$BEST" \
        '[.[] | select(.id == ($wid | tonumber))] | first | .space // empty')
    TARGET_DISPLAY=$(echo "$ALL_WINDOWS" | jq -r --arg wid "$BEST" \
        '[.[] | select(.id == ($wid | tonumber))] | first | .display // empty')

    # If window is on a different space, switch to that space first
    if [ -n "$TARGET_SPACE" ] && [ "$TARGET_SPACE" != "$CURRENT_SPACE" ]; then
        yabai -m space --focus "$TARGET_SPACE"
    # Otherwise if on different display (multi-monitor), switch display
    elif [ -n "$TARGET_DISPLAY" ] && [ "$TARGET_DISPLAY" != "$CURRENT_DISPLAY" ]; then
        yabai -m display --focus "$TARGET_DISPLAY"
    fi

    yabai -m window --focus "$BEST"
else
    yabai -m window --focus "$(echo "$WINDOWS" | head -1)"
fi
