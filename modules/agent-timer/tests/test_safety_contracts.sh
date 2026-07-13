#!/usr/bin/env bash

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$TEST_DIR")"
REPO_DIR="$(cd "$MODULE_DIR/../.." && pwd)"
TIMER="$MODULE_DIR/bin/agent-timer"
FIXTURES="$TEST_DIR/safety-fixtures"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/agent-timer-safety.XXXXXX")"
REAL_PS="$(command -v ps)"

PASSED=0
FAILED=0
AGENT_PID=""
TRACKED_PIDS=()

cleanup() {
    local pid
    for pid in "${TRACKED_PIDS[@]}"; do
        [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
    done
    if [[ -n "$AGENT_PID" ]]; then
        kill "$AGENT_PID" 2>/dev/null || true
        wait "$AGENT_PID" 2>/dev/null || true
    fi
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

pass() {
    printf '  ✓ %s\n' "$1"
    PASSED=$((PASSED + 1))
}

fail() {
    printf '  ✗ %s\n' "$1"
    [[ -z "${2:-}" ]] || printf '    %s\n' "$2"
    FAILED=$((FAILED + 1))
}

assert_eq() {
    local expected="$1" actual="$2" name="$3"
    if [[ "$actual" == "$expected" ]]; then
        pass "$name"
    else
        fail "$name" "expected '$expected', got '$actual'"
    fi
}

assert_contains() {
    local value="$1" pattern="$2" name="$3"
    if grep -q -- "$pattern" <<<"$value"; then
        pass "$name"
    else
        fail "$name" "missing pattern '$pattern'"
    fi
}

process_exists() {
    local pid="$1"
    local state
    [[ -n "$pid" ]] || return 1
    state="$($REAL_PS -p "$pid" -o stat= 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)"
    [[ -n "$state" && "$state" != Z* ]]
}

wait_for_exit() {
    local pid="$1"
    local attempt
    for attempt in {1..60}; do
        process_exists "$pid" || return 0
        sleep 0.05
    done
    return 1
}

wait_for_sleep_child() {
    local parent="$1"
    local attempt child command_line
    for attempt in {1..60}; do
        while IFS= read -r child; do
            [[ -n "$child" ]] || continue
            command_line="$($REAL_PS -p "$child" -o command= 2>/dev/null || true)"
            case "$command_line" in
                sleep|sleep\ *|*/sleep|*/sleep\ *)
                    printf '%s\n' "$child"
                    return 0
                    ;;
            esac
        done < <("$REAL_PS" -axo pid=,ppid= | awk -v parent="$parent" '$2 == parent { print $1 }')
        sleep 0.05
    done
    return 1
}

wait_for_state() {
    local file="$1"
    local expression="$2"
    local attempt
    for attempt in {1..160}; do
        if [[ -f "$file" ]] && jq -e "$expression" "$file" >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.05
    done
    return 1
}

wait_for_file_content() {
    local file="$1"
    local attempt
    for attempt in {1..60}; do
        [[ -s "$file" ]] && return 0
        sleep 0.05
    done
    return 1
}

reset_case() {
    local name="$1"
    export AGENT_TIMER_STATE_DIR="$TEMP_DIR/state/$name"
    export FAKE_TMUX_LOG="$TEMP_DIR/$name.tmux.log"
    export FAKE_TMUX_RUN_SHELL_LOG="$TEMP_DIR/$name.run-shell.log"
    export FAKE_TMUX_RUN_SHELL_STATUS_LOG="$TEMP_DIR/$name.run-shell-status.log"
    mkdir -p "$AGENT_TIMER_STATE_DIR"
    : >"$FAKE_TMUX_LOG"
    : >"$FAKE_TMUX_RUN_SHELL_LOG"
    : >"$FAKE_TMUX_RUN_SHELL_STATUS_LOG"
    export FAKE_TMUX_SNAPSHOT="\$9|work|@1|%9|$$|/dev/ttys999|zsh"
    export FAKE_TMUX_PANES="\$9|work|@1|%9|$$|/dev/ttys999|zsh|/tmp/work"
    export FAKE_SESH_JSON='[{"Src":"tmux","Name":"work","Path":"/tmp/work","Attached":0,"Windows":3},{"Src":"tmux","Name":"other","Path":"/tmp/other","Attached":1,"Windows":2}]'
    export AGENT_TIMER_NO_WORKER=1
    unset AGENT_TIMER_NOW
}

export AGENT_TIMER_TMUX_BIN="$FIXTURES/tmux"
export AGENT_TIMER_SESH_BIN="$FIXTURES/sesh"
export AGENT_TIMER_PS_BIN="$REAL_PS"
export AGENT_TIMER_NOTIFIER_BIN="/usr/bin/true"
export AGENT_TIMER_CONFIG_FILE="$TEMP_DIR/missing-config.toml"
export DOTFILES_LIB_DIR="$REPO_DIR/home/dot_local/lib/dotfiles"

# A real descendant with a supported executable name keeps process identity,
# start-time, child traversal, and worker shutdown assertions honest.
cp "$(command -v sleep)" "$TEMP_DIR/codex"
chmod +x "$TEMP_DIR/codex"
"$TEMP_DIR/codex" 300 &
AGENT_PID=$!

printf '================================\n'
printf 'Agent Timer Safety Contracts\n'
printf '================================\n'

printf '\nTesting stale lock recovery...\n'
reset_case stale-lock
dead_pid=99999999
while kill -0 "$dead_pid" 2>/dev/null; do
    dead_pid=$((dead_pid + 1))
done
mkdir "$AGENT_TIMER_STATE_DIR/session-_9.lock" "$AGENT_TIMER_STATE_DIR/stale-lock.lock"
printf '%s\n' "$dead_pid" >"$AGENT_TIMER_STATE_DIR/session-_9.lock/pid"
printf '%s\n' "$dead_pid" >"$AGENT_TIMER_STATE_DIR/stale-lock.lock/pid"
if stale_state="$(AGENT_TIMER_NOW=1000 "$TIMER" start --seconds 100 --warning-seconds 20 --target %9 --id stale-lock --turn-id turn-1 --json 2>"$TEMP_DIR/stale-lock.err")"; then
    assert_eq "running" "$(jq -r '.status' <<<"$stale_state")" "dead session and state locks are reaped before arming"
    assert_eq "0" "$(find "$AGENT_TIMER_STATE_DIR" -maxdepth 1 -type d -name '*.lock' | wc -l | tr -d ' ')" "recovered locks are released after the write"
else
    fail "dead session and state locks are reaped before arming" "$(cat "$TEMP_DIR/stale-lock.err")"
fi

printf '\nTesting replacement-turn isolation...\n'
reset_case replacement-turn
old_prompt='{"hook_event_name":"UserPromptSubmit","session_id":"replace","turn_id":"turn-old","cwd":"/tmp/work"}'
new_prompt='{"hook_event_name":"UserPromptSubmit","session_id":"replace","turn_id":"turn-new","cwd":"/tmp/work"}'
old_stop='{"hook_event_name":"Stop","session_id":"replace","turn_id":"turn-old","cwd":"/tmp/work"}'
old_pretool='{"hook_event_name":"PreToolUse","session_id":"replace","turn_id":"turn-old","cwd":"/tmp/work","tool_name":"Bash"}'
TMUX_PANE=%9 TASK_TIMELIMIT_SECS=10 AGENT_TIMER_NOW=1100 "$TIMER" hook <<<"$old_prompt" >/dev/null
AGENT_TIMER_NOW=1101 "$TIMER" cancel --id codex-replace >/dev/null
TMUX_PANE=%9 TASK_TIMELIMIT_SECS=100 AGENT_TIMER_NOW=1102 "$TIMER" hook <<<"$new_prompt" >/dev/null
old_pretool_result="$(TMUX_PANE=%9 AGENT_TIMER_NOW=1111 "$TIMER" hook <<<"$old_pretool")"
TMUX_PANE=%9 AGENT_TIMER_NOW=1112 "$TIMER" hook <<<"$old_stop" >/dev/null
replacement_state="$(cat "$AGENT_TIMER_STATE_DIR/codex-replace.json")"
old_pretool_json="$old_pretool_result"
[[ -n "$old_pretool_json" ]] || old_pretool_json='{}'
assert_eq "none" "$(jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$old_pretool_json")" "a canceled old turn cannot deny tools in its replacement"
assert_eq "turn-new:running" "$(jq -r '[.turnId,.status] | join(":")' <<<"$replacement_state")" "an old Stop event cannot complete its replacement turn"

