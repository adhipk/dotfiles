#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/scripts/whichkey/WhichKey.swift"
OUT="${WHICHKEY_BUILD_PATH:-$ROOT/scripts/whichkey/executable_whichkey}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "whichkey: skip (macOS only)" >&2
  exit 0
fi

if ! command -v swiftc >/dev/null 2>&1; then
  echo "whichkey: swiftc is required; install the Xcode Command Line Tools with: xcode-select --install" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")"
swiftc -parse-as-library -O \
  -framework SwiftUI \
  -framework AppKit \
  "$SRC" \
  -o "$OUT"

chmod +x "$OUT"
echo "Built $OUT"

target="${WHICHKEY_INSTALL_PATH:-$HOME/.config/skhd/whichkey}"
mkdir -p "$(dirname "$target")"
install -m 755 "$OUT" "$target"
echo "Installed $target"
