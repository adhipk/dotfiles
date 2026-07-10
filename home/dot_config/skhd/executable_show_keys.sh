#!/usr/bin/env bash
# man-me: name=show_keys.sh
# man-me: category=Desktop Helper Paths
# man-me: usage=~/.config/skhd/show_keys.sh
# man-me: description=Toggle the searchable skhd shortcut guide, rebuilding it from source when needed.
# man-me: tags=hotkeys hotkey keyboard shortcut shortcuts keybinding keybindings skhd whichkey keys search interactive
# man-me: name=whichkey
# man-me: source=scripts/whichkey/WhichKey.swift
# man-me: category=Desktop Helper Paths
# man-me: usage=~/.config/skhd/whichkey
# man-me: description=Searchable SwiftUI shortcut browser launched by show_keys.sh.
# man-me: tags=hotkeys hotkey keyboard shortcut shortcuts keybinding keybindings skhd whichkey keys search interactive

set -u

app="$HOME/.config/skhd/whichkey"
dotfiles_dir="${DOTFILES_DIR:-$HOME/dotfiles}"
build_script="$dotfiles_dir/scripts/build-whichkey.sh"
source_file="$dotfiles_dir/scripts/whichkey/WhichKey.swift"
action="${1:-toggle}"

# `close` is used by skhd's default-mode entry hook. It must never turn a
# missing guide into an open one.
if [[ "$action" == "close" ]]; then
    pkill -x whichkey 2>/dev/null || true
    exit 0
fi

if [[ "$action" != "open" && "$action" != "toggle" ]]; then
    echo "usage: show_keys.sh [open|close|toggle]" >&2
    exit 2
fi

launch_lock="${TMPDIR:-/tmp}/whichkey-launch.lock"
if ! mkdir "$launch_lock" 2>/dev/null; then
    exit 0
fi
trap 'rmdir "$launch_lock" 2>/dev/null || true' EXIT

# Direct calls retain toggle behavior; modal `open` calls are idempotent.
if pgrep -x whichkey >/dev/null 2>&1; then
    if [[ "$action" == "toggle" ]]; then
        pkill -x whichkey 2>/dev/null || true
    fi
    exit 0
fi

# A direct chezmoi apply can remove the locally built app. Rebuild lazily when
# it is missing or when its checked-in source is newer than the installed copy.
if [[ ! -x "$app" || ( -f "$source_file" && "$source_file" -nt "$app" ) ||
      ( -f "$build_script" && "$build_script" -nt "$app" ) ]]; then
    if [[ ! -x "$build_script" ]]; then
        "$HOME/.config/skhd/notify.sh" "Shortcut Guide" "Build script not found at $build_script" 2>/dev/null || true
        exit 1
    fi
    build_log="${TMPDIR:-/tmp}/whichkey-build.log"
    if ! WHICHKEY_INSTALL_PATH="$app" "$build_script" >"$build_log" 2>&1; then
        "$HOME/.config/skhd/notify.sh" "Shortcut Guide" "Build failed; see $build_log" 2>/dev/null || true
        exit 1
    fi
fi

# Launch independently so the app survives skhd's short-lived shell.
nohup "$app" >/dev/null 2>&1 &
