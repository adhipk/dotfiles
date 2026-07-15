#!/usr/bin/env bash
set -uo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$TEST_DIR")"
COMMAND="$MODULE_DIR/bin/dotfiles-deps"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-dependencies.XXXXXX")"
ROOT="$TEMP_DIR/repo"
HOME_DIR="$TEMP_DIR/home"
FAKE_BIN="$TEMP_DIR/bin"
TOOL_LOG="$TEMP_DIR/tools.log"
OUT="$TEMP_DIR/out"
ERR="$TEMP_DIR/err"
PASSED=0
FAILED=0
STATUS=0

cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT
pass() { printf '  ✓ %s\n' "$1"; PASSED=$((PASSED + 1)); }
fail() { printf '  ✗ %s\n    Expected: %s\n    Actual: %s\n' "$1" "$2" "$3"; FAILED=$((FAILED + 1)); }
assert_eq() { [[ "$1" == "$2" ]] && pass "$3" || fail "$3" "$1" "$2"; }
assert_json() {
  local expression="$1" name="$2"
  if jq -e "$expression" "$OUT" >/dev/null 2>&1; then pass "$name"; else fail "$name" "$expression" "$(cat "$OUT")"; fi
}
run_deps() {
  : >"$OUT"; : >"$ERR"; STATUS=0
  find "$HOME_DIR" -name .fake-head -delete 2>/dev/null || true
  HOME="$HOME_DIR" PATH="$FAKE_BIN:$PATH" DOTFILES_DIR="$ROOT" TOOL_LOG="$TOOL_LOG" \
    BREW_FAIL="${BREW_FAIL:-0}" BREW_TAP_FAIL="${BREW_TAP_FAIL:-0}" BREW_OUTDATED_FAIL="${BREW_OUTDATED_FAIL:-0}" CODIUM_FAIL="${CODIUM_FAIL:-0}" \
    GIT_DIRTY="${GIT_DIRTY:-0}" GIT_PIN_DIRTY="${GIT_PIN_DIRTY:-0}" GIT_HEAD="${GIT_HEAD:-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb}" \
    "$COMMAND" "$@" >"$OUT" 2>"$ERR" || STATUS=$?
}

mkdir -p \
  "$ROOT/modules/dependencies/config" "$ROOT/modules/alpha" "$ROOT/modules/beta/bin" "$ROOT/modules/beta/targets" \
  "$ROOT/home/dot_local/lib/dotfiles" "$ROOT/home/dot_config/yazi" \
  "$HOME_DIR/.custom/plugins/tpm/.git" "$HOME_DIR/.custom/plugins/example/.git" "$HOME_DIR/.custom/plugins/unpinned/.git" \
  "$HOME_DIR/projects/plugin-cli/.git" \
  "$FAKE_BIN" "$ROOT/nvim"
cat >"$ROOT/modules/dependencies/config/sources.toml" <<'EOF'
schema_version = 1
[sources]
brewfile = "Brewfile"
modules = "modules"
chezmoi_data = "home/.chezmoidata.toml"
chezmoi_externals = "home/.chezmoiexternal.toml.tmpl"
tmux = "home/dot_tmux.conf.tmpl"
tmux_installer = "install.sh"
yazi = "home/dot_config/yazi/package.toml"
neovim = "nvim/nvim-pack-lock.json"
[runtime]
shared_library_dir = "home/dot_local/lib/dotfiles"
tmux_plugin_dir = ".custom/plugins"

[[local_git_plugins]]
id = "plugin-cli"
path = "projects/plugin-cli"
commit = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
provides = ["plugin-cli"]
EOF

cat >"$ROOT/Brewfile" <<'EOF'
tap "owner/tap"
brew "foo"
brew "missing-formula"
brew "neovim"
brew "ripgrep"
cask "example-app"
cask "ghostty"
EOF
cat >"$ROOT/modules/alpha/module.yaml" <<'EOF'
apiVersion: dotfiles/v1
kind: Module
id: alpha
requires:
  executables: [foo, missing-cli, cksum, bc, nvim, rg, ghostty, owned-cli, plugin-cli]
  libraries: [core.sh]
optional:
  executables: [optional-cli]
EOF
cat >"$ROOT/modules/beta/module.yaml" <<'EOF'
apiVersion: dotfiles/v1
kind: Module
id: beta
commands:
  - name: owned-cli
    source: bin/owned-cli
