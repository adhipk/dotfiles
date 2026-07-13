#!/usr/bin/env bash

# Contract tests for module lifecycle inventory, planning, and execution.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$TEST_DIR")"
REPO_ROOT="$(cd "$MODULE_DIR/../.." && pwd)"
LIFECYCLE="$MODULE_DIR/bin/dotfiles-module"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-module-lifecycle.XXXXXX")"
FIXTURE_REPO="$TEMP_DIR/repo"
INVALID_REPO="$TEMP_DIR/invalid-repo"
ESCAPE_REPO="$TEMP_DIR/escape-repo"
TEST_HOME="$TEMP_DIR/home"
STATE_ROOT="$TEMP_DIR/state-root"
MOCK_BIN="$TEMP_DIR/mock-bin"
CHEZMOI_LOG="$TEMP_DIR/chezmoi.log"
CHEZMOI_FAIL_MARKER="$TEMP_DIR/chezmoi.fail-once"
STDOUT_FILE="$TEMP_DIR/stdout"
STDERR_FILE="$TEMP_DIR/stderr"

PASSED=0
FAILED=0
LAST_STATUS=0
LAST_STDOUT=""
LAST_STDERR=""

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

pass() {
  printf '  ✓ %s\n' "$1"
  PASSED=$((PASSED + 1))
}

