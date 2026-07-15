#!/usr/bin/env bash
# man-me: name=bootstrap.sh
# man-me: category=Repository Setup
# man-me: usage=./bootstrap.sh
# man-me: description=Install Homebrew dependencies from Brewfile, then apply the dotfiles.
# man-me: tags=bootstrap setup install homebrew brewfile chezmoi dotfiles
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
BREWFILE="$DOTFILES_DIR/Brewfile"
export DOTFILES_DIR

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

echo ""
echo "Next steps:"
echo "  1. Restart yabai and skhd: alt+r"
echo "  2. Review personal commands: man-me"