printf '\nTesting mutable tmux metadata...\n'
reset_case mutable-tmux
AGENT_TIMER_NOW=2000 "$TIMER" start --seconds 100 --warning-seconds 20 --target %9 --id mutable --turn-id turn-1 --json >/dev/null
export FAKE_TMUX_SNAPSHOT="\$9|renamed-work|@1|%9|$$|/dev/ttys999|bash"
: >"$FAKE_TMUX_LOG"
AGENT_TIMER_NOW=2080 "$TIMER" tick
assert_eq "3" "$(wc -l <"$FAKE_TMUX_LOG" | tr -d ' ')" "session rename and pane command change do not suppress a valid steer"
assert_eq "warning" "$(jq -r '.status' "$AGENT_TIMER_STATE_DIR/mutable.json")" "mutable tmux metadata does not mark the target stale"

printf '\nTesting active-agent inventory and close protection...\n'
reset_case active-session
inventory="$(AGENT_TIMER_NOW=2100 "$TIMER" sessions --json 2>"$TEMP_DIR/inventory.err")"
assert_eq "1" "$(jq --argjson pid "$AGENT_PID" '[.[] | select(.name == "work") | .agents[]? | select(.kind == "codex" and .pid == $pid)] | length' <<<"${inventory:-[]}" 2>/dev/null || printf invalid)" "sessions JSON exposes the live Codex process in its sesh session"

