#!/usr/bin/env bash

set -uo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$TEST_DIR")"
DOTFILES_DIR="$(cd "$MODULE_DIR/../.." && pwd)"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-shortcut-guide-module.XXXXXX")"
TEMP_DIR="$(cd "$TEMP_DIR" && pwd -P)"
APP="$TEMP_DIR/whichkey"
JSON="$TEMP_DIR/parser.json"
CATALOG="$MODULE_DIR/bin/shortcut-catalog"
OUTPUT_DIR="$TEMP_DIR/generated"
FAKE_BIN="$TEMP_DIR/bin"
PASSED=0
FAILED=0

cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT
pass() { printf '  ✓ %s\n' "$1"; PASSED=$((PASSED + 1)); }
fail() { printf '  ✗ %s\n    Expected: %s\n    Actual:   %s\n' "$1" "$2" "$3"; FAILED=$((FAILED + 1)); }
assert_file() { [[ -f "$1" ]] && pass "$2" || fail "$2" "$1" "missing"; }
assert_executable() { [[ -x "$1" ]] && pass "$2" || fail "$2" "executable $1" "missing or not executable"; }
assert_absent() { [[ ! -e "$1" ]] && pass "$2" || fail "$2" "absent" "$1 exists"; }
assert_contains() { grep -Fq -- "$2" "$1" && pass "$3" || fail "$3" "text containing $2" "$1"; }
assert_jq() {
  local expression="$1" name="$2" file="${3:-$OUTPUT_DIR/shortcuts.json}"
  if jq -e "$expression" "$file" >/dev/null; then
    pass "$name"
  else
    fail "$name" "jq expression: $expression" "$file"
  fi
}

printf '================================\nShortcut Guide Module Contract Tests\n================================\n'

assert_file "$MODULE_DIR/module.yaml" "module manifest exists"
assert_file "$MODULE_DIR/README.md" "module documents its boundary"
assert_file "$MODULE_DIR/app/WhichKey.swift" "module owns the Swift application"
assert_executable "$MODULE_DIR/install/build-whichkey.sh" "module owns the native build adapter"
assert_executable "$CATALOG" "module owns the catalog generator"
assert_executable "$MODULE_DIR/bin/show_keys.sh" "module owns the stable launcher implementation"
assert_file "$MODULE_DIR/targets/skhdrc.tmpl" "module owns the shortcut-guide binding"
assert_file "$MODULE_DIR/generated/shortcuts.json" "module checks in machine-readable shortcuts"
assert_file "$MODULE_DIR/generated/shortcuts.md" "module checks in human-readable shortcuts"
assert_absent "$DOTFILES_DIR/scripts/whichkey/WhichKey.swift" "legacy Swift source is removed"
assert_contains "$DOTFILES_DIR/scripts/build-whichkey.sh" \
  'exec "$ROOT/modules/shortcut-guide/install/build-whichkey.sh" "$@"' \
  "legacy build path is a thin compatibility wrapper"

if yq eval '.' "$MODULE_DIR/module.yaml" >/dev/null 2>&1; then
  pass "module manifest parses as YAML"
else
  fail "module manifest parses as YAML" "valid YAML" "parse error"
fi

if bash -n "$MODULE_DIR/install/build-whichkey.sh" \
  && bash -n "$MODULE_DIR/bin/show_keys.sh" \
  && bash -n "$DOTFILES_DIR/scripts/build-whichkey.sh"; then
  pass "module shell entrypoints parse"
else
  fail "module shell entrypoints parse" "valid shell" "syntax error"
fi

if PYTHONDONTWRITEBYTECODE=1 python3 "$CATALOG" --help >/dev/null; then
  pass "catalog command parses"
else
  fail "catalog command parses" "successful --help" "command failed"
fi

assert_contains "$MODULE_DIR/app/WhichKey.swift" 'let owner: String' "Swift model exports shortcut ownership"
assert_contains "$MODULE_DIR/app/WhichKey.swift" 'comment.hasPrefix("dotfiles-owner:")' "Swift parser reads rendered ownership markers"
assert_contains "$MODULE_DIR/bin/show_keys.sh" 'module_dir="${SHORTCUT_GUIDE_MODULE_DIR:-$dotfiles_dir/modules/shortcut-guide}"' "launcher resolves module-owned source"
assert_contains "$MODULE_DIR/README.md" 'not repeat shortcut keys or commands.' "module documents rendered skhd authority"

