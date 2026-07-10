#!/usr/bin/env bash
# man-me: name=bootstrap.sh
# man-me: category=Repository Setup
# man-me: usage=./bootstrap.sh
# man-me: description=Install Homebrew dependencies, apply dotfiles, install tmux plugins and native HUDs, and start desktop services.
# man-me: tags=bootstrap setup install homebrew brewfile chezmoi dotfiles tmux tpm codex tuxedo todo tasks yabai skhd
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
BREWFILE="$DOTFILES_DIR/Brewfile"
export DOTFILES_DIR

start_desktop_service() {
  local service="$1"

  command -v "$service" >/dev/null 2>&1 || return 0
  echo "Starting $service launch service..."
  if ! "$service" --start-service; then
    echo "warning: could not start $service automatically; retry after granting macOS permissions." >&2
  fi
}

if [ ! -d "$DOTFILES_DIR" ]; then
  echo "Dotfiles directory not found at $DOTFILES_DIR" >&2
  exit 1
fi

cd "$DOTFILES_DIR"

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

if [ -f "$BREWFILE" ]; then
  echo "Installing dependencies from Brewfile..."
  brew bundle --file "$BREWFILE"
else
  echo "Brewfile not found at $BREWFILE" >&2
  exit 1
fi

echo "Applying chezmoi source state..."
"$DOTFILES_DIR/install.sh"

start_desktop_service yabai
start_desktop_service skhd

echo ""
echo "Next steps:"
echo "  1. Grant Accessibility to yabai, skhd, and Ghostty; approve Karabiner's DriverKit extension and Input Monitoring access."
echo "  2. Complete yabai's SIP setup, then run: setup-yabai-sa"
echo "     https://github.com/asmvik/yabai/wiki/Disabling-System-Integrity-Protection"
echo "  3. Sign in to the Codex app and CLI."
echo "  4. Open this directory's canonical task list: todo"
echo "  5. Review personal commands: man-me"
