#!/usr/bin/env bash
# man-me: name=bootstrap.sh
# man-me: category=Repository Setup
# man-me: usage=./bootstrap.sh
# man-me: description=Install Homebrew dependencies, apply dotfiles, install tmux plugins and native HUDs, and start desktop services.
# man-me: tags=bootstrap setup install homebrew brewfile chezmoi dotfiles tmux tpm codex tuxedo todo tasks yabai skhd
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
if [[ "${1:-}" == "--consumer" ]]; then
  shift
  exec python3 "$DOTFILES_DIR/scripts/consumer-setup.py" "$@"
fi
# The public app path builds only the native wrapper; personal setup remains explicit.
if [[ "${1:-}" == "--app" ]]; then
  shift
  exec python3 "$DOTFILES_DIR/scripts/build-app.py" "$@"
fi
BREWFILE="$DOTFILES_DIR/Brewfile"
export DOTFILES_DIR

activate_homebrew_path() {
  local brew_prefix

  command -v brew >/dev/null 2>&1 || return 0
  brew_prefix=$(brew --prefix 2>/dev/null) || return 0
  [[ -d "$brew_prefix/bin" ]] || return 0
  export PATH="$brew_prefix/bin:$PATH"
  hash -r
}

start_desktop_service() {
  local service="$1"

  command -v "$service" >/dev/null 2>&1 || return 0
  echo "Starting $service launch service..."
  if ! "$service" --start-service; then
    echo "warning: could not start $service automatically; retry after granting macOS permissions." >&2
  fi
}

warm_dotfiles_manager_ui() {
  local manager_ui="$HOME/bin/dotfiles-manager-ui"

  command -v uv >/dev/null 2>&1 || return 0
  [[ -x "$manager_ui" ]] || return 0
  echo "Preparing the dotfiles control panel..."
  "$manager_ui" --self-test >/dev/null
}

install_browser_use_cli() {
  local browser_use_bin

  echo "Installing Browser Use CLI for coding agents..."
  uv tool install --python 3.12 'browser-use==0.13.10'
  browser_use_bin="$(uv tool dir --bin)/browser-use"
  "$browser_use_bin" skill install --target agents --no-install
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

activate_homebrew_path

if [ -f "$BREWFILE" ]; then
  echo "Installing dependencies from Brewfile..."
  # Current Homebrew requires individual grants for third-party formulae.
  # Older versions have no trust command and retain their existing behavior.
  if brew help trust >/dev/null 2>&1; then
    brew tap asmvik/formulae
    brew tap FelixKratz/formulae
    brew trust --formula asmvik/formulae/yabai asmvik/formulae/skhd felixkratz/formulae/borders
  fi
  brew bundle --file "$BREWFILE"
  activate_homebrew_path
else
  echo "Brewfile not found at $BREWFILE" >&2
  exit 1
fi

echo "Applying chezmoi source state..."
"$DOTFILES_DIR/install.sh"

if [[ "${DOTFILES_CONSUMER_PROFILE:-0}" != "1" ]]; then
  install_browser_use_cli
fi
warm_dotfiles_manager_ui

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
echo "  6. Build the optional native utility app: make build-app"
