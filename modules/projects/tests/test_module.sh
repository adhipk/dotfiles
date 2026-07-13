#!/usr/bin/env bash
set -u

MODULE="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$MODULE/../.." && pwd)"
TEMP="$(mktemp -d "${TMPDIR:-/tmp}/projects-module-test.XXXXXX")"
PASSED=0
FAILED=0
trap 'rm -rf "$TEMP"' EXIT

pass() { printf '  ok - %s\n' "$1"; PASSED=$((PASSED + 1)); }
fail() { printf '  not ok - %s: %s\n' "$1" "$2"; FAILED=$((FAILED + 1)); }
assert_contains() { [[ "$1" == *"$2"* ]] && pass "$3" || fail "$3" "missing [$2]"; }

printf 'Testing Projects module boundary...\n'
[[ "$(yq -r '.modules.projects.enabled' "$ROOT/home/.chezmoidata/10-modules.yaml")" == false ]] \
  && pass "Projects is explicitly disabled" || fail "Projects is explicitly disabled" "data flag is not false"
[[ "$(yq -r '.id' "$MODULE/module.yaml")" == projects ]] \
  && pass "manifest id matches its folder" || fail "manifest id matches its folder" "manifest mismatch"
[[ "$(yq -r '.state.preserved[0]' "$MODULE/module.yaml")" == '~/.config/yabai/projects.json' ]] \
  && pass "mutable project data is declared preserved" || fail "mutable project data is declared preserved" "state mismatch"

disabled=$(chezmoi -S "$ROOT" cat "$HOME/bin/projects")
[[ -z "$disabled" ]] && pass "disabled profile renders no global projects command" || fail "disabled profile renders no global projects command" "$disabled"
enabled=$(chezmoi -S "$ROOT" --override-data '{"modules":{"projects":{"enabled":true}}}' cat "$HOME/bin/projects")
assert_contains "$enabled" 'PROJECTS_FILE=' "enabled profile renders the module CLI"
picker=$(chezmoi -S "$ROOT" --override-data '{"modules":{"projects":{"enabled":true}}}' cat "$HOME/bin/projects-pick")
assert_contains "$picker" 'module_dir=' "enabled profile renders the source-relative picker"

APPLY_HOME="$TEMP/disabled-home"
mkdir -p "$APPLY_HOME/bin" "$APPLY_HOME/.config/yabai"
touch "$APPLY_HOME/bin/projects" "$APPLY_HOME/bin/projects-pick" "$APPLY_HOME/.config/yabai/projects"
printf '{}\n' >"$APPLY_HOME/.config/yabai/projects.json"
printf 'manual binary\n' >"$APPLY_HOME/.config/yabai/projectdeck"
if chezmoi -S "$ROOT" -D "$APPLY_HOME" --persistent-state "$TEMP/projects-state.boltdb" \
    apply --exclude=scripts,externals --force -- "$APPLY_HOME/bin/projects" "$APPLY_HOME/bin/projects-pick" "$APPLY_HOME/.config/yabai/projects"; then
  [[ ! -e "$APPLY_HOME/bin/projects" && ! -e "$APPLY_HOME/bin/projects-pick" && ! -e "$APPLY_HOME/.config/yabai/projects" ]] \
    && pass "disabled apply removes only module targets" || fail "disabled apply removes only module targets" "target remains"
else
  fail "disabled apply removes only module targets" "chezmoi apply failed"
fi
[[ -f "$APPLY_HOME/.config/yabai/projects.json" && -f "$APPLY_HOME/.config/yabai/projectdeck" ]] \
  && pass "disabled apply preserves project data and manual build side effect" \
  || fail "disabled apply preserves project data and manual build side effect" "preserved file missing"

printf '\nTesting child-folder removal safety...\n'
FIXTURE="$TEMP/source"
DEST="$TEMP/home"
mkdir -p "$FIXTURE/home/bin" "$FIXTURE/home/dot_config/yabai" "$FIXTURE/home/.chezmoidata" "$FIXTURE/tests" "$DEST"
printf 'home\n' >"$FIXTURE/.chezmoiroot"
printf 'modules:\n  projects:\n    enabled: false\n' >"$FIXTURE/home/.chezmoidata/10-modules.yaml"
cp "$ROOT/home/bin/executable_projects.tmpl" "$FIXTURE/home/bin/executable_projects.tmpl"
cp "$ROOT/home/bin/executable_projects-pick.tmpl" "$FIXTURE/home/bin/executable_projects-pick.tmpl"
cp "$ROOT/home/dot_config/yabai/executable_projects.tmpl" "$FIXTURE/home/dot_config/yabai/executable_projects.tmpl"
absent=""
absent_error=""
for target in "$DEST/bin/projects" "$DEST/bin/projects-pick" "$DEST/.config/yabai/projects"; do
  if rendered=$(chezmoi -S "$FIXTURE" -D "$DEST" cat "$target" 2>>"$TEMP/absent.err"); then
    absent="${absent}${rendered}"
  else
    absent_error="$(cat "$TEMP/absent.err")"
    break
  fi
