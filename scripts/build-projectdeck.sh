#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/scripts/projectdeck/ProjectDeck.swift"
OUT="$ROOT/scripts/projectdeck/executable_projectdeck"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "projectdeck: skip (macOS only)" >&2
  exit 0
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