EOF
printf '#!/usr/bin/env bash\n' >"$ROOT/modules/beta/bin/owned-cli"
cat >"$ROOT/modules/beta/targets/tmux-persistence.conf.tmpl" <<'EOF'
set -g @plugin 'tmux-plugins/tmux-resurrect#v4.0.0'
set -g @plugin 'tmux-plugins/tmux-continuum#v3.1.0'
EOF
printf 'library\n' >"$ROOT/home/dot_local/lib/dotfiles/core.sh"
cat >"$ROOT/home/.chezmoidata.toml" <<'EOF'
vscodeExtensions = ["publisher.extension"]
[[gitPins]]
id = "chezmoi-git:.custom/plugins/tpm"
manager = "chezmoi"
path = ".custom/plugins/tpm"
revision = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
[[gitPins]]
id = "tpm:owner/unpinned"
manager = "tpm"
path = ".custom/plugins/unpinned"
revision = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
[[externalProjects]]
name = "project"
url = "https://example.invalid/project.git"
path = ".local/share/project"
refreshPeriod = "168h"
EOF
cat >"$ROOT/home/.chezmoiexternal.toml.tmpl" <<'EOF'
[".custom/plugins/tpm"]
type = "git-repo"
url = "https://github.com/tmux-plugins/tpm.git"
EOF
cat >"$ROOT/home/dot_tmux.conf.tmpl" <<'EOF'
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'owner/example#v1.2.3'
set -g @plugin 'owner/unpinned'
EOF
cat >"$ROOT/install.sh" <<'EOF'
plugin_dir="$CHEZMOI_DESTINATION/.tmux/plugins/example"
expected_revision="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
EOF
cat >"$ROOT/home/dot_config/yazi/package.toml" <<'EOF'
[[plugin.deps]]
use = "owner/yazi-plugin"
rev = "abc1234"
hash = "11111111111111111111111111111111"
EOF
cat >"$ROOT/nvim/nvim-pack-lock.json" <<'EOF'
{"plugins":{"nvim-plugin":{"rev":"2222222222222222222222222222222222222222","src":"https://example.invalid/nvim"}}}
EOF
cat >"$ROOT/modules/dependencies/dependencies.lock.json" <<'EOF'
{
  "schemaVersion": 1,
  "complete": true,
  "managerStatus": {"homebrew":"complete","git":"complete","vscodium":"complete"},
  "errors": [],
  "dependencies": {
    "homebrew:formula:foo": {"installedVersion":"1.0.0","resolvedVersion":"1.1.0","installedPath":null},
    "homebrew:formula:missing-formula": {"installedVersion":null,"resolvedVersion":"9.0.0","installedPath":null},
    "homebrew:cask:example-app": {"installedVersion":"2.0.0","resolvedVersion":"2.0.0","installedPath":null},
    "chezmoi-git:.custom/plugins/tpm": {"installedVersion":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","resolvedVersion":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","installedPath":null},
    "chezmoi-git:.local/share/project": {"installedVersion":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","resolvedVersion":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","installedPath":null},
    "tpm:owner/example": {"installedVersion":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","resolvedVersion":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","installedPath":null},
    "vscodium:publisher.extension": {"installedVersion":"3.0.0","resolvedVersion":null,"installedPath":null},
    "yazi:owner/yazi-plugin": {"installedVersion":null,"resolvedVersion":"11111111111111111111111111111111","installedPath":null},
    "neovim:nvim-plugin": {"installedVersion":null,"resolvedVersion":"2222222222222222222222222222222222222222","installedPath":null},
    "stale:removed-declaration": {"installedVersion":"old","resolvedVersion":null,"installedPath":null}
  }
}
EOF

cat >"$FAKE_BIN/brew" <<'EOF'
#!/usr/bin/env bash
printf 'brew %s\n' "$*" >>"$TOOL_LOG"
if [[ "$BREW_FAIL" == "1" ]]; then
  printf 'simulated brew failure\n' >&2
  exit 77
fi
if [[ "$1" == "tap" ]]; then
  if [[ "$BREW_TAP_FAIL" == "1" ]]; then printf 'simulated tap failure\n' >&2; exit 80; fi
  printf '%s\n' 'OWNER/TAP'
  exit 0
