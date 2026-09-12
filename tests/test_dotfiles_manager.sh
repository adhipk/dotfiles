#!/usr/bin/env bash
exec "$(cd "$(dirname "$0")/.." && pwd)/modules/dotfiles-manager/tests/test_module.sh" "$@"