if [[ "$(uname -s)" != "Darwin" ]]; then
  pass "native parser and catalog execution are macOS-only"
  printf '\n================================\nResults: %d passed, %d failed\n================================\n' "$PASSED" "$FAILED"
  exit "$FAILED"
fi

if WHICHKEY_BUILD_PATH="$TEMP_DIR/build/whichkey" WHICHKEY_INSTALL_PATH="$APP" \
  "$MODULE_DIR/install/build-whichkey.sh" >"$TEMP_DIR/build.log" 2>&1; then
  pass "module build adapter compiles and installs WhichKey"
else
  fail "module build adapter compiles and installs WhichKey" "successful build" "$(cat "$TEMP_DIR/build.log")"
fi
assert_executable "$APP" "built WhichKey is executable"

if [[ "$($APP --self-test 2>&1)" == "whichkey self-test: 19 passed" ]]; then
  pass "embedded parser and search self-test passes"
else
  fail "embedded parser and search self-test passes" "19 passed" "$($APP --self-test 2>&1)"
fi

cat >"$TEMP_DIR/owned.skhdrc" <<'EOF'
# dotfiles-owner: app-focus
# ============================================================
# App Focus
# ============================================================
alt - 1 : ~/.config/skhd/focus_app.sh 1 "Browser" # Focus Browser
# dotfiles-owner: root
# ============================================================
# System
# ============================================================
alt - 0x2C : ~/.config/skhd/show_keys.sh # Open shortcut guide
EOF

if "$APP" --dump-json "$TEMP_DIR/owned.skhdrc" >"$JSON"; then
  pass "WhichKey dumps owned bindings as JSON"
else
  fail "WhichKey dumps owned bindings as JSON" "successful dump" "command failed"
fi
assert_jq 'length == 2' "fixture contains two shortcuts" "$JSON"
assert_jq 'any(.[]; .rawKey == "alt - 1" and .owner == "app-focus")' "explicit marker assigns module ownership" "$JSON"
assert_jq 'any(.[]; .rawKey == "alt - 0x2C" and .owner == "root")' "root marker restores root ownership" "$JSON"

mkdir -p "$FAKE_BIN" "$TEMP_DIR/home"
cat >"$FAKE_BIN/chezmoi" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$SHORTCUT_CATALOG_TEST_LOG"
if [[ "$1" != "-S" || "$2" != "$SHORTCUT_CATALOG_TEST_ROOT" || "$3" != "cat" || "$4" != "$HOME/.skhdrc" ]]; then
  printf 'unexpected chezmoi invocation: %s\n' "$*" >&2
  exit 64
fi
cat "$SHORTCUT_CATALOG_TEST_SKHDRC"
EOF
chmod +x "$FAKE_BIN/chezmoi"
: >"$TEMP_DIR/chezmoi.log"

CATALOG_ENV=(
  PATH="$FAKE_BIN:$PATH"
  HOME="$TEMP_DIR/home"
  SHORTCUT_CATALOG_TEST_LOG="$TEMP_DIR/chezmoi.log"
  SHORTCUT_CATALOG_TEST_ROOT="$DOTFILES_DIR"
  SHORTCUT_CATALOG_TEST_SKHDRC="$TEMP_DIR/owned.skhdrc"
  SHORTCUT_CATALOG_WHICHKEY_BIN="$APP"
)

if env "${CATALOG_ENV[@]}" "$CATALOG" update --root "$DOTFILES_DIR" --output-dir "$OUTPUT_DIR" >"$TEMP_DIR/update.log" 2>&1; then
  pass "catalog update renders through chezmoi and writes outputs"
else
  fail "catalog update renders through chezmoi and writes outputs" "successful update" "$(cat "$TEMP_DIR/update.log")"
