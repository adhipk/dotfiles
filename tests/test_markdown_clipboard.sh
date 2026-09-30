#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
exec bash "$root/modules/markdown-clipboard/tests/test_service.sh"
