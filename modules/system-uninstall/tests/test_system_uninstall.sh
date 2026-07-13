#!/usr/bin/env bash
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
COMMAND="$REPO_ROOT/modules/system-uninstall/bin/dotfiles-uninstall"
TEMP="$(mktemp -d "${TMPDIR:-/tmp}/system-uninstall-test.XXXXXX")"
TEMP="$(cd -P "$TEMP" && pwd)"
ORIGINAL_PATH="$PATH"
PASSED=0
FAILED=0
trap 'rm -rf "$TEMP"' EXIT

pass() { printf '  ok - %s\n' "$1"; PASSED=$((PASSED + 1)); }
fail() { printf '  not ok - %s: %s\n' "$1" "$2"; FAILED=$((FAILED + 1)); }
assert_eq() { [[ "$1" == "$2" ]] && pass "$3" || fail "$3" "expected [$1], got [$2]"; }
assert_file() { [[ -f "$1" ]] && pass "$2" || fail "$2" "missing $1"; }
assert_missing() { [[ ! -e "$1" && ! -L "$1" ]] && pass "$2" || fail "$2" "unexpected $1"; }

setup_case() {
    local name="$1"
    CASE="$TEMP/$name"
    HOME_DIR="$CASE/home"
    SOURCE="$CASE/source"
    FAKE_BIN="$CASE/bin"
    STATE_HOME="$CASE/state-home"
    LEAVES="$CASE/leaves"
    DIRS="$CASE/dirs"
    CHANGED="$CASE/changed"
    REMOVE_LOG="$CASE/remove.log"
    TIMER_LOG="$CASE/timer.log"
    mkdir -p "$HOME_DIR/.config" "$HOME_DIR/bin" "$HOME_DIR/projects" \
        "$HOME_DIR/.local/state" "$HOME_DIR/.tmux/plugins" "$FAKE_BIN" \
        "$SOURCE/home/dot_local/lib/dotfiles" "$SOURCE/modules/system-uninstall" "$STATE_HOME"
    chmod 755 "$STATE_HOME"
    printf 'home\n' >"$SOURCE/.chezmoiroot"
    cp "$REPO_ROOT/home/dot_local/lib/dotfiles/core.sh" "$SOURCE/home/dot_local/lib/dotfiles/core.sh"
    cp "$REPO_ROOT/home/dot_local/lib/dotfiles/locks.sh" "$SOURCE/home/dot_local/lib/dotfiles/locks.sh"
    cp "$REPO_ROOT/modules/system-uninstall/module.yaml" "$SOURCE/modules/system-uninstall/module.yaml"

    printf 'user changed\n' >"$HOME_DIR/.config/changed"
    printf 'desired clean\n' >"$HOME_DIR/.config/clean"
    printf 'unmanaged\n' >"$HOME_DIR/.config/unmanaged"
    printf 'project\n' >"$HOME_DIR/projects/keep"
    printf 'module state\n' >"$HOME_DIR/.local/state/keep"
    printf 'plugin\n' >"$HOME_DIR/.tmux/plugins/keep"
    printf '%s\n' '.config/changed' '.config/clean' 'bin/agent-timer' \
        'bin/dotfiles-module' 'bin/dotfiles-uninstall' 'bin/project-link' >"$LEAVES"
    printf '%s\n' '.config' 'bin' >"$DIRS"
    printf '%s\n' '.config/changed' >"$CHANGED"

    cat >"$HOME_DIR/bin/agent-timer" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TIMER_LOG"
EOF
    printf '#!/usr/bin/env bash\nexit 0\n' >"$HOME_DIR/bin/dotfiles-module"
    printf '#!/usr/bin/env bash\nexit 0\n' >"$HOME_DIR/bin/dotfiles-uninstall"
    ln -s ../projects/keep "$HOME_DIR/bin/project-link"
    chmod +x "$HOME_DIR/bin/agent-timer" "$HOME_DIR/bin/dotfiles-module" "$HOME_DIR/bin/dotfiles-uninstall"

    cat >"$FAKE_BIN/chezmoi" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *"managed --include=files,symlinks"*) while IFS= read -r path; do printf '%s\0' "$path"; done <"$FAKE_LEAVES" ;;
  *"managed --include=dirs"*) while IFS= read -r path; do printf '%s\0' "$path"; done <"$FAKE_DIRS" ;;
  *"verify --"*)
    [[ "$*" == *"$HOME/.config/changed"* ]] && exit 1
    exit 0
    ;;
  *) printf 'unexpected chezmoi args: %s\n' "$*" >&2; exit 2 ;;
esac
EOF
    cat >"$FAKE_BIN/remove-one" <<'EOF'
#!/usr/bin/env bash
target="${!#}"
printf '%s\n' "$target" >>"$REMOVE_LOG"
if [[ -n "${FAIL_REMOVE_PATH:-}" && "$target" == "$HOME/$FAIL_REMOVE_PATH" ]]; then
  exit 19
