#!/usr/bin/env bash
exec "$(cd "$(dirname "$0")/.." && pwd)/modules/settings/tests/test_module.sh" "$@"