: >"$FAKE_TMUX_LOG"
if close_error="$(AGENT_TIMER_NOW=2101 "$TIMER" close work --yes 2>&1)"; then
    fail "non-interactive close refuses a session with live agents" "close unexpectedly succeeded"
else
    assert_contains "$close_error" "--force-active" "non-interactive close explains the active-session override"
fi
assert_eq "0" "$(grep -c 'kill-session' "$FAKE_TMUX_LOG" || true)" "refused active-session close never reaches tmux"

unknown_inventory="$(AGENT_TIMER_PS_BIN=/usr/bin/false AGENT_TIMER_NOW=2101 "$TIMER" sessions --json)"
assert_eq "true" "$(jq -r '.[] | select(.name == "work") | .activityUnknown' <<<"$unknown_inventory")" "process-scan failures are surfaced instead of looking idle"
if unknown_close="$(AGENT_TIMER_PS_BIN=/usr/bin/false AGENT_TIMER_NOW=2101 "$TIMER" close work --yes 2>&1)"; then
    fail "unknown activity fails closed during session close" "close unexpectedly succeeded"
else
    assert_contains "$unknown_close" "--force-active" "unknown activity fails closed during session close"
fi

: >"$FAKE_TMUX_LOG"
if AGENT_TIMER_NOW=2102 "$TIMER" close work --yes --force-active >"$TEMP_DIR/force-active.out" 2>"$TEMP_DIR/force-active.err"; then
    assert_eq "1" "$(grep -c 'kill-session' "$FAKE_TMUX_LOG" || true)" "--force-active permits the explicitly requested close"
else
    fail "--force-active permits the explicitly requested close" "$(cat "$TEMP_DIR/force-active.err")"
fi

printf '\nTesting pane-root agent discovery...\n'
reset_case pane-root-agent
export FAKE_TMUX_SNAPSHOT="\$9|work|@1|%9|$AGENT_PID|/dev/ttys999|codex"
export FAKE_TMUX_PANES="\$9|work|@1|%9|$AGENT_PID|/dev/ttys999|codex|/tmp/work"
root_state="$(AGENT_TIMER_NOW=2150 "$TIMER" start --seconds 60 --target %9 --id pane-root --turn-id turn-root --json)"
assert_eq "$AGENT_PID" "$(jq -r '.agent.pid' <<<"$root_state")" "an agent running as pane_pid is detected"

