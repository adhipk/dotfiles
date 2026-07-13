#!/usr/bin/env bash
exec "$(cd "$(dirname "$0")/.." && pwd)/modules/unescape-cli/tests/test_module.sh" "$@"
