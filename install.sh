#!/usr/bin/env bash
# man-me: name=install.sh
# man-me: category=Repository Setup
# man-me: usage=./install.sh [chezmoi apply args...]
# man-me: description=Apply this source state with chezmoi and build ProjectDeck on macOS.
# man-me: tags=install setup apply chezmoi dotfiles projectdeck bootstrap
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
CHEZMOI_SOURCE_ROOT="$DOTFILES_DIR"
CHEZMOI_DESTINATION="${HOME:?HOME is not set}"

if ! command -v chezmoi >/dev/null 2>&1; then
    echo "chezmoi is not installed. Run ./bootstrap.sh or brew install chezmoi." >&2
    exit 1
fi

is_dry_run=false
for arg in "$@"; do
    if [[ "$arg" == "--dry-run" || "$arg" == "-n" ]]; then
        is_dry_run=true
        break
    fi
done

show_status() {
    local status

    status=$(chezmoi -S "$CHEZMOI_SOURCE_ROOT" status)
    if [[ -n "$status" ]]; then
        printf '%s\n' "$status"
        if grep -qE '^[[:space:]]*R[[:space:]]+\.chezmoiscripts/' <<<"$status"; then
            echo "  note: R .chezmoiscripts entries are run-after hooks evaluated on every apply."
        fi
    else
        echo "  (none)"
    fi
}

show_managed_file_summary() {
    local status

    status=$(chezmoi -S "$CHEZMOI_SOURCE_ROOT" status --exclude=scripts)
    if [[ -n "$status" ]]; then
        echo "[dotfiles] managed files still differ after apply:"
        printf '%s\n' "$status"
    else
        echo "[dotfiles] managed files are up to date."
    fi
}

build_projectdeck() {
    local build_script="$DOTFILES_DIR/scripts/build-projectdeck.sh"

    [[ "$(uname -s)" == "Darwin" ]] || return 0
    [[ -x "$build_script" ]] || return 0

    echo "[dotfiles] building projectdeck..."
    PROJECTDECK_INSTALL_PATH="$CHEZMOI_DESTINATION/.config/yabai/projectdeck" \
        "$build_script"
}

echo "[dotfiles] repository:  $DOTFILES_DIR"
echo "[dotfiles] source:      $CHEZMOI_SOURCE_ROOT"
echo "[dotfiles] destination: $CHEZMOI_DESTINATION"
echo "[dotfiles] pending changes before apply:"
show_status
if [[ "${DOTFILES_DEBUG:-0}" == "1" ]]; then
    echo "[dotfiles] running: chezmoi -S \"$CHEZMOI_SOURCE_ROOT\" apply --verbose $*"
    chezmoi -S "$CHEZMOI_SOURCE_ROOT" apply --verbose "$@"
else
    echo "[dotfiles] running: chezmoi -S \"$CHEZMOI_SOURCE_ROOT\" apply $*"
    chezmoi -S "$CHEZMOI_SOURCE_ROOT" apply "$@"
fi

if [[ "$is_dry_run" == true ]]; then
    echo "[dotfiles] dry run complete; no files were changed."
else
    build_projectdeck
    echo "[dotfiles] pending changes after apply:"
    show_status
    show_managed_file_summary
    echo "[dotfiles] apply complete."
fi
