#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$MODULE_DIR/app/WhichKey.swift"
TEMP_BUILD_DIR=""

cleanup() {
  if [[ -n "$TEMP_BUILD_DIR" ]]; then
    rm -rf "$TEMP_BUILD_DIR"
  fi
}
trap cleanup EXIT

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "whichkey: skip (macOS only)" >&2
  exit 0
fi

if ! command -v swiftc >/dev/null 2>&1; then
  echo "whichkey: swiftc is required; install the Xcode Command Line Tools with: xcode-select --install" >&2
  exit 1
fi

if [[ -n "${WHICHKEY_BUILD_PATH:-}" ]]; then
  OUT="$WHICHKEY_BUILD_PATH"
else
  TEMP_BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/whichkey-build.XXXXXX")"
  OUT="$TEMP_BUILD_DIR/whichkey"
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
