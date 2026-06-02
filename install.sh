#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

if ! command -v chezmoi >/dev/null 2>&1; then
    echo "chezmoi is not installed. Run ./bootstrap.sh or brew install chezmoi." >&2
    exit 1
fi

exec chezmoi -S "$DOTFILES_DIR" apply "$@"
