#!/usr/bin/env bash
set -euo pipefail

if ! command -v fswatch >/dev/null 2>&1; then
  echo "watch-sync: fswatch not found." >&2
  echo "Install it with: brew install fswatch" >&2
  exit 1
fi

dotfiles_dir="${DOTFILES_DIR:-$HOME/dotfiles}"

echo "watch-sync: watching for changes..."
echo "  - ${dotfiles_dir}/scripts/"
echo "  - ${dotfiles_dir}/config/skhd/"
echo "  - ${dotfiles_dir}/config/yabai/"
echo ""
echo "Will run: ${dotfiles_dir}/install.sh"

fswatch -o \
  "${dotfiles_dir}/scripts" \
  "${dotfiles_dir}/config/skhd" \
  "${dotfiles_dir}/config/yabai" \
  | while read -r _; do
      echo ""
      echo "watch-sync: change detected, syncing..."
      "${dotfiles_dir}/install.sh"
      echo "watch-sync: done."
    done
