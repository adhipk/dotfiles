#!/usr/bin/env bash
exec "$(cd "$(dirname "$0")/.." && pwd)/modules/hermes-agent/tests/test_module.sh" "$@"