fi
if [[ "$1" == "outdated" ]]; then
  if [[ "$BREW_OUTDATED_FAIL" == "1" ]]; then printf 'simulated outdated failure\n' >&2; exit 79; fi
  printf '%s\n' '{"formulae":[{"name":"foo","installed_versions":["1.0.0"],"current_version":"1.1.0"}],"casks":[]}'
  exit 0
fi
if [[ "$1" == "info" && "$3" == "--formula" ]]; then
  if [[ "$4" == "missing-formula" ]]; then installed='[]'; else installed='[{"version":"1.0.0"}]'; fi
  printf '{"formulae":[{"name":"%s","installed":%s,"versions":{"stable":"1.1.0"},"revision":0}]}\n' "$4" "$installed"
  exit 0
fi
if [[ "$1" == "info" && "$3" == "--cask" ]]; then
  printf '{"casks":[{"token":"%s","installed":"2.0.0","version":"2.0.0"}]}\n' "$4"
  exit 0
fi
exit 91
EOF
cat >"$FAKE_BIN/git" <<'EOF'
#!/usr/bin/env bash
printf 'git %s\n' "$*" >>"$TOOL_LOG"
if [[ "$*" == *" status --porcelain=v1"* ]]; then
  if [[ "$*" == *"/projects/plugin-cli"* && "$GIT_DIRTY" == "1" ]]; then
    printf ' M plugin-cli\n'
  fi
  if [[ "$*" == *"/.custom/plugins/tpm"* && "$GIT_PIN_DIRTY" == "1" ]]; then
    printf ' M bin/install_plugins\n'
  fi
  exit 0
fi
if [[ "$*" == *" rev-parse HEAD" ]]; then
  if [[ -f "$2/.fake-head" ]]; then cat "$2/.fake-head"; else printf '%s\n' "$GIT_HEAD"; fi
  exit 0
fi
if [[ "$*" == *" cat-file -e "* ]]; then exit 0; fi
if [[ "$*" == *" checkout --quiet --detach "* ]]; then
  printf '%s\n' "$6" >"$2/.fake-head"
  exit 0
fi
exit 92
EOF
cat >"$FAKE_BIN/codium" <<'EOF'
#!/usr/bin/env bash
printf 'codium %s\n' "$*" >>"$TOOL_LOG"
if [[ "$CODIUM_FAIL" == "1" ]]; then printf 'simulated codium failure\n' >&2; exit 78; fi
printf '%s\n' 'publisher.extension@3.0.0'
EOF
chmod +x "$FAKE_BIN/brew" "$FAKE_BIN/git" "$FAKE_BIN/codium"

printf '================================\nDependency Module Tests\n================================\n'

