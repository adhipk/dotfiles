#!/usr/bin/env bash
exec "$(cd "$(dirname "$0")/.." && pwd)/modules/gh-create-repo/tests/test_module.sh" "$@"