fi
/bin/rm "$@"
EOF
    chmod +x "$FAKE_BIN/chezmoi" "$FAKE_BIN/remove-one"
    : >"$REMOVE_LOG"
    : >"$TIMER_LOG"
}

run_command() {
    HOME="$HOME_DIR" XDG_STATE_HOME="$STATE_HOME" DOTFILES_DIR="$SOURCE" \
        FAKE_LEAVES="$LEAVES" FAKE_DIRS="$DIRS" FAKE_CHANGED="$CHANGED" \
        TIMER_LOG="$TIMER_LOG" REMOVE_LOG="$REMOVE_LOG" \
        PATH="$FAKE_BIN:$ORIGINAL_PATH" "$COMMAND" "$@"
}

latest_run() {
    find "$STATE_HOME/dotfiles/system-uninstall/runs" -mindepth 1 -maxdepth 1 -type d | sort | tail -1
}

printf 'Testing read-only plan and exact confirmation...\n'
setup_case success
before=$(find "$HOME_DIR" -type f -exec shasum {} \; | sort)
if plan=$(run_command plan --json); then
    assert_eq 1 "$(jq -r '.schemaVersion' <<<"$plan")" "JSON plan exposes schema version 1"
    assert_eq system-uninstall "$(jq -r '.operation' <<<"$plan")" "JSON plan exposes stable operation"
    assert_eq 1 "$(jq '.changedTargets | length' <<<"$plan")" "changed target is surfaced"
    assert_eq true "$(jq -r '.executable' <<<"$plan")" "safe plan is executable"
    jq -e --arg state "$STATE_HOME" '.preserved | index($state)' <<<"$plan" >/dev/null \
        && pass "actual external XDG state home is preserved" || fail "actual external XDG state home is preserved" "$plan"
else
    fail "JSON plan succeeds" "command failed"
fi
after=$(find "$HOME_DIR" -type f -exec shasum {} \; | sort)
assert_eq "$before" "$after" "plan does not mutate disposable HOME"
if run_command execute --confirm wrong >/dev/null 2>&1; then fail "wrong confirmation is rejected" "execution succeeded"; else pass "wrong confirmation is rejected"; fi

printf '\nTesting symlinked state ancestry rejection...\n'
setup_case state-symlink
REAL_STATE="$CASE/real-state"
mkdir "$REAL_STATE"
rmdir "$STATE_HOME"
ln -s "$REAL_STATE" "$STATE_HOME"
if run_command execute --confirm "REMOVE DOTFILES FROM $(cd -P "$HOME_DIR" && pwd)" >/dev/null 2>&1; then
    fail "symlinked state ancestry is rejected" "execution succeeded"
else
    pass "symlinked state ancestry is rejected"
fi

printf '\nTesting backed-up execution...\n'
setup_case execute
if result=$(DOTFILES_UNINSTALL_REMOVE_BIN="$FAKE_BIN/remove-one" run_command execute \
    --confirm "REMOVE DOTFILES FROM $(cd -P "$HOME_DIR" && pwd)" --json); then
    RUN_DIR=$(latest_run)
    LEDGER="$RUN_DIR/ledger.json"
    assert_eq 1 "$(jq -r '.schemaVersion' <<<"$result")" "JSON execution result exposes schema version 1"
    assert_eq 1 "$(jq -r '.schemaVersion' "$LEDGER")" "durable ledger preserves schema version 1"
    assert_eq complete "$(jq -r '.status' "$LEDGER")" "successful removal has a complete ledger"
    assert_eq stopped "$(jq -r '.quiesce.agentTimer' "$LEDGER")" "agent timer is quiesced before removal"
    assert_file "$RUN_DIR/backup/.config/changed" "changed target is backed up"
    assert_file "$RUN_DIR/backup/.config/clean" "clean target is also snapshotted for exact restore"
    [[ -L "$RUN_DIR/backup/bin/project-link" ]] && pass "managed symlink is backed up without dereference" || fail "managed symlink is backed up without dereference" "backup is not a symlink"
    assert_eq 'user changed' "$(tr -d '\n' <"$RUN_DIR/backup/.config/changed")" "backup preserves changed content"
    assert_file "$RUN_DIR/plan.json" "plan snapshot is durable"
    assert_eq 1 "$(jq -r '.schemaVersion' "$RUN_DIR/plan.json")" "durable plan snapshot preserves schema version 1"
    assert_file "$RUN_DIR/manifests/system-uninstall.yaml" "manifest snapshot is durable"
    assert_eq 700 "$(stat -f '%Lp' "$RUN_DIR")" "run directory is private"
    assert_eq 600 "$(stat -f '%Lp' "$LEDGER")" "ledger is private"
    assert_eq 755 "$(stat -f '%Lp' "$STATE_HOME")" "pre-existing XDG state root mode is preserved"
    assert_missing "$HOME_DIR/.config/changed" "managed changed leaf is removed"
    assert_missing "$HOME_DIR/.config/clean" "managed clean leaf is removed"
    assert_missing "$HOME_DIR/bin/project-link" "managed symlink is unlinked"
    assert_missing "$HOME_DIR/bin" "empty managed directory is removed"
    assert_file "$HOME_DIR/.config/unmanaged" "unmanaged child keeps managed directory nonempty"
    assert_file "$HOME_DIR/projects/keep" "projects are preserved"
    assert_file "$HOME_DIR/.local/state/keep" "declared module state is preserved"
    assert_file "$HOME_DIR/.tmux/plugins/keep" "ambiguous plugin side effect is preserved"
    assert_eq 'shutdown --reason system-uninstall' "$(head -1 "$TIMER_LOG")" "quiesce command is exact"
    assert_eq "$HOME_DIR/bin/dotfiles-uninstall" "$(tail -1 "$REMOVE_LOG")" "installed uninstaller removes itself last"
    assert_eq "$HOME_DIR/bin/dotfiles-module" "$(tail -2 "$REMOVE_LOG" | head -1)" "lifecycle controller is removed immediately before uninstaller"