printf '\nTesting cancellation of a sleeping worker...\n'
reset_case worker-cancel
unset AGENT_TIMER_NO_WORKER
worker_state="$("$TIMER" start --seconds 60 --warning-seconds 5 --target %9 --id worker-cancel --turn-id turn-1 --json)"
worker_pid="$(jq -r '.worker.pid // empty' <<<"$worker_state")"
[[ -n "$worker_pid" ]] && TRACKED_PIDS+=("$worker_pid")
sleep_pid="$(wait_for_sleep_child "$worker_pid" || true)"
[[ -n "$sleep_pid" ]] && TRACKED_PIDS+=("$sleep_pid")
if [[ -n "$sleep_pid" ]]; then
    pass "worker exposes its interruptible sleep child"
else
    fail "worker exposes its interruptible sleep child" "no sleep child appeared for worker $worker_pid"
fi
if "$TIMER" cancel --id worker-cancel >"$TEMP_DIR/worker-cancel.out" 2>"$TEMP_DIR/worker-cancel.err"; then
    if wait_for_exit "$worker_pid" && { [[ -z "$sleep_pid" ]] || wait_for_exit "$sleep_pid"; }; then
        pass "cancel terminates both the worker and its sleep child"
    else
        fail "cancel terminates both the worker and its sleep child" "worker=$worker_pid sleep=$sleep_pid still present"
    fi
else
    fail "cancel terminates both the worker and its sleep child" "$(cat "$TEMP_DIR/worker-cancel.err")"
fi
assert_eq "canceled" "$(jq -r '.status' "$AGENT_TIMER_STATE_DIR/worker-cancel.json")" "worker cancellation records a terminal state"
if wait_for_file_content "$FAKE_TMUX_RUN_SHELL_STATUS_LOG"; then
    assert_eq "0" "$(tail -n 1 "$FAKE_TMUX_RUN_SHELL_STATUS_LOG")" "intentional worker shutdown exits cleanly under tmux"
else
    fail "intentional worker shutdown exits cleanly under tmux" "tmux-owned worker status was not recorded"
fi

printf '\nTesting Codex Stop cleanup of a sleeping worker...\n'
reset_case worker-stop
unset AGENT_TIMER_NO_WORKER
stop_state="$("$TIMER" start --seconds 60 --warning-seconds 5 --target %9 --id codex-worker-stop --turn-id turn-stop --json)"
stop_worker_pid="$(jq -r '.worker.pid // empty' <<<"$stop_state")"
[[ -n "$stop_worker_pid" ]] && TRACKED_PIDS+=("$stop_worker_pid")
stop_fingerprint="$(jq -c '{token,deadlineAt,worker}' <<<"$stop_state")"
subagent_input='{"hook_event_name":"SubagentStart","session_id":"worker-stop","turn_id":"turn-stop","cwd":"/tmp/work"}'
subagent_context="$(TMUX_PANE=%9 "$TIMER" hook <<<"$subagent_input")"
assert_contains "$subagent_context" "TASK TIMEBOX ACTIVE" "checkpoint subagent inherits the active block context"
assert_eq "$stop_fingerprint" "$(jq -c '{token,deadlineAt,worker}' "$AGENT_TIMER_STATE_DIR/codex-worker-stop.json")" "checkpoint subagent does not reset the root timer"
assert_eq "1" "$(wc -l <"$FAKE_TMUX_RUN_SHELL_LOG" | tr -d ' ')" "checkpoint subagent does not launch another worker"
stop_input='{"hook_event_name":"Stop","session_id":"worker-stop","turn_id":"turn-stop","cwd":"/tmp/work"}'
TMUX_PANE=%9 "$TIMER" hook <<<"$stop_input" >"$TEMP_DIR/worker-stop.out"
if wait_for_exit "$stop_worker_pid"; then
    pass "Codex Stop terminates its tmux-owned timer worker"
else
    fail "Codex Stop terminates its tmux-owned timer worker" "worker=$stop_worker_pid still present"