: >"$TOOL_LOG"
run_deps status --json
assert_eq 0 "$STATUS" "offline JSON status succeeds"
assert_eq 0 "$(wc -l <"$TOOL_LOG" | tr -d ' ')" "offline status does not execute Brew, Git, or Codium"
assert_json '.offline == true and .schemaVersion == 1' "status exposes a stable offline JSON envelope"
assert_json 'any(.dependencies[]; .id == "homebrew:formula:foo" and .installedVersion == "1.0.0" and .pinStatus == "rolling")' "status inventories Brewfile formula snapshots"
assert_json 'any(.dependencies[]; .id == "homebrew:formula:missing-formula" and .resolvedVersion == "9.0.0" and .state == "missing")' "a resolvable Homebrew formula is not misreported as installed"
assert_json 'any(.dependencies[]; .id == "homebrew:cask:example-app") and any(.dependencies[]; .id == "homebrew:tap:owner/tap")' "status inventories Homebrew casks and taps"
assert_json 'any(.dependencies[]; .id == "module-executable:missing-cli" and .owners == ["alpha"] and .state == "missing")' "status centralizes missing module requirements with owners"
assert_json 'any(.dependencies[]; .id == "module-library:core.sh" and .pinStatus == "source-hash")' "status inventories shared module libraries"
assert_json 'any(.dependencies[]; .id == "module-executable:cksum" and .pinStatus == "platform-owned")' "status classifies POSIX checksum tooling as platform-owned"
assert_json 'any(.dependencies[]; .id == "module-executable:bc" and .pinStatus == "platform-owned")' "status classifies the macOS bc runtime as platform-owned"
assert_json 'any(.dependencies[]; .id == "module-executable:owned-cli" and .pinStatus == "source-hash" and .resolvedVersion != null and (.owners | sort) == ["alpha", "beta"] and (.sources | sort) == ["modules/alpha/module.yaml", "modules/beta/module.yaml"])' "module-provided executables resolve to their source hash and provider"
assert_json '([.dependencies[] | select(.id == "module-executable:nvim" or .id == "module-executable:rg" or .id == "module-executable:ghostty")] | length) == 0' "Homebrew aliases do not create redundant module dependency authorities"
assert_json 'any(.dependencies[]; .id == "homebrew:formula:neovim" and (.owners | index("alpha")) != null) and any(.dependencies[]; .id == "homebrew:formula:ripgrep" and (.owners | index("alpha")) != null) and any(.dependencies[]; .id == "homebrew:cask:ghostty" and (.owners | index("alpha")) != null)' "Homebrew formulae and casks inherit module ownership"
assert_json 'any(.dependencies[]; .id == "local-git:plugin-cli" and .declaredVersion == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" and .resolvedVersion == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" and (.installedPath | endswith("/projects/plugin-cli")) and .providedExecutables == ["plugin-cli"] and (.owners | index("alpha")) != null)' "status inventories the HOME-relative local Git plugin authority"
assert_json '([.dependencies[] | select(.id == "module-executable:plugin-cli")] | length) == 0 and any(.dependencies[]; .id == "local-git:plugin-cli" and (.sources | index("modules/alpha/module.yaml")) != null)' "provided executables map module requirements to one local Git authority"
assert_json 'any(.dependencies[]; .id == "chezmoi-git:.custom/plugins/tpm" and .pinStatus == "commit" and .declaredVersion == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")' "status applies immutable pins to static ChezMoi git externals"
assert_json 'any(.dependencies[]; .id == "chezmoi-git:.local/share/project")' "status inventories data-driven external projects"
assert_json 'any(.dependencies[]; .id == "tpm:owner/example" and .pinStatus == "commit") and any(.dependencies[]; .id == "tpm:owner/unpinned" and .pinStatus == "commit" and .declaredVersion == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")' "status applies explicit commit pins where TPM only declares a floating plugin"
assert_json 'any(.dependencies[]; .id == "tpm:tmux-plugins/tmux-resurrect" and .declaredVersion == "v4.0.0" and .owners == ["beta"] and .source == "modules/beta/targets/tmux-persistence.conf.tmpl") and any(.dependencies[]; .id == "tpm:tmux-plugins/tmux-continuum" and .declaredVersion == "v3.1.0")' "status inventories versioned TPM declarations owned by module fragments"
assert_json 'any(.dependencies[]; .id == "yazi:owner/yazi-plugin" and .pinStatus == "revision+hash")' "status inventories Yazi revision and integrity hash"
assert_json 'any(.dependencies[]; .id == "neovim:nvim-plugin" and .resolvedVersion == "2222222222222222222222222222222222222222")' "status inventories Neovim lock revisions"
assert_json 'any(.dependencies[]; .id == "vscodium:publisher.extension" and .installedVersion == "3.0.0")' "status inventories VSCodium extension declarations and snapshots"
assert_json '.summary.missing > 0 and .summary.unpinned > 0' "status centrally summarizes missing and unpinned dependencies"
assert_json '.summary.missingLockIds > 0 and .summary.staleLockIds == 1 and (.lockDrift.staleIds == ["stale:removed-declaration"])' "status diagnoses missing and stale lock IDs"
assert_json '[.dependencies[] | select(.target == "~/.custom/plugins/tpm")] | length == 1' "one authority represents the shared ChezMoi and TPM target"
assert_json 'any(.dependencies[]; .id == "chezmoi-git:.custom/plugins/tpm" and (.sources | sort) == ["home/.chezmoidata.toml", "home/.chezmoiexternal.toml.tmpl", "home/dot_tmux.conf.tmpl"])' "deduplicated authority retains every declaration and pin source"

GIT_HEAD=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb run_deps pins check --json
if [[ "$STATUS" -ne 0 ]] && jq -e '.ok == false and ([.pins[] | select(.state == "drifted")] | length) == 2' "$OUT" >/dev/null; then
  pass "git pin check reports every clean checkout that drifted from its immutable declaration"
