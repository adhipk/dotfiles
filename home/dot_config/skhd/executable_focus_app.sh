#!/usr/bin/env bash
# man-me: name=focus_app.sh
# man-me: category=Desktop Helper Paths
# man-me: usage=~/.config/skhd/focus_app.sh APP
# man-me: description=Focus, MRU-cycle, toggle, or launch an app; @browser resolves the macOS HTTPS handler and @editor uses EDITOR_APP (default VSCodium).
# man-me: tags=hotkeys hotkey keyboard shortcut skhd app focus browser editor ghostty

PRESENTATION_MODE=false
PRESENTATION_MODE_FILE="$HOME/.config/skhd/presentation_mode"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=app-mru.sh
source "$SCRIPT_DIR/app-mru.sh"

while [[ "${1:-}" == --* ]]; do
    case "$1" in
        --single-window|--presentation)
            PRESENTATION_MODE=true
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            break
            ;;
    esac
done

ARG="${1:-}"
LAUNCH_CMD=""

if [ -f "$PRESENTATION_MODE_FILE" ] && [ "$(cat "$PRESENTATION_MODE_FILE" 2>/dev/null)" = "on" ]; then
    PRESENTATION_MODE=true
fi

# Resolve macOS default handlers at invocation time so changes made in System
# Settings take effect without updating this file.
default_app_for_url() {
    local url_type="$1"
    local url="$2"
    local app_path

    app_path=$(/usr/bin/osascript -l JavaScript \
        -e 'ObjC.import("AppKit")' \
        -e 'ObjC.import("Foundation")' \
        -e 'function run(argv) {
            var url = argv[0] === "file"
                ? $.NSURL.fileURLWithPath(argv[1])
                : $.NSURL.URLWithString(argv[1]);
            var appURL = $.NSWorkspace.sharedWorkspace.URLForApplicationToOpenURL(url);
            return appURL ? ObjC.unwrap(appURL.path) : "";
        }' \
        -- "$url_type" "$url" 2>/dev/null)

    if [ -n "$app_path" ]; then
        basename "$app_path" .app
    fi
}

case "$ARG" in
    @browser)
        APP=$(default_app_for_url scheme "https://google.com")
        LAUNCH_CMD="open https://google.com"
        ;;
    @editor)
        APP="${EDITOR_APP:-VSCodium}"
        LAUNCH_CMD="open -a \"${APP}\""
        ;;
    *)
        APP="$ARG"
        LAUNCH_CMD="open -a \"$APP\""
        ;;
esac

if [ "$APP" = "Ghostty" ]; then
    LAUNCH_CMD="$HOME/bin/hotkeys terminal new"
fi

if [ -z "$APP" ]; then
    if [ -n "$LAUNCH_CMD" ]; then
        eval "$LAUNCH_CMD"
    fi
    exit 0
fi

app_mru_require_tools || exit 1
app_mru_cycle "$APP" "$LAUNCH_CMD" "$PRESENTATION_MODE"
