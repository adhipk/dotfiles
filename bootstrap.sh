#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
BREWFILE="$DOTFILES_DIR/Brewfile"

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

echo "Installing dotfiles..."
./install.sh

echo ""
echo "Next steps:"
echo "  1. Restart yabai and skhd: alt+r"
echo "  2. Start borders with: borders active_color=$(source ~/dotfiles/colorschemes/colors.sh && echo $BORDER_COLOR_ACTIVE) inactive_color=$(source ~/dotfiles/colorschemes/colors.sh && echo $BORDER_COLOR_INACTIVE) width=5.0"