else
  fail "git pin check reports every clean checkout that drifted from its immutable declaration" "two drifted pins and nonzero" "status=$STATUS out=$(cat "$OUT")"
fi

: >"$TOOL_LOG"
GIT_HEAD=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa GIT_PIN_DIRTY=1 run_deps pins check --manager chezmoi --json
if [[ "$STATUS" -ne 0 ]] && jq -e '.ok == false and .changed == 0 and .pins[0].state == "local-modified"' "$OUT" >/dev/null; then
  pass "git pin check reports tracked local work even when HEAD matches the pin"
else
  fail "git pin check reports tracked local work even when HEAD matches the pin" "local-modified and nonzero" "status=$STATUS out=$(cat "$OUT") err=$(cat "$ERR")"
fi

: >"$TOOL_LOG"
GIT_HEAD=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa GIT_PIN_DIRTY=1 run_deps pins apply --manager chezmoi --json
if [[ "$STATUS" -eq 0 ]] && jq -e '.ok == true and .changed == 0 and .pins[0].state == "current-local-modified"' "$OUT" >/dev/null && ! rg -q 'checkout --quiet --detach' "$TOOL_LOG"; then
  pass "git pin apply preserves tracked local work when HEAD already matches the pin"
else
  fail "git pin apply preserves tracked local work when HEAD already matches the pin" "current-local-modified, zero changes, and no checkout" "status=$STATUS out=$(cat "$OUT") err=$(cat "$ERR") log=$(cat "$TOOL_LOG")"
fi

: >"$TOOL_LOG"
GIT_HEAD=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb run_deps pins apply --json
if [[ "$STATUS" -eq 0 ]] && jq -e '.ok == true and .changed == 2 and all(.pins[]; .state == "applied")' "$OUT" >/dev/null && rg -q 'checkout --quiet --detach aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' "$TOOL_LOG"; then
  pass "git pin apply performs verified detached checkouts without fetching"
else
  fail "git pin apply performs verified detached checkouts without fetching" "two applied pins and checkout calls" "status=$STATUS out=$(cat "$OUT") err=$(cat "$ERR")"
fi

cp "$ROOT/install.sh" "$TEMP_DIR/install.good"
sed 's/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/cccccccccccccccccccccccccccccccccccccccc/' "$TEMP_DIR/install.good" >"$ROOT/install.sh"
run_deps status --json
assert_json 'any(.dependencies[]; .id == "tpm:owner/example" and .updateStatus == "declaration-drift" and .drifted == true)' "status detects expected_revision drift from the checked resolution"
cp "$TEMP_DIR/install.good" "$ROOT/install.sh"

: >"$TOOL_LOG"
run_deps snapshot --json
assert_eq 0 "$STATUS" "snapshot succeeds entirely through fake local managers"
assert_json '.dependencies["homebrew:tap:owner/tap"].installedVersion == "present"' "snapshot matches Homebrew taps case-insensitively"
assert_json '.dependencies["local-git:plugin-cli"].installedVersion == "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" and .dependencies["local-git:plugin-cli"].resolvedVersion == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" and (.dependencies["local-git:plugin-cli"].installedPath | endswith("/projects/plugin-cli"))' "snapshot captures the local Git HEAD, declared commit, and checkout path"

: >"$TOOL_LOG"
CODIUM_FAIL=1 run_deps snapshot --json
if [[ "$STATUS" -ne 0 && ! -s "$OUT" ]] && rg -q 'refusing snapshot replacement' "$ERR"; then pass "snapshot refuses to erase versions when an optional declared manager is unavailable"; else fail "snapshot refuses to erase versions when an optional declared manager is unavailable" "nonzero, empty stdout, explicit refusal" "status=$STATUS out=$(cat "$OUT") err=$(cat "$ERR")"; fi

: >"$TOOL_LOG"
BREW_FAIL=1 run_deps snapshot --json
if [[ "$STATUS" -ne 0 && ! -s "$OUT" ]]; then pass "snapshot fails closed without JSON when required manager inventory fails"; else fail "snapshot fails closed without JSON when required manager inventory fails" "nonzero and empty stdout" "status=$STATUS out=$(cat "$OUT")"; fi

