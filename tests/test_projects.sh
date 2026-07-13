#!/usr/bin/env bash
# Optional parent entrypoint for the module-owned Projects tests.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODULE="$ROOT/modules/projects"
if [[ ! -d "$MODULE" ]]; then
  echo "Projects module absent; parent tests remain valid."
  exit 0
fi

"$MODULE/tests/test_projects.sh"
"$MODULE/tests/test_module.sh"