fi
assert_eq "completed" "$(jq -r '.status' "$AGENT_TIMER_STATE_DIR/codex-worker-stop.json")" "Codex Stop records completed timer state"
if wait_for_file_content "$FAKE_TMUX_RUN_SHELL_STATUS_LOG"; then
    assert_eq "0" "$(tail -n 1 "$FAKE_TMUX_RUN_SHELL_STATUS_LOG")" "Codex Stop worker cleanup is silent under tmux"
else
    fail "Codex Stop worker cleanup is silent under tmux" "tmux-owned worker status was not recorded"
fi

printf '\nTesting tmux-owned recurrence across a real warning and checkpoint...\n'
reset_case worker-recurrence
unset AGENT_TIMER_NO_WORKER
recurring_state="$(AGENT_TIMER_WORKER_POLL_SECONDS=1 AGENT_TIMER_EXPIRY_SOUND=none \
    "$TIMER" start --seconds 4 --warning-seconds 2 --target %9 --id worker-recurrence --turn-id turn-1 --json)"
recurring_worker_pid="$(jq -r '.worker.pid // empty' <<<"$recurring_state")"
recurring_first_deadline="$(jq -r '.deadlineAt' <<<"$recurring_state")"
TRACKED_PIDS+=("$recurring_worker_pid")
assert_eq "ready" "$(jq -r '.workerLaunchStatus // empty' <<<"$recurring_state")" "tmux-owned worker self-registers before start returns"
assert_eq "1" "$(wc -l <"$FAKE_TMUX_RUN_SHELL_LOG" | tr -d ' ')" "one tmux server launch owns the recurring worker"
if wait_for_state "$AGENT_TIMER_STATE_DIR/worker-recurrence.json" '.status == "warning" and (.warningSentAt > 0)'; then
    pass "real worker reaches warning state"
else
    fail "real worker reaches warning state" "warning was not observed before expiry"
fi
if process_exists "$recurring_worker_pid"; then
    pass "same worker remains alive after warning"
else
    fail "same worker remains alive after warning" "worker $recurring_worker_pid exited at warning"
fi
if wait_for_state "$AGENT_TIMER_STATE_DIR/worker-recurrence.json" '.checkpointCount == 1 and .status == "running" and .lastCheckpointDeliveryStatus == "sent"'; then
    pass "real worker advances warning into a recurring checkpoint"
else
    fail "real worker advances warning into a recurring checkpoint" "checkpointCount did not advance"
fi
recurring_after="$(cat "$AGENT_TIMER_STATE_DIR/worker-recurrence.json")"
assert_eq "$recurring_worker_pid" "$(jq -r '.worker.pid // empty' <<<"$recurring_after")" "next block preserves the exact registered worker"
if process_exists "$recurring_worker_pid"; then
    pass "registered worker remains alive in the next block"
else
    fail "registered worker remains alive in the next block" "worker $recurring_worker_pid is not live"
fi
if [[ "$(jq -r '.deadlineAt' <<<"$recurring_after")" -gt "$recurring_first_deadline" ]]; then
    pass "checkpoint installs a later next-block deadline"
else
    fail "checkpoint installs a later next-block deadline" "first=$recurring_first_deadline next=$(jq -r '.deadlineAt' <<<"$recurring_after")"
fi
if ! "$TIMER" cancel --id worker-recurrence >"$TEMP_DIR/worker-recurrence.cancel.out" 2>"$TEMP_DIR/worker-recurrence.cancel.err"; then
    fail "cancel command accepts the tmux-owned recurring worker" "$(cat "$TEMP_DIR/worker-recurrence.cancel.err")"
fi
if wait_for_exit "$recurring_worker_pid"; then
    pass "cancel still terminates the tmux-owned recurring worker"
else
    fail "cancel still terminates the tmux-owned recurring worker" "worker $recurring_worker_pid is still alive; cancel=$(cat "$TEMP_DIR/worker-recurrence.cancel.err"); state=$(jq -c '{status,worker}' "$AGENT_TIMER_STATE_DIR/worker-recurrence.json"); process=$($REAL_PS -p "$recurring_worker_pid" -o pid=,ppid=,stat=,lstart=,command= 2>/dev/null || true)"