: >"$TOOL_LOG"
GIT_DIRTY=1 run_deps check --json
assert_eq 0 "$STATUS" "manager-backed JSON check succeeds with fake tools"
assert_json '.offline == false and .summary.outdated == 1' "check reports Homebrew outdated results centrally"
assert_json 'any(.dependencies[]; .id == "homebrew:formula:foo" and .outdated == true)' "check maps brew outdated results to the normalized dependency"
assert_json 'any(.dependencies[]; .id == "homebrew:formula:missing-formula" and .state == "missing" and .updateStatus == "missing")' "check never calls a missing Homebrew entry current"
assert_json 'any(.dependencies[]; .id == "homebrew:formula:foo" and .state == "available" and .installedVersion == "1.0.0" and .resolvedVersion == "1.1.0")' "check refreshes Homebrew installed and stable versions"
assert_json '.summary.drifted > 0' "check reports local Git drift from the checked snapshot"
assert_json 'any(.dependencies[]; .id == "local-git:plugin-cli" and .installedVersion == "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" and .updateStatus == "local-modified" and .remoteStatus == "unchecked" and .drifted == true)' "check surfaces a dirty local plugin without claiming a remote result"
assert_json 'all(.dependencies[] | select(.manager == "chezmoi" or .manager == "tpm"); .updateStatus == "local-drift" or .updateStatus == "remote-unchecked")' "check surfaces Git remote update state as unchecked"
if rg -q '^brew outdated --json=v2$' "$TOOL_LOG" && rg -q '^git -C .* rev-parse HEAD$' "$TOOL_LOG"; then
  pass "check delegates to existing Brew and Git manager surfaces"
else
  fail "check delegates to existing Brew and Git manager surfaces" "brew outdated and git rev-parse calls" "$(cat "$TOOL_LOG")"
fi
if rg -q '^git .*(fetch|pull|remote update)' "$TOOL_LOG"; then
  fail "local Git checks never contact or mutate remotes" "no fetch, pull, or remote update" "$(cat "$TOOL_LOG")"
else
  pass "local Git checks never contact or mutate remotes"
fi
if ! rg -q '^codium ' "$TOOL_LOG"; then pass "check does not invent a VSCodium update manager"; else fail "check does not invent a VSCodium update manager" "no codium mutation" "$(cat "$TOOL_LOG")"; fi

GIT_HEAD=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa GIT_DIRTY=0 run_deps check --json
assert_json 'any(.dependencies[]; .id == "local-git:plugin-cli" and .updateStatus == "remote-unchecked" and .remoteStatus == "unchecked" and .drifted == false)' "a clean declared HEAD still reports remote availability as unchecked"

GIT_HEAD=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa GIT_PIN_DIRTY=1 run_deps check --json
assert_json 'any(.dependencies[]; .id == "chezmoi-git:.custom/plugins/tpm" and .updateStatus == "local-modified" and .drifted == true)' "manager checks surface tracked changes in immutable ChezMoi and TPM checkouts"

BREW_FAIL=1 run_deps check --json
if [[ "$STATUS" -ne 0 ]] && jq -e '.summary.managerErrors > 0 and any(.dependencies[]; .manager == "homebrew" and .updateStatus == "error")' "$OUT" >/dev/null; then
  pass "check emits diagnostic JSON and exits nonzero on manager errors"
else
  fail "check emits diagnostic JSON and exits nonzero on manager errors" "nonzero with manager errors" "status=$STATUS out=$(cat "$OUT")"
fi

BREW_OUTDATED_FAIL=1 run_deps check --json
if [[ "$STATUS" -ne 0 ]] && jq -e 'any(.dependencies[]; .id == "homebrew:formula:foo" and .state == "installed" and .updateStatus == "error") and ([.dependencies[] | select(.manager == "homebrew" and .updateStatus == "current")] | length == 0)' "$OUT" >/dev/null; then
  pass "failed outdated inventory never labels installed packages current"
else
  fail "failed outdated inventory never labels installed packages current" "installed/error and no current" "status=$STATUS out=$(cat "$OUT")"
fi

BREW_TAP_FAIL=1 run_deps check --json
if [[ "$STATUS" -ne 0 ]] && jq -e 'any(.dependencies[]; .kind == "tap" and .state == "unknown" and .updateStatus == "error")' "$OUT" >/dev/null; then
  pass "failed tap inventory reports unknown/error rather than missing"
else
  fail "failed tap inventory reports unknown/error rather than missing" "unknown/error tap" "status=$STATUS out=$(cat "$OUT")"
