#!/usr/bin/env bash
exec "$(cd "$(dirname "$0")/.." && pwd)/modules/space-display/tests/test_module.sh" "$@"
