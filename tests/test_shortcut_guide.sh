#!/usr/bin/env bash
exec "$(cd "$(dirname "$0")/.." && pwd)/modules/shortcut-guide/tests/test_module.sh" "$@"