fi

printf '\nTesting same-turn recovery of a dead registered worker...\n'
reset_case worker-relaunch
unset AGENT_TIMER_NO_WORKER
relaunch_before="$(AGENT_TIMER_WORKER_POLL_SECONDS=1 "$TIMER" start --seconds 60 --warning-seconds 5 --target %9 --id worker-relaunch --turn-id same-turn --json)"
dead_worker_pid="$(jq -r '.worker.pid' <<<"$relaunch_before")"
TRACKED_PIDS+=("$dead_worker_pid")
kill "$dead_worker_pid" 2>/dev/null || true
wait_for_exit "$dead_worker_pid" || true
relaunch_after="$(AGENT_TIMER_WORKER_POLL_SECONDS=1 "$TIMER" start --seconds 999 --warning-seconds 5 --target %9 --id worker-relaunch --turn-id same-turn --json)"
replacement_worker_pid="$(jq -r '.worker.pid' <<<"$relaunch_after")"
TRACKED_PIDS+=("$replacement_worker_pid")
assert_eq "$(jq -r '.token' <<<"$relaunch_before")" "$(jq -r '.token' <<<"$relaunch_after")" "dead-worker repair preserves the same turn token"
assert_eq "$(jq -r '.deadlineAt' <<<"$relaunch_before")" "$(jq -r '.deadlineAt' <<<"$relaunch_after")" "dead-worker repair preserves the immutable block deadline"
if [[ "$replacement_worker_pid" != "$dead_worker_pid" ]] && process_exists "$replacement_worker_pid"; then
    pass "same-turn reuse replaces a dead registered worker"
else
    fail "same-turn reuse replaces a dead registered worker" "old=$dead_worker_pid replacement=$replacement_worker_pid"
fi
assert_eq "2" "$(wc -l <"$FAKE_TMUX_RUN_SHELL_LOG" | tr -d ' ')" "dead-worker repair schedules exactly one replacement launch"
"$TIMER" cancel --id worker-relaunch >/dev/null 2>&1 || true
wait_for_exit "$replacement_worker_pid" || true

printf '\nTesting worker-registration timeout containment...\n'
reset_case worker-timeout
unset AGENT_TIMER_NO_WORKER
export FAKE_TMUX_DROP_RUN_SHELL=1
if timeout_error="$(AGENT_TIMER_WORKER_REGISTRATION_ATTEMPTS=2 "$TIMER" start --seconds 60 --warning-seconds 5 --target %9 --id worker-timeout --turn-id timeout-turn --json 2>&1)"; then
    fail "unregistered tmux launch fails start" "start unexpectedly succeeded"
else
    assert_contains "$timeout_error" "did not register" "unregistered tmux launch fails start"
fi
unset FAKE_TMUX_DROP_RUN_SHELL
assert_eq "canceled:timeout" "$(jq -r '[.status,.workerLaunchStatus] | join(":")' "$AGENT_TIMER_STATE_DIR/worker-timeout.json")" "registration timeout leaves terminal state"
assert_eq "none" "$(jq -r '.worker.pid // "none"' "$AGENT_TIMER_STATE_DIR/worker-timeout.json")" "registration timeout leaves no registered orphan"

printf '\nTesting recurring-worker retirement after agent exit...\n'
reset_case worker-agent-exit
unset AGENT_TIMER_NO_WORKER
"$TEMP_DIR/codex" 300 &
EXIT_AGENT_PID=$!
TRACKED_PIDS+=("$EXIT_AGENT_PID")
export FAKE_TMUX_SNAPSHOT="\$9|work|@1|%9|$EXIT_AGENT_PID|/dev/ttys999|codex"
export FAKE_TMUX_PANES="\$9|work|@1|%9|$EXIT_AGENT_PID|/dev/ttys999|codex|/tmp/work"
exit_state="$(AGENT_TIMER_WORKER_POLL_SECONDS=1 "$TIMER" start --seconds 60 --warning-seconds 5 --target %9 --id worker-agent-exit --turn-id turn-exit --json)"
exit_worker_pid="$(jq -r '.worker.pid // empty' <<<"$exit_state")"
TRACKED_PIDS+=("$exit_worker_pid")
exit_sleep_pid="$(wait_for_sleep_child "$exit_worker_pid" || true)"
[[ -n "$exit_sleep_pid" ]] && TRACKED_PIDS+=("$exit_sleep_pid")
kill "$EXIT_AGENT_PID" 2>/dev/null || true
wait "$EXIT_AGENT_PID" 2>/dev/null || true
if wait_for_exit "$exit_worker_pid"; then
    pass "recurring worker exits after its fingerprinted agent ends"
