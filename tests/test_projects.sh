#!/usr/bin/env bash

set -euo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECTS_BIN="$TEST_DIR/../home/dot_config/yabai/executable_projects"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/projects-test.XXXXXX")"
export PROJECTS_FILE="$TEMP_DIR/projects.json"
export PROJECTS_NOTIFY=0
export PROJECTS_CONFIRM=0

PASSED=0
FAILED=0

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

assert_eq() {
  local expected="$1"
  local actual="$2"
  local name="$3"

  if [[ "$expected" == "$actual" ]]; then
    echo "  ✓ $name"
    ((PASSED++))
  else
    echo "  ✗ $name"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    ((FAILED++))
  fi
}

echo "Testing projects CLI (store only)..."

if "$PROJECTS_BIN" create acme --name "Acme"; then
  echo "  ✓ create exits successfully"
  ((PASSED++))
else
  echo "  ✗ create exits successfully"
  ((FAILED++))
fi

last=$("$PROJECTS_BIN" list --json | jq -r '.last_project // empty')
assert_eq "acme" "$last" "create sets last_project"

count=$("$PROJECTS_BIN" list --json | jq '.projects | length')
assert_eq "1" "$count" "list shows one project"

"$PROJECTS_BIN" delete acme

if "$PROJECTS_BIN" create myapp --name "My App" --slot 2; then
  echo "  ✓ create --slot exits successfully"
  ((PASSED++))
else
  echo "  ✗ create --slot exits successfully"
  ((FAILED++))
fi

slot=$("$PROJECTS_BIN" list --json | jq -r '.project_slots["2"] // empty')
assert_eq "myapp" "$slot" "create --slot assigns Hyper shortcut"

"$PROJECTS_BIN" delete myapp

jq --arg id "acme" '
  .projects[$id].spaces = ["uuid-a", "uuid-b"]
  | .projects[$id].space_slots = {"1": "uuid-a"}
' "$PROJECTS_FILE" >"$PROJECTS_FILE.tmp" && mv "$PROJECTS_FILE.tmp" "$PROJECTS_FILE"

slot=$(jq -r '
  (.projects.acme.space_slots // {}) as $slots
  | [range(1; 10) | tostring]
  | map(select(($slots[.] // "") == ""))
  | .[0] // empty
' "$PROJECTS_FILE")
assert_eq "2" "$slot" "next free space slot is 2"

"$PROJECTS_BIN" delete acme
count=$("$PROJECTS_BIN" list --json | jq '.projects | length')
assert_eq "0" "$count" "delete removes project"

"$PROJECTS_BIN" create demo --name "Demo" --slot 1
jq --arg id "demo" '
  .projects[$id].spaces = ["uuid-a"]
  | .projects[$id].space_slots = {"1": "uuid-a", "2": "uuid-b"}
' "$PROJECTS_FILE" >"$PROJECTS_FILE.tmp" && mv "$PROJECTS_FILE.tmp" "$PROJECTS_FILE"

menu=$("$PROJECTS_BIN" menu-json --menu spaces:demo)
detach_count=$(printf '%s' "$menu" | jq '[.items[] | select(.line | startswith("DETACH:"))] | length')
delete_count=$(printf '%s' "$menu" | jq '[.items[] | select(.line | startswith("DELETE:"))] | length')
assert_eq "2" "$detach_count" "spaces menu includes detach rows"
assert_eq "1" "$delete_count" "spaces menu includes delete row"

echo ""
echo "================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "================================"

exit "$FAILED"
