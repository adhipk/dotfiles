#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
"$TEST_DIR/../modules/agent-timer/tests/test_agent_timer.sh"
"$TEST_DIR/../modules/agent-timer/tests/test_safety_contracts.sh"
