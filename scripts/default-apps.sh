#!/usr/bin/env bash
# man-me: name=default-apps
# man-me: category=Development and Repo
# man-me: usage=default-apps list; default-apps get .md; default-apps set .md Obsidian
# man-me: description=Inspect and change macOS default application handlers.
# man-me: tags=defaults macos app handlers duti development
set -euo pipefail

temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/default-apps.XXXXXX")
trap 'rm -rf "$temp_dir"' EXIT

usage() {
    cat <<'EOF'
default-apps - inspect and change macOS default application handlers

Usage:
  default-apps
  default-apps list
  default-apps get TARGET [...]
  default-apps set TARGET APP
  default-apps help
  default-apps --help

Commands:
  list
      List common default handlers. This is also the default command when no
      arguments are provided.

  get TARGET [...]
      Print the handler for each target. The "get" keyword is optional, so
      "default-apps .md" is equivalent to "default-apps get .md".

  set TARGET APP
      Set the default application for a file extension or URL scheme. Changing
      defaults requires duti, installed with "brew install duti".

  help, -h, --help
      Show this help text.

Targets:
  .EXTENSION
      A file extension with a leading dot, such as ".md" or ".pdf".

  URL:
      A URL scheme with a trailing colon, such as "https:" or "mailto:".

  PATH
      An existing file path. Paths can be inspected with "get" but cannot be
      changed with "set".

Applications:
  APP may be an application name, an application path, or a bundle ID.

Examples:
  default-apps list
  default-apps get .md .txt
  default-apps .pdf
  default-apps set .md Obsidian
  default-apps set .md /Applications/Obsidian.app
  default-apps set .md md.obsidian
  default-apps set https: Safari
EOF
}

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

require_duti() {
    if ! command -v duti >/dev/null 2>&1; then
        printf '%s\n' "duti is required to change defaults. Install it with: brew install duti" >&2
        exit 1
    fi
}

resolve_bundle_id() {
    local app="$1"
    local app_name
    local app_path=""
    local root

    if [[ "$app" == */* ]]; then
        app_path="$app"
    else
        app_name="${app%.app}"
        for root in /Applications "$HOME/Applications" /System/Applications /System/Applications/Utilities; do
            if [[ -d "$root/$app_name.app" ]]; then
                app_path="$root/$app_name.app"
                break
            fi
        done
    fi

    if [[ -z "$app_path" ]]; then
        printf '%s\n' "$app"
        return
    fi

    if [[ ! -d "$app_path" ]]; then
        printf 'Application does not exist: %s\n' "$app_path" >&2
        return 1
    fi

    if ! /usr/bin/plutil -extract CFBundleIdentifier raw -o - "$app_path/Contents/Info.plist"; then
        printf 'Could not read bundle ID from: %s\n' "$app_path" >&2
        return 1
    fi
}

set_default() {
    local target="$1"
    local app="$2"
    local bundle_id
    local scheme

    require_duti
    bundle_id=$(resolve_bundle_id "$app")

    if [[ "$target" == *:* ]]; then
        scheme="${target%%:*}"
        if [[ ! "$scheme" =~ ^[[:alpha:]][[:alnum:]+.-]*$ ]]; then
            printf 'Invalid URL scheme: %s\n' "$target" >&2
            return 1
        fi
        duti -s "$bundle_id" "$scheme"
        printf '%s -> %s\n' "$scheme:" "$bundle_id"
    elif [[ "$target" == .* && "$target" != */* ]]; then
        duti -s "$bundle_id" "$target" all
        printf '%s -> %s\n' "$target" "$bundle_id"
    else
        printf 'Expected an extension such as .md or a URL scheme such as https:; got: %s\n' "$target" >&2
        return 1
    fi
}

list_defaults() {
    print_url_default "Browser (https)" "https://example.com"
    print_url_default "Email (mailto)" "mailto:test@example.com"
    print_extension_default "Markdown (.md)" ".md"
    print_extension_default "Text (.txt)" ".txt"
    print_extension_default "PDF (.pdf)" ".pdf"
    print_extension_default "Image (.png)" ".png"
}

if [[ "${1:-}" == "set" ]]; then
    if (( $# != 3 )); then
        usage >&2
        exit 1
    fi
    set_default "$2" "$3"
    exit 0
fi

if [[ "${1:-}" == "list" ]]; then
    if (( $# != 1 )); then
        usage >&2
        exit 1
    fi
    list_defaults
    exit 0
fi

if [[ "${1:-}" == "get" ]]; then
    if (( $# < 2 )); then
        usage >&2
        exit 1
    fi
    shift
    for value in "$@"; do
        print_default_for_argument "$value"
    done
    exit 0
fi

if [[ "${1:-}" == "help" || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if (( $# > 0 )); then
    for value in "$@"; do
        print_default_for_argument "$value"
    done
    exit 0
fi

list_defaults