done
if [[ -z "$absent_error" ]]; then
  [[ -z "$absent" ]] && pass "all disabled bridges render when child folder is absent" || fail "all disabled bridges render when child folder is absent" "$absent"
else
  fail "all disabled bridges render when child folder is absent" "$absent_error"
fi
cp "$ROOT/tests/test_projects.sh" "$FIXTURE/tests/test_projects.sh"
chmod +x "$FIXTURE/tests/test_projects.sh"
if "$FIXTURE/tests/test_projects.sh" >"$TEMP/parent-test.out" 2>"$TEMP/parent-test.err"; then
  pass "parent Projects test remains valid when the child folder is absent"
else
  fail "parent Projects test remains valid when the child folder is absent" "$(cat "$TEMP/parent-test.err")"
fi

printf '\nTesting the intentional manual ProjectDeck adapter...\n'
FAKE_BIN="$TEMP/bin"
mkdir -p "$FAKE_BIN"
cat >"$FAKE_BIN/uname" <<'EOF'
#!/usr/bin/env bash
printf 'Darwin\n'
EOF
cat >"$FAKE_BIN/swiftc" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$SWIFTC_LOG"
output=""
while [[ $# -gt 0 ]]; do
  if [[ "$1" == -o ]]; then output="$2"; shift 2; else shift; fi
done
printf '#!/usr/bin/env bash\nexit 0\n' >"$output"
chmod +x "$output"
EOF
chmod +x "$FAKE_BIN/uname" "$FAKE_BIN/swiftc"
if PATH="$FAKE_BIN:$PATH" SWIFTC_LOG="$TEMP/swiftc.log" \
    PROJECTDECK_BUILD_PATH="$TEMP/projectdeck-built" PROJECTDECK_INSTALL_PATH="$TEMP/projectdeck-installed" \
    make -s -C "$ROOT" build-projectdeck PROJECTS_MODULE_DIR="$MODULE" >"$TEMP/build.out" 2>"$TEMP/build.err"; then
  pass "manual make target delegates to the module build"
else
  fail "manual make target delegates to the module build" "$(cat "$TEMP/build.err")"
fi
[[ -x "$TEMP/projectdeck-installed" ]] && pass "manual build installs the picker" || fail "manual build installs the picker" "binary missing"
assert_contains "$(cat "$TEMP/swiftc.log")" "$MODULE/projectdeck/ProjectDeck.swift" "manual build compiles module-owned Swift source"
cat >"$FAKE_BIN/yabai" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$FAKE_BIN/projectdeck" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$PROJECTS_BIN" >"$PROJECTS_BIN_LOG"
EOF
chmod +x "$FAKE_BIN/yabai" "$FAKE_BIN/projectdeck"
mkdir -p "$TEMP/manual-home"
if HOME="$TEMP/manual-home" PATH="$FAKE_BIN:$PATH" PROJECTDECK_BIN="$FAKE_BIN/projectdeck" PROJECTS_BIN_LOG="$TEMP/projects-bin.log" \
    PROJECTS_FILE="$TEMP/manual-projects.json" PROJECTS_NOTIFY=0 "$MODULE/bin/projects" pick; then
  [[ "$(cat "$TEMP/projects-bin.log")" == "$MODULE/bin/projects" ]] \
    && pass "manual ProjectDeck points back to the source CLI while disabled" \
    || fail "manual ProjectDeck points back to the source CLI while disabled" "$(cat "$TEMP/projects-bin.log")"
else
  fail "manual ProjectDeck points back to the source CLI while disabled" "projects pick failed"
fi
if make -s -C "$ROOT" build-projectdeck PROJECTS_MODULE_DIR="$TEMP/missing" >"$TEMP/missing.out" 2>"$TEMP/missing.err"; then
  fail "missing optional child fails only its manual target" "target unexpectedly succeeded"
else
  assert_contains "$(cat "$TEMP/missing.err")" 'projects module build adapter is unavailable' "missing optional child has an actionable manual-target error"
fi

[[ ! -e "$ROOT/scripts/projectdeck/ProjectDeck.swift" && ! -e "$ROOT/scripts/build-projectdeck.sh" ]] \
  && pass "old ProjectDeck ownership paths are gone" || fail "old ProjectDeck ownership paths are gone" "stale source remains"

printf '\n%s passed, %s failed\n' "$PASSED" "$FAILED"
[[ "$FAILED" -eq 0 ]]