fi

run_deps status
assert_eq 0 "$STATUS" "human offline status succeeds"
if rg -q '^MANAGER.*KIND.*NAME.*STATE.*PIN.*UPDATE' "$OUT" && rg -q '^Total:' "$OUT"; then
  pass "human status exposes inventory and central summary"
else
  fail "human status exposes inventory and central summary" "table and summary" "$(cat "$OUT")"
fi

if rg -q '^    - python3$' "$MODULE_DIR/module.yaml"; then pass "the dependency module declares required Python 3"; else fail "the dependency module declares required Python 3" "python3 requirement" "$(cat "$MODULE_DIR/module.yaml")"; fi

cp "$ROOT/modules/dependencies/config/sources.toml" "$TEMP_DIR/config.good"
printf 'not = [valid\n' >"$ROOT/modules/dependencies/config/sources.toml"
run_deps status --json
[[ "$STATUS" -ne 0 ]] && pass "malformed source TOML fails closed" || fail "malformed source TOML fails closed" "nonzero" "$STATUS"
cp "$TEMP_DIR/config.good" "$ROOT/modules/dependencies/config/sources.toml"

sed 's|path = "projects/plugin-cli"|path = "../plugin-cli"|' "$TEMP_DIR/config.good" >"$ROOT/modules/dependencies/config/sources.toml"
run_deps status --json
if [[ "$STATUS" -ne 0 ]] && rg -q 'unsafe HOME-relative path' "$ERR"; then pass "local Git plugin paths cannot escape HOME"; else fail "local Git plugin paths cannot escape HOME" "unsafe path failure" "status=$STATUS err=$(cat "$ERR")"; fi
cp "$TEMP_DIR/config.good" "$ROOT/modules/dependencies/config/sources.toml"

sed 's/commit = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"/commit = "main"/' "$TEMP_DIR/config.good" >"$ROOT/modules/dependencies/config/sources.toml"
run_deps status --json
if [[ "$STATUS" -ne 0 ]] && rg -q 'invalid commit' "$ERR"; then pass "local Git plugins require immutable commit pins"; else fail "local Git plugins require immutable commit pins" "invalid commit failure" "status=$STATUS err=$(cat "$ERR")"; fi
cp "$TEMP_DIR/config.good" "$ROOT/modules/dependencies/config/sources.toml"

cp "$ROOT/modules/dependencies/dependencies.lock.json" "$TEMP_DIR/lock.good"
printf '{"schemaVersion":1,"dependencies":[]}\n' >"$ROOT/modules/dependencies/dependencies.lock.json"
run_deps status --json
[[ "$STATUS" -ne 0 ]] && pass "malformed lock shape fails closed" || fail "malformed lock shape fails closed" "nonzero" "$STATUS"
cp "$TEMP_DIR/lock.good" "$ROOT/modules/dependencies/dependencies.lock.json"

cp "$ROOT/modules/alpha/module.yaml" "$TEMP_DIR/module.good"
printf 'id: alpha\nrequires:\n  executables: nope\n' >"$ROOT/modules/alpha/module.yaml"
run_deps status --json
[[ "$STATUS" -ne 0 ]] && pass "malformed module YAML shape fails closed" || fail "malformed module YAML shape fails closed" "nonzero" "$STATUS"
cp "$TEMP_DIR/module.good" "$ROOT/modules/alpha/module.yaml"

cp "$ROOT/home/.chezmoiexternal.toml.tmpl" "$TEMP_DIR/externals.good"
cat >"$ROOT/home/.chezmoiexternal.toml.tmpl" <<'EOF'
["missing-url"]
type = "git-repo"
["valid-later"]
type = "git-repo"
url = "https://example.invalid/later.git"
EOF
run_deps status --json
if [[ "$STATUS" -ne 0 ]] && rg -q 'section-local URL' "$ERR"; then pass "static external URLs cannot bleed across table sections"; else fail "static external URLs cannot bleed across table sections" "section-local URL failure" "status=$STATUS err=$(cat "$ERR")"; fi
cp "$TEMP_DIR/externals.good" "$ROOT/home/.chezmoiexternal.toml.tmpl"

printf '\n================================\nResults: %d passed, %d failed\n================================\n' "$PASSED" "$FAILED"
[[ "$FAILED" -eq 0 ]]
