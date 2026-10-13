#!/usr/bin/env bash
set -uo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$TEST_DIR")"
PASSED=0
FAILED=0

pass() { printf '  ✓ %s\n' "$1"; PASSED=$((PASSED + 1)); }
fail() { printf '  ✗ %s\n    %s\n' "$1" "$2"; FAILED=$((FAILED + 1)); }
assert_file() { [[ -f "$1" ]] && pass "$2" || fail "$2" "missing $1"; }
assert_contains() {
  local file="$1" text="$2" name="$3"
  grep -Fq -- "$text" "$file" && pass "$name" || fail "$name" "$file does not contain: $text"
}

printf '%s\n' '====================================' 'Dotfiles Control Center Module Tests' '===================================='

for file in \
  "$MODULE_DIR/module.yaml" \
  "$MODULE_DIR/README.md" \
  "$MODULE_DIR/Package.swift" \
  "$MODULE_DIR/bin/dotfiles-control-center" \
  "$MODULE_DIR/Sources/DotfilesControlCenter/App.swift" \
  "$MODULE_DIR/Sources/DotfilesControlCenter/CommandClient.swift" \
  "$MODULE_DIR/Sources/DotfilesControlCenter/AppModel.swift"; do
  assert_file "$file" "transportable module includes ${file#"$MODULE_DIR/"}"
done

if [[ -x "$MODULE_DIR/bin/dotfiles-control-center" ]]; then
  pass "launcher is executable"
else
  fail "launcher is executable" "chmod +x is missing"
fi

if bash -n "$MODULE_DIR/bin/dotfiles-control-center"; then
  pass "launcher syntax is valid"
else
  fail "launcher syntax is valid" "bash -n failed"
fi

assert_contains "$MODULE_DIR/bin/dotfiles-control-center" 'CALLER_CWD="$(pwd -P)"' "launcher captures the physical caller cwd"
assert_contains "$MODULE_DIR/bin/dotfiles-control-center" 'DOTFILES_CONTROL_CENTER_CWD' "launcher propagates cwd explicitly"
assert_contains "$MODULE_DIR/bin/dotfiles-control-center" 'DOTFILES_DIR/modules/dotfiles-control-center' "installed launcher resolves the package through its embedded source root"
assert_contains "$MODULE_DIR/bin/dotfiles-control-center" 'swift run' "launcher delegates build and launch to SwiftPM"

# A source launch must make the service worker available before launching the app.
LAUNCH_FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-launch-test.XXXXXX")"
mkdir -p "$LAUNCH_FIXTURE/bin"
cat > "$LAUNCH_FIXTURE/bin/swift" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == build ]]; then
  [[ "$*" == *'--product dotfiles-service-runner' ]] || exit 31
  printf ready > "$DOTFILES_TEST_WORKER_MARKER"
elif [[ "$1" == run ]]; then
  [[ -s "$DOTFILES_TEST_WORKER_MARKER" ]] || exit 32
  printf '%s\n' "$DOTFILES_CONTROL_CENTER_CWD" "$@" > "$DOTFILES_TEST_LAUNCH_ARGS"
else
  exit 33
fi
EOF
chmod +x "$LAUNCH_FIXTURE/bin/swift"
if PATH="$LAUNCH_FIXTURE/bin:/usr/bin:/bin" \
    DOTFILES_DIR="$(dirname "$(dirname "$MODULE_DIR")")" \
    DOTFILES_TEST_WORKER_MARKER="$LAUNCH_FIXTURE/worker" \
    DOTFILES_TEST_LAUNCH_ARGS="$LAUNCH_FIXTURE/args" \
    "$MODULE_DIR/bin/dotfiles-control-center" 'literal argument with spaces'; then
  pass "source launcher builds its service worker before starting the app"
  assert_contains "$LAUNCH_FIXTURE/args" "$(pwd -P)" "source launch retains caller cwd"
  assert_contains "$LAUNCH_FIXTURE/args" 'literal argument with spaces' "source launch preserves literal arguments"
else
  fail "source launcher builds its service worker before starting the app" "worker or arguments unavailable"
fi
rm -rf "$LAUNCH_FIXTURE"

if yq -e '
  .apiVersion == "dotfiles/v1" and
  .id == "dotfiles-control-center" and
  .dataKey == "modules.dotfilesControlCenter" and
  .distribution.standalone == false and
  .targets[0].ownership == "exclusive" and
  .targets[0].bridge == "home/bin/executable_dotfiles-control-center.tmpl"
' "$MODULE_DIR/module.yaml" >/dev/null; then
  pass "manifest declares the parent bridge and module data contract"
else
  fail "manifest declares the parent bridge and module data contract" "module.yaml contract mismatch"
fi

COMMAND_CLIENT="$MODULE_DIR/Sources/DotfilesControlCenter/CommandClient.swift"
assert_contains "$COMMAND_CLIENT" 'let process = Process()' "backend execution uses Foundation.Process"
assert_contains "$COMMAND_CLIENT" 'process.executableURL = executableURL' "backend uses an explicit executable URL"
assert_contains "$COMMAND_CLIENT" 'process.arguments = arguments' "backend uses an explicit argument array"
assert_contains "$COMMAND_CLIENT" 'process.currentDirectoryURL = currentDirectoryURL' "backend preserves the caller working directory"

if rg -n '/bin/(ba)?sh|"(ba|z)?sh".*"-c"|WKWebView|URLSession|NWListener|localhost|127\.0\.0\.1' \
  "$MODULE_DIR/Sources" >/dev/null; then
  fail "native client contains no shell, browser, server, or port path" "$(rg -n '/bin/(ba)?sh|"(ba|z)?sh".*"-c"|WKWebView|URLSession|NWListener|localhost|127\.0\.0\.1' "$MODULE_DIR/Sources")"
else
  pass "native client contains no shell, browser, server, or port path"
fi

if rg -n '10-modules\.yaml|module\.yaml|dependencies\.lock\.json|yq[[:space:]]+-i|chezmoi[[:space:]]+apply' \
  "$MODULE_DIR/Sources" >/dev/null; then
  fail "native client does not edit parent data or call chezmoi directly" "$(rg -n '10-modules\.yaml|module\.yaml|dependencies\.lock\.json|yq[[:space:]]+-i|chezmoi[[:space:]]+apply' "$MODULE_DIR/Sources")"
else
  pass "native client does not edit parent data or call chezmoi directly"
fi

if swift package --package-path "$MODULE_DIR" dump-package >/dev/null; then
  pass "SwiftPM package manifest resolves"
else
  fail "SwiftPM package manifest resolves" "swift package dump-package failed"
fi

printf '\nResults: %d passed, %d failed\n' "$PASSED" "$FAILED"
[[ "$FAILED" -eq 0 ]]
