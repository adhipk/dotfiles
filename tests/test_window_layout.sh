#!/usr/bin/env bash
exec "$(cd "$(dirname "$0")/.." && pwd)/modules/window-layout/tests/test_module.sh" "$@"