else
    fail "backed-up execution succeeds" "command failed"
fi

printf '\nTesting exact restore from preserved source...\n'
run_id=$(basename "$(latest_run)")
chmod 711 "$HOME_DIR/.config"
if restore=$(run_command restore "$run_id" --confirm "RESTORE DOTFILES TO $(cd -P "$HOME_DIR" && pwd)" --json); then
    LEDGER="$(latest_run)/ledger.json"
    assert_eq 1 "$(jq -r '.schemaVersion' <<<"$restore")" "JSON restore result preserves schema version 1"
    assert_eq complete "$(jq -r '.restoreStatus' "$LEDGER")" "restore completion is recorded"
    assert_eq 'user changed' "$(tr -d '\n' <"$HOME_DIR/.config/changed")" "restore recovers changed content"
    assert_eq 'desired clean' "$(tr -d '\n' <"$HOME_DIR/.config/clean")" "restore recovers clean content"
    assert_file "$HOME_DIR/bin/dotfiles-uninstall" "restore recovers installed uninstaller"
    assert_eq ../projects/keep "$(readlink "$HOME_DIR/bin/project-link")" "restore recovers managed symlink"
    assert_eq 711 "$(stat -f '%Lp' "$HOME_DIR/.config")" "restore preserves a post-uninstall directory mode"
    assert_eq enable "$(tail -1 "$TIMER_LOG")" "restore re-enables agent timer"
else
    fail "restore succeeds" "command failed"
fi

printf '\nTesting restore rejects a symlinked backup parent...\n'
/bin/rm -f "$HOME_DIR/.config/changed"
mv "$(latest_run)/backup/.config" "$(latest_run)/backup/.config-real"
ln -s .config-real "$(latest_run)/backup/.config"
if run_command restore "$run_id" --confirm "RESTORE DOTFILES TO $(cd -P "$HOME_DIR" && pwd)" >/dev/null 2>&1; then
    fail "symlinked backup parent is rejected" "restore succeeded"
else
    pass "symlinked backup parent is rejected"
fi
assert_missing "$HOME_DIR/.config/changed" "rejected backup is not copied"

printf '\nTesting durable partial failure and rollback...\n'
setup_case partial
if FAIL_REMOVE_PATH='.config/clean' DOTFILES_UNINSTALL_REMOVE_BIN="$FAKE_BIN/remove-one" \
    run_command execute --confirm "REMOVE DOTFILES FROM $(cd -P "$HOME_DIR" && pwd)" >/dev/null 2>&1; then
    fail "injected removal failure returns nonzero" "execution succeeded"
else
    pass "injected removal failure returns nonzero"
fi
RUN_DIR=$(latest_run)
LEDGER="$RUN_DIR/ledger.json"
assert_eq 1 "$(jq -r '.schemaVersion' "$LEDGER")" "failed ledger preserves schema version 1"
assert_eq failed "$(jq -r '.status' "$LEDGER")" "partial failure is durable in ledger"
assert_file "$RUN_DIR/failure.txt" "partial failure has a durable error marker"
assert_missing "$HOME_DIR/.config/changed" "earlier removal remains visible as partial progress"
assert_file "$HOME_DIR/.config/clean" "failed removal target is retained"
assert_file "$RUN_DIR/backup/.config/changed" "partial failure retains full backup"
run_id=$(basename "$RUN_DIR")
if run_command restore "$run_id" --confirm "RESTORE DOTFILES TO $(cd -P "$HOME_DIR" && pwd)" >/dev/null; then
    assert_file "$HOME_DIR/.config/changed" "restore rolls back an already-removed leaf"
    assert_file "$HOME_DIR/.config/clean" "restore preserves an untouched matching leaf"
    assert_eq complete "$(jq -r '.restoreStatus' "$LEDGER")" "partial run restore is recorded"
    assert_missing "$RUN_DIR/failure.txt" "successful restore clears failure marker"
else
    fail "partial run can be restored" "restore failed"
fi

printf '\n%s passed, %s failed\n' "$PASSED" "$FAILED"
[[ "$FAILED" -eq 0 ]]