fail() {
  local name="$1"
  local expected="${2:-}"
  local actual="${3:-}"

  printf '  ✗ %s\n' "$name"
  [[ -z "$expected" ]] || printf '    Expected: %s\n' "$expected"
  [[ -z "$actual" ]] || printf '    Actual:   %s\n' "$actual"
  FAILED=$((FAILED + 1))
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local name="$3"

  if [[ "$actual" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name" "$expected" "$actual"
  fi
}

assert_contains() {
  local value="$1"
  local expected="$2"
  local name="$3"

  if grep -Fqi -- "$expected" <<<"$value"; then
    pass "$name"
  else
    fail "$name" "text containing '$expected'" "$value"
  fi
}

assert_success() {
  local name="$1"

  if [[ "$LAST_STATUS" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "exit status 0" "exit status $LAST_STATUS; stderr: $LAST_STDERR"
  fi
}

assert_failure() {
  local name="$1"

  if [[ "$LAST_STATUS" -ne 0 ]]; then
    pass "$name"
  else
    fail "$name" "non-zero exit status" "exit status 0"
  fi
}

assert_file_exists() {
  local path="$1" name="$2"
  if [[ -e "$path" || -L "$path" ]]; then pass "$name"; else fail "$name" "$path to exist" "missing"; fi
}

assert_file_absent() {
  local path="$1" name="$2"
  if [[ ! -e "$path" && ! -L "$path" ]]; then pass "$name"; else fail "$name" "$path to be absent" "present"; fi
}

run_lifecycle() {
  local repo="$1"
  shift

  : >"$STDOUT_FILE"
  : >"$STDERR_FILE"
  LAST_STATUS=0
  DOTFILES_DIR="$repo" "$LIFECYCLE" "$@" >"$STDOUT_FILE" 2>"$STDERR_FILE" || LAST_STATUS=$?
  LAST_STDOUT="$(cat "$STDOUT_FILE")"
  LAST_STDERR="$(cat "$STDERR_FILE")"
}

run_execution() {
  local repo="$1"
  shift

  : >"$STDOUT_FILE"
  : >"$STDERR_FILE"
  LAST_STATUS=0
  HOME="$TEST_HOME" \
    PATH="$MOCK_BIN:$PATH" \
    CHEZMOI_LOG="$CHEZMOI_LOG" \
    CHEZMOI_FAIL_MARKER="$CHEZMOI_FAIL_MARKER" \
    DOTFILES_DIR="$repo" \
    "$LIFECYCLE" "$@" >"$STDOUT_FILE" 2>"$STDERR_FILE" || LAST_STATUS=$?
  LAST_STDOUT="$(cat "$STDOUT_FILE")"
  LAST_STDERR="$(cat "$STDERR_FILE")"
}

set_alpha_enabled() {
  yq -i ".modules.alpha.enabled = $1" "$FIXTURE_REPO/home/.chezmoidata/10-modules.yaml"
}

make_fixture() {
  mkdir -p \
    "$FIXTURE_REPO/home/.chezmoidata" \
    "$FIXTURE_REPO/home/bin" \
    "$FIXTURE_REPO/home/dot_config/example" \
    "$FIXTURE_REPO/home/dot_local/lib/dotfiles" \
    "$FIXTURE_REPO/modules/alpha/bin" \
    "$FIXTURE_REPO/modules/alpha/targets" \
    "$FIXTURE_REPO/modules/beta/bin"

  cat >"$FIXTURE_REPO/home/.chezmoidata/10-modules.yaml" <<'EOF'
dotfiles:
  profile: test
  moduleApiVersion: 1
modules:
  alpha:
    enabled: true
  beta:
    enabled: false
EOF

  cat >"$FIXTURE_REPO/modules/alpha/module.yaml" <<'EOF'
apiVersion: dotfiles/v1
kind: Module
id: alpha
version: 1.0.0
description: Alpha fixture module
dataKey: modules.alpha
distribution:
  standalone: true
state:
  preserved:
    - ~/.local/state/alpha
    - ./alpha-data
  ephemeral:
    - ~/.cache/alpha
    - tmux-wait-channel:alpha-*
commands:
  - name: alpha
    source: bin/alpha
    target: ~/bin/alpha
targets:
  - source: bin/alpha
    destination: ~/bin/alpha
    bridge: home/bin/executable_alpha.tmpl
    ownership: exclusive
  - source: targets/example.conf.tmpl
    destination: ~/.config/example/config
    bridge: home/dot_config/example/config.tmpl
    ownership: contribution
tests: []
EOF

  cat >"$FIXTURE_REPO/modules/beta/module.yaml" <<'EOF'
apiVersion: dotfiles/v1
kind: Module
id: beta
version: 1.0.0
description: Beta fixture module
dataKey: modules.beta
distribution:
  standalone: true
state:
  preserved: []
  ephemeral: []
commands:
  - name: beta
    source: bin/beta
    target: ~/bin/beta
targets:
  - source: bin/beta
    destination: ~/bin/beta
    bridge: home/bin/executable_beta.tmpl
    ownership: exclusive
tests: []
EOF

  : >"$FIXTURE_REPO/modules/alpha/bin/alpha"
  : >"$FIXTURE_REPO/modules/alpha/targets/example.conf.tmpl"
  : >"$FIXTURE_REPO/modules/beta/bin/beta"
  : >"$FIXTURE_REPO/home/bin/executable_alpha.tmpl"
  : >"$FIXTURE_REPO/home/bin/executable_beta.tmpl"
  : >"$FIXTURE_REPO/home/dot_config/example/config.tmpl"
  cp "$REPO_ROOT/home/dot_local/lib/dotfiles/core.sh" "$FIXTURE_REPO/home/dot_local/lib/dotfiles/core.sh"
  cp "$REPO_ROOT/home/dot_local/lib/dotfiles/locks.sh" "$FIXTURE_REPO/home/dot_local/lib/dotfiles/locks.sh"
}

make_mock_chezmoi() {
  mkdir -p "$MOCK_BIN" "$TEST_HOME" "$STATE_ROOT"
  cat >"$MOCK_BIN/chezmoi" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CHEZMOI_LOG"
if [[ "${CHEZMOI_FAIL_FIRST:-0}" == "1" && ! -e "$CHEZMOI_FAIL_MARKER" ]]; then
  : >"$CHEZMOI_FAIL_MARKER"
  exit 42
fi
exit 0
EOF
  chmod +x "$MOCK_BIN/chezmoi"
}

printf '================================\n'
printf 'Module Lifecycle Contract Tests\n'
printf '================================\n'

if [[ -x "$LIFECYCLE" ]]; then
  pass "lifecycle command is executable"
else
  fail "lifecycle command is executable" "$LIFECYCLE" "missing or not executable"
fi

make_fixture
make_mock_chezmoi

run_lifecycle "$FIXTURE_REPO" validate --json
assert_success "validate --json accepts an isolated module repository"
if jq -e '.valid == true and .apiVersion == "dotfiles/v1" and .moduleCount == 2' >/dev/null 2>&1 <<<"$LAST_STDOUT"; then
  pass "validate --json exposes a stable automation contract"
else
  fail "validate --json exposes a stable automation contract" '{valid:true,apiVersion:"dotfiles/v1",moduleCount:2}' "$LAST_STDOUT"
fi

printf '\nTesting repository discovery and status...\n'
run_lifecycle "$FIXTURE_REPO" status
assert_success "status accepts an isolated DOTFILES_DIR repository"
assert_contains "$LAST_STDOUT" "MODULE" "human status includes the module heading"
assert_contains "$LAST_STDOUT" "ENABLED" "human status includes the enabled heading"
assert_contains "$LAST_STDOUT" "DESCRIPTION" "human status includes the description heading"
assert_contains "$LAST_STDOUT" "alpha" "human status lists enabled modules"
assert_contains "$LAST_STDOUT" "true" "human status reports enabled state"
assert_contains "$LAST_STDOUT" "Alpha fixture module" "human status reports module descriptions"
assert_contains "$LAST_STDOUT" "beta" "human status lists disabled modules"
assert_contains "$LAST_STDOUT" "false" "human status reports disabled state"

run_lifecycle "$FIXTURE_REPO" status --json
assert_success "status --json succeeds for a valid repository"
if jq -e '
  type == "array" and
  length == 2 and
  any(.[]; .id == "alpha" and .enabled == true and .description == "Alpha fixture module") and
  any(.[]; .id == "beta" and .enabled == false and .description == "Beta fixture module")
' >/dev/null 2>&1 <<<"$LAST_STDOUT"; then
  pass "status --json exposes the stable module inventory schema"
else
  fail \
    "status --json exposes the stable module inventory schema" \
    "an array of {id, enabled, description} objects" \
    "$LAST_STDOUT"
fi

run_lifecycle "$REPO_ROOT" status --json
assert_success "status --json validates the checked-in repository"
if jq -e 'length >= 3 and all(.[]; (.id | type == "string") and (.enabled | type == "boolean") and (.description | type == "string"))' \
  >/dev/null 2>&1 <<<"$LAST_STDOUT"; then
  pass "checked-in modules expose the same JSON status contract"
else
  fail "checked-in modules expose the same JSON status contract" "three or more valid module status objects" "$LAST_STDOUT"
fi

printf '\nTesting read-only lifecycle plans...\n'
run_lifecycle "$FIXTURE_REPO" plan enable alpha
assert_success "plan enable succeeds for a known module"
assert_contains "$LAST_STDOUT" "Plan: enable module alpha" "plan enable names its exact scope"
assert_contains "$LAST_STDOUT" "modules.alpha" "plan enable reports the full dataKey"
assert_contains "$LAST_STDOUT" "exclusive" "plan enable distinguishes exclusive targets"
assert_contains "$LAST_STDOUT" "shared contributions" "plan enable distinguishes shared-file contributions"

for action in disable uninstall purge; do
  run_lifecycle "$FIXTURE_REPO" plan "$action" alpha
  assert_success "plan $action succeeds for a known module"
  assert_contains "$LAST_STDOUT" "Plan: $action module alpha" "plan $action names its exact scope"
  assert_contains "$LAST_STDOUT" "modules.alpha" "plan $action reports the full dataKey"
  assert_contains "$LAST_STDOUT" "exclusive" "plan $action distinguishes exclusive targets"
  assert_contains "$LAST_STDOUT" "contribution" "plan $action distinguishes shared-file contributions"
  assert_contains "$LAST_STDOUT" "~/.local/state/alpha" "plan $action accounts for preserved state"
done

for action in enable disable uninstall purge; do
  run_lifecycle "$FIXTURE_REPO" plan "$action" alpha --json
  assert_success "plan $action --json succeeds"
  if jq -e --arg operation "module-$action" --arg action "$action" '
    .schemaVersion == 1 and
    .operation == $operation and
    .module.id == "alpha" and
    (.module.enabled | type == "boolean") and
    .module.targetEnabled == ($action == "enable") and
    .module.dataKey == "modules.alpha" and
    .exclusiveTargets == ["~/bin/alpha"] and
    .contributionTargets == ["~/.config/example/config"] and
    (.preservedState | index("~/.local/state/alpha")) != null and
    (.ephemeralState | index("~/.cache/alpha")) != null and
    .stateRootRequired == ($action == "purge") and
    .confirmation == (if $action == "purge" then "alpha" else null end) and
    .sourcePreserved == true and
    .executable == true and
    .blockers == []
  ' >/dev/null 2>&1 <<<"$LAST_STDOUT"; then
    pass "plan $action --json exposes the stable schema-v1 contract"
  else
    fail "plan $action --json exposes the stable schema-v1 contract" "schema-v1 $action plan" "$LAST_STDOUT"
  fi
done

run_lifecycle "$FIXTURE_REPO" plan system-uninstall
assert_success "system-uninstall planning succeeds"
assert_contains "$LAST_STDOUT" "complete dotfiles target state" "system plan declares its complete target scope"
assert_contains "$LAST_STDOUT" "source" "system plan mentions checked-in source"
assert_contains "$LAST_STDOUT" "preserv" "system plan explicitly preserves source"
assert_contains "$LAST_STDOUT" "never use chezmoi destroy" "system plan warns against destructive source removal"

printf '\nTesting fail-closed validation...\n'
run_lifecycle "$FIXTURE_REPO" plan disable missing-module
assert_failure "an unknown module is rejected"
assert_contains "$LAST_STDERR" "unknown module" "unknown-module failure is actionable"

run_lifecycle "$FIXTURE_REPO" plan disable ../alpha
assert_failure "module ids reject path traversal"
assert_contains "$LAST_STDERR" "invalid module id" "path-traversal failure is actionable"

run_lifecycle "$REPO_ROOT" plan disable module-lifecycle
assert_failure "the lifecycle controller cannot plan its own module removal"
assert_contains "$LAST_STDERR" "removed last" "self-removal directs callers to system uninstall"

cp -R "$FIXTURE_REPO" "$INVALID_REPO"
mkdir -p "$INVALID_REPO/modules/broken/bin"
cat >"$INVALID_REPO/modules/broken/module.yaml" <<'EOF'
apiVersion: dotfiles/v1
kind: Module
id: broken
version: 1.0.0
description: Invalid ownership fixture
dataKey: modules.beta
state:
  preserved: []
  ephemeral: []
targets:
  - source: bin/broken
    destination: ~/bin/broken
    bridge: home/bin/executable_broken.tmpl
    ownership: shared
EOF
: >"$INVALID_REPO/modules/broken/bin/broken"

run_lifecycle "$INVALID_REPO" status --json
assert_failure "status fails closed on unknown target ownership"
assert_eq "" "$LAST_STDOUT" "invalid manifests produce no partial status inventory"
assert_contains "$LAST_STDERR" "ownership" "invalid ownership failure identifies the unsafe field"
assert_contains "$LAST_STDERR" "exclusive" "invalid ownership failure names an accepted value"
assert_contains "$LAST_STDERR" "contribution" "invalid ownership failure names every accepted value"

run_lifecycle "$INVALID_REPO" plan uninstall broken
assert_failure "planning fails closed on unknown target ownership"
assert_eq "" "$LAST_STDOUT" "invalid manifests produce no partial lifecycle plan"

printf '\nTesting executable lifecycle operations...\n'
mkdir -p "$TEST_HOME/.local/state/alpha" "$TEST_HOME/.cache/alpha"
: >"$TEST_HOME/.local/state/alpha/preserved"
: >"$TEST_HOME/.cache/alpha/ephemeral"
: >"$CHEZMOI_LOG"
run_execution "$FIXTURE_REPO" disable alpha
assert_success "disable succeeds in a disposable repository and HOME"
assert_eq "false" "$(yq -r '.modules.alpha.enabled' "$FIXTURE_REPO/home/.chezmoidata/10-modules.yaml")" "disable atomically changes the module flag"
assert_eq "1" "$(wc -l <"$CHEZMOI_LOG" | tr -d ' ')" "disable invokes chezmoi exactly once"
assert_contains "$(cat "$CHEZMOI_LOG")" "-S $FIXTURE_REPO apply --force --source-path" "disable uses targeted chezmoi source-path apply"
assert_contains "$(cat "$CHEZMOI_LOG")" "home/bin/executable_alpha.tmpl" "disable applies the exclusive bridge"
assert_contains "$(cat "$CHEZMOI_LOG")" "home/dot_config/example/config.tmpl" "disable applies the contribution bridge"
assert_file_exists "$TEST_HOME/.local/state/alpha/preserved" "disable preserves declared persistent state"
assert_file_exists "$TEST_HOME/.cache/alpha/ephemeral" "disable preserves declared ephemeral state"
assert_file_exists "$FIXTURE_REPO/modules/alpha/module.yaml" "disable preserves module source"
assert_file_absent "$FIXTURE_REPO/.dotfiles-module.lock" "disable releases the repository lock"
if ! find "$FIXTURE_REPO/home/.chezmoidata" -name '10-modules.yaml.*.??????' -print -quit | grep -q .; then
  pass "successful execution leaves no transaction files"
else
  fail "successful execution leaves no transaction files" "no backup or temp files" "transaction file remains"
fi

printf '\nTesting enable and JSON action results...\n'
: >"$CHEZMOI_LOG"
run_execution "$FIXTURE_REPO" enable alpha --json
assert_success "enable --json succeeds in a disposable repository and HOME"
assert_eq "true" "$(yq -r '.modules.alpha.enabled' "$FIXTURE_REPO/home/.chezmoidata/10-modules.yaml")" "enable atomically changes the module flag"
assert_eq "1" "$(wc -l <"$CHEZMOI_LOG" | tr -d ' ')" "enable invokes chezmoi exactly once"
if jq -e '
  .schemaVersion == 1 and
  .operation == "module-enable" and
  .status == "complete" and
  .module == {id:"alpha",dataKey:"modules.alpha",enabled:true,previouslyEnabled:false} and
  .changed == true and
  .sourcePreserved == true
' >/dev/null 2>&1 <<<"$LAST_STDOUT"; then
  pass "enable --json exposes the stable schema-v1 result"
else
  fail "enable --json exposes the stable schema-v1 result" "schema-v1 enable result" "$LAST_STDOUT"
fi
assert_file_exists "$TEST_HOME/.local/state/alpha/preserved" "enable preserves declared persistent state"
assert_file_exists "$TEST_HOME/.cache/alpha/ephemeral" "enable preserves declared ephemeral state"

: >"$CHEZMOI_LOG"
run_execution "$FIXTURE_REPO" disable alpha --json
assert_success "disable --json succeeds"
if jq -e '
  .schemaVersion == 1 and
  .operation == "module-disable" and
  .status == "complete" and
  .module.enabled == false and
  .module.previouslyEnabled == true and
  .changed == true and
  .sourcePreserved == true
' >/dev/null 2>&1 <<<"$LAST_STDOUT"; then
  pass "disable --json exposes the stable schema-v1 result"
else
  fail "disable --json exposes the stable schema-v1 result" "schema-v1 disable result" "$LAST_STDOUT"
fi

printf '\nTesting enable apply rollback...\n'
set_alpha_enabled false
: >"$CHEZMOI_LOG"
rm -f "$CHEZMOI_FAIL_MARKER"
CHEZMOI_FAIL_FIRST=1 run_execution "$FIXTURE_REPO" enable alpha --json
assert_failure "a failed enable apply fails the operation"
assert_contains "$LAST_STDERR" "rolled back" "enable apply failure reports successful rollback"
assert_eq "" "$LAST_STDOUT" "failed JSON enable emits no partial result"
assert_eq "false" "$(yq -r '.modules.alpha.enabled' "$FIXTURE_REPO/home/.chezmoidata/10-modules.yaml")" "failed enable restores the disabled config backup"
assert_eq "2" "$(wc -l <"$CHEZMOI_LOG" | tr -d ' ')" "failed enable re-applies the restored target state"
assert_file_absent "$FIXTURE_REPO/.dotfiles-module.lock" "failed enable releases the repository lock"

printf '\nTesting apply rollback...\n'
set_alpha_enabled true
: >"$CHEZMOI_LOG"
rm -f "$CHEZMOI_FAIL_MARKER"
CHEZMOI_FAIL_FIRST=1 run_execution "$FIXTURE_REPO" disable alpha
assert_failure "a failed chezmoi apply fails the operation"
assert_contains "$LAST_STDERR" "rolled back" "apply failure reports successful rollback"
assert_eq "true" "$(yq -r '.modules.alpha.enabled' "$FIXTURE_REPO/home/.chezmoidata/10-modules.yaml")" "apply failure restores the config backup"
assert_eq "2" "$(wc -l <"$CHEZMOI_LOG" | tr -d ' ')" "apply failure re-applies the restored target state"
assert_file_absent "$FIXTURE_REPO/.dotfiles-module.lock" "rollback releases the repository lock"

printf '\nTesting uninstall state boundaries...\n'
set_alpha_enabled true
mkdir -p "$TEST_HOME/.cache/alpha"
: >"$TEST_HOME/.cache/alpha/ephemeral"
: >"$CHEZMOI_LOG"
run_execution "$FIXTURE_REPO" uninstall alpha --json
assert_success "uninstall succeeds without deleting source"
if jq -e '.schemaVersion == 1 and .operation == "module-uninstall" and .status == "complete" and .module.enabled == false and .sourcePreserved == true' \
  >/dev/null 2>&1 <<<"$LAST_STDOUT"; then
  pass "uninstall --json exposes the stable schema-v1 result without mixed stdout"
else
  fail "uninstall --json exposes the stable schema-v1 result without mixed stdout" "schema-v1 uninstall result" "$LAST_STDOUT"
fi
assert_file_absent "$TEST_HOME/.cache/alpha" "uninstall removes declared ephemeral filesystem state"
assert_file_exists "$TEST_HOME/.local/state/alpha/preserved" "uninstall preserves declared persistent state"
assert_file_exists "$FIXTURE_REPO/modules/alpha/module.yaml" "uninstall preserves module source"
assert_contains "$LAST_STDERR" "Retained non-filesystem state" "uninstall explicitly reports retained runtime handles"

printf '\nTesting confirmed purge and relative state roots...\n'
set_alpha_enabled true
mkdir -p "$STATE_ROOT/alpha-data"
: >"$STATE_ROOT/alpha-data/preserved"
: >"$CHEZMOI_LOG"
run_execution "$FIXTURE_REPO" purge alpha --confirm beta --state-root "$STATE_ROOT"
assert_failure "purge rejects a non-exact confirmation"
assert_contains "$LAST_STDERR" "--confirm alpha" "purge failure shows the exact required confirmation"
assert_eq "true" "$(yq -r '.modules.alpha.enabled' "$FIXTURE_REPO/home/.chezmoidata/10-modules.yaml")" "confirmation failure does not mutate config"
assert_eq "0" "$(wc -l <"$CHEZMOI_LOG" | tr -d ' ')" "confirmation failure does not call chezmoi"
assert_file_exists "$STATE_ROOT/alpha-data/preserved" "confirmation failure preserves state"

: >"$CHEZMOI_LOG"
run_execution "$FIXTURE_REPO" purge alpha --confirm alpha
assert_failure "purge requires an explicit root for relative state"
assert_contains "$LAST_STDERR" "--state-root" "relative-state failure is actionable"
assert_eq "true" "$(yq -r '.modules.alpha.enabled' "$FIXTURE_REPO/home/.chezmoidata/10-modules.yaml")" "missing state root fails before config mutation"
assert_eq "0" "$(wc -l <"$CHEZMOI_LOG" | tr -d ' ')" "missing state root fails before chezmoi apply"

: >"$CHEZMOI_LOG"
run_execution "$FIXTURE_REPO" purge alpha --confirm alpha --state-root "$STATE_ROOT" --json
assert_success "purge succeeds after exact confirmation and explicit state root"
if jq -e '.schemaVersion == 1 and .operation == "module-purge" and .status == "complete" and .module.enabled == false and .sourcePreserved == true' \
  >/dev/null 2>&1 <<<"$LAST_STDOUT"; then
  pass "purge --json exposes the stable schema-v1 result without mixed stdout"
else
  fail "purge --json exposes the stable schema-v1 result without mixed stdout" "schema-v1 purge result" "$LAST_STDOUT"
fi
assert_file_absent "$TEST_HOME/.local/state/alpha" "purge removes declared HOME persistent state"
assert_file_absent "$STATE_ROOT/alpha-data" "purge removes declared relative persistent state from the explicit root"
assert_file_exists "$FIXTURE_REPO/modules/alpha/module.yaml" "purge preserves module source"

printf '\nTesting destructive path refusal...\n'
set_alpha_enabled true
mkdir -p "$TEMP_DIR/outside/state/alpha"
: >"$TEMP_DIR/outside/state/alpha/keep"
rm -rf "$TEST_HOME/.local"
ln -s "$TEMP_DIR/outside" "$TEST_HOME/.local"
: >"$CHEZMOI_LOG"
run_execution "$FIXTURE_REPO" purge alpha --confirm alpha --state-root "$STATE_ROOT"
assert_failure "purge refuses state paths whose parent traverses a symlink"
assert_contains "$LAST_STDERR" "through symlink" "symlink refusal identifies the unsafe path"
assert_eq "true" "$(yq -r '.modules.alpha.enabled' "$FIXTURE_REPO/home/.chezmoidata/10-modules.yaml")" "symlink refusal happens before config mutation"
assert_eq "0" "$(wc -l <"$CHEZMOI_LOG" | tr -d ' ')" "symlink refusal happens before chezmoi apply"
assert_file_exists "$TEMP_DIR/outside/state/alpha/keep" "symlink refusal preserves outside data"

cp -R "$FIXTURE_REPO" "$ESCAPE_REPO"
yq -i '.state.preserved = ["~/../outside"]' "$ESCAPE_REPO/modules/alpha/module.yaml"
: >"$CHEZMOI_LOG"
run_execution "$ESCAPE_REPO" purge alpha --confirm alpha --state-root "$STATE_ROOT"
assert_failure "purge rejects a manifest path that escapes HOME"
assert_contains "$LAST_STDERR" "unsafe state path" "HOME-containment failure identifies the manifest entry"
assert_eq "0" "$(wc -l <"$CHEZMOI_LOG" | tr -d ' ')" "HOME-containment failure does not call chezmoi"

printf '\n================================\n'
printf 'Results: %d passed, %d failed\n' "$PASSED" "$FAILED"
printf '================================\n'

[[ "$FAILED" -eq 0 ]]