else
    fail "recurring worker exits after its fingerprinted agent ends" "worker $exit_worker_pid is still alive"
fi
assert_eq "stale" "$(jq -r '.status' "$AGENT_TIMER_STATE_DIR/worker-agent-exit.json")" "agent exit retires recurring state instead of leaving an orphan"

printf '\nTesting global shutdown of active workers...\n'
reset_case shutdown
unset AGENT_TIMER_NO_WORKER
shutdown_one="$("$TIMER" start --seconds 60 --warning-seconds 5 --target %9 --id shutdown-one --turn-id turn-1 --json)"
shutdown_two="$("$TIMER" start --seconds 60 --warning-seconds 5 --target %9 --id shutdown-two --turn-id turn-1 --json)"
shutdown_worker_one="$(jq -r '.worker.pid // empty' <<<"$shutdown_one")"
shutdown_worker_two="$(jq -r '.worker.pid // empty' <<<"$shutdown_two")"
TRACKED_PIDS+=("$shutdown_worker_one" "$shutdown_worker_two")
shutdown_sleep_one="$(wait_for_sleep_child "$shutdown_worker_one" || true)"
shutdown_sleep_two="$(wait_for_sleep_child "$shutdown_worker_two" || true)"
[[ -n "$shutdown_sleep_one" ]] && TRACKED_PIDS+=("$shutdown_sleep_one")
[[ -n "$shutdown_sleep_two" ]] && TRACKED_PIDS+=("$shutdown_sleep_two")
if "$TIMER" shutdown --reason safety-test >"$TEMP_DIR/shutdown.out" 2>"$TEMP_DIR/shutdown.err"; then
    workers_gone=1
    for pid in "$shutdown_worker_one" "$shutdown_worker_two" "$shutdown_sleep_one" "$shutdown_sleep_two"; do
        [[ -z "$pid" ]] && continue
        wait_for_exit "$pid" || workers_gone=0
    done
    assert_eq "1" "$workers_gone" "shutdown terminates every active worker and sleep child"
    assert_eq "2" "$(jq -s '[.[] | select(.status == "disabled")] | length' "$AGENT_TIMER_STATE_DIR"/*.json)" "shutdown retires every active timer as disabled"
    assert_eq "present" "$([[ -f "$AGENT_TIMER_STATE_DIR/module-disabled" ]] && printf present || printf missing)" "shutdown latches the module disabled before releasing its lock"
    if blocked_start="$(AGENT_TIMER_NO_WORKER=1 "$TIMER" start --seconds 60 --target %9 --id blocked-rearm --json 2>&1)"; then
        fail "the disabled latch blocks post-shutdown re-arming" "start unexpectedly succeeded"
    else
        assert_contains "$blocked_start" "disabled" "the disabled latch blocks post-shutdown re-arming"
    fi
    "$TIMER" enable >/dev/null
    reenabled_state="$(AGENT_TIMER_NO_WORKER=1 "$TIMER" start --seconds 60 --target %9 --id reenabled --json)"
    assert_eq "running" "$(jq -r '.status' <<<"$reenabled_state")" "explicit enable clears the latch for a future turn"
else
    fail "shutdown terminates every active worker and sleep child" "$(cat "$TEMP_DIR/shutdown.err")"
    fail "shutdown retires every active timer as disabled" "shutdown command failed"
fi

printf '\nResults: %d passed, %d failed\n' "$PASSED" "$FAILED"
[[ "$FAILED" -eq 0 ]]
