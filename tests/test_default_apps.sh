#!/usr/bin/env bash
exec "$(cd "$(dirname "$0")/.." && pwd)/modules/macos-default-apps/tests/test_module.sh" "$@"