fi
assert_contains "$TEMP_DIR/chezmoi.log" "-S $DOTFILES_DIR cat $TEMP_DIR/home/.skhdrc" "catalog renders desired state instead of reading live skhd"
assert_file "$OUTPUT_DIR/shortcuts.json" "catalog writes JSON"
assert_file "$OUTPUT_DIR/shortcuts.md" "catalog writes Markdown"
assert_jq '.schemaVersion == 1 and (.renderedSourceSha256 | test("^[0-9a-f]{64}$"))' "JSON declares schema and rendered-source digest"
assert_jq '.shortcuts | length == 2' "JSON contains normalized shortcuts"
assert_jq 'all(.shortcuts[]; .stableId | test("^sha256:[0-9a-f]{64}$"))' "JSON uses stable SHA-256 identities"
assert_jq 'all(.shortcuts[]; (has("id") | not) and (has("sourceLine") | not))' "JSON excludes volatile parser identity and line numbers"
assert_jq 'any(.shortcuts[]; .owner == "app-focus") and any(.shortcuts[]; .owner == "root")' "JSON preserves validated owners"
assert_contains "$OUTPUT_DIR/shortcuts.md" '<!-- Generated by modules/shortcut-guide/bin/shortcut-catalog. Do not edit. -->' "Markdown identifies its generator"
assert_contains "$OUTPUT_DIR/shortcuts.md" '[app-focus](../../app-focus/README.md)' "Markdown links module ownership"

cp "$OUTPUT_DIR/shortcuts.json" "$TEMP_DIR/first.json"
cp "$OUTPUT_DIR/shortcuts.md" "$TEMP_DIR/first.md"
if env "${CATALOG_ENV[@]}" "$CATALOG" update --root "$DOTFILES_DIR" --output-dir "$OUTPUT_DIR" >/dev/null \
  && cmp -s "$TEMP_DIR/first.json" "$OUTPUT_DIR/shortcuts.json" \
  && cmp -s "$TEMP_DIR/first.md" "$OUTPUT_DIR/shortcuts.md"; then
  pass "catalog output is deterministic across updates"
else
  fail "catalog output is deterministic across updates" "byte-identical outputs" "outputs changed"
fi

if env "${CATALOG_ENV[@]}" "$CATALOG" check --root "$DOTFILES_DIR" --output-dir "$OUTPUT_DIR" >/dev/null; then
  pass "catalog check accepts current output"
else
  fail "catalog check accepts current output" "successful check" "check failed"
fi

printf 'tampered\n' >>"$OUTPUT_DIR/shortcuts.json"
cp "$OUTPUT_DIR/shortcuts.json" "$TEMP_DIR/tampered.json"
if env "${CATALOG_ENV[@]}" "$CATALOG" check --root "$DOTFILES_DIR" --output-dir "$OUTPUT_DIR" >"$TEMP_DIR/check.log" 2>&1; then
  fail "catalog check rejects stale output" "non-zero check" "check passed"
elif cmp -s "$TEMP_DIR/tampered.json" "$OUTPUT_DIR/shortcuts.json"; then
  pass "catalog check rejects stale output without writing"
else
  fail "catalog check rejects stale output without writing" "unchanged tampered file" "file changed"
fi

cat >"$TEMP_DIR/invalid-owner.skhdrc" <<'EOF'
# dotfiles-owner: missing-module
alt - 1 : ~/.config/skhd/focus_app.sh 1 "Browser"
EOF
INVALID_ENV=("${CATALOG_ENV[@]}")
INVALID_ENV[4]="SHORTCUT_CATALOG_TEST_SKHDRC=$TEMP_DIR/invalid-owner.skhdrc"
if env "${INVALID_ENV[@]}" "$CATALOG" update --root "$DOTFILES_DIR" --output-dir "$TEMP_DIR/invalid" >"$TEMP_DIR/invalid.log" 2>&1; then
  fail "catalog rejects unknown owners" "non-zero update" "update passed"
elif grep -Fq "unknown module owner 'missing-module'" "$TEMP_DIR/invalid.log"; then
  pass "catalog rejects unknown owners"
else
  fail "catalog rejects unknown owners" "unknown owner diagnostic" "$(cat "$TEMP_DIR/invalid.log")"
fi

printf '\n================================\nResults: %d passed, %d failed\n================================\n' "$PASSED" "$FAILED"
exit "$FAILED"
