#!/usr/bin/env bash
set -euo pipefail

temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/default-apps.XXXXXX")
trap 'rm -rf "$temp_dir"' EXIT

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

    if [[ -n "$app_path" ]]; then
        basename "$app_path" .app
    else
        printf '%s\n' "(none)"
    fi
}

default_app_for_extension() {
    local extension="${1#.}"
    local sample_file="$temp_dir/sample.$extension"

    touch "$sample_file"
    default_app_for_url file "$sample_file"
}

print_url_default() {
    local label="$1"
    local url="$2"

    printf '%-20s %s\n' "$label" "$(default_app_for_url scheme "$url")"
}

print_extension_default() {
    local label="$1"
    local extension="$2"

    printf '%-20s %s\n' "$label" "$(default_app_for_extension "$extension")"
}

print_default_for_argument() {
    local value="$1"

    case "$value" in
        .* | *.*)
            if [[ "$value" != */* && "$value" != *:* ]]; then
                print_extension_default "$value" "$value"
                return
            fi
            ;;
    esac

    if [[ "$value" == *:* ]]; then
        print_url_default "$value" "$value"
    elif [[ -e "$value" ]]; then
        printf '%-20s %s\n' "$value" "$(default_app_for_url file "$(cd "$(dirname "$value")" && pwd)/$(basename "$value")")"
    else
        printf '%-20s %s\n' "$value" "(path does not exist)"
    fi
}

if (( $# > 0 )); then
    for value in "$@"; do
        print_default_for_argument "$value"
    done
    exit 0
fi

print_url_default "Browser (https)" "https://example.com"
print_url_default "Email (mailto)" "mailto:test@example.com"
print_extension_default "Markdown (.md)" ".md"
print_extension_default "Text (.txt)" ".txt"
print_extension_default "PDF (.pdf)" ".pdf"
print_extension_default "Image (.png)" ".png"
