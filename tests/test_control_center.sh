#!/usr/bin/env bash
exec "$(cd "$(dirname "$0")/.." && pwd)/modules/dotfiles-control-center/Tests/test_module.sh" "$@"
