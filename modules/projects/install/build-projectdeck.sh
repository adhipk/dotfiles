#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$MODULE_DIR/projectdeck/ProjectDeck.swift"
OUT="${PROJECTDECK_BUILD_PATH:-$MODULE_DIR/projectdeck/executable_projectdeck}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "projectdeck: skip (macOS only)" >&2
  exit 0
fi

if ! command -v swiftc >/dev/null 2>&1; then
  echo "projectdeck: swiftc is required; install the Xcode Command Line Tools with: xcode-select --install" >&2
  exit 1
fi

swiftc -parse-as-library -O \
  -framework SwiftUI \
  -framework AppKit \
  "$SRC" \
  -o "$OUT"

chmod +x "$OUT"
echo "Built $OUT"

target="${PROJECTDECK_INSTALL_PATH:-$HOME/.config/yabai/projectdeck}"
if [[ -d "$target" ]]; then
  rm -rf "$target"
fi
mkdir -p "$(dirname "$target")"
install -m 755 "$OUT" "$target"
echo "Installed $target"
