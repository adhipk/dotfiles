#!/usr/bin/env bash
exec "$(cd "$(dirname "$0")/.." && pwd)/modules/kit-tts/tests/test_module.sh" "$@"
