#!/usr/bin/env bash

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$TEST_DIR")"
TIMER="$MODULE_DIR/bin/agent-timer"
FIXTURES="$TEST_DIR/fixtures"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/agent-timer-test.XXXXXX")"
WORKER_PID=""

PASSED=0
FAILED=0

cleanup() {
    [[ -z "$WORKER_PID" ]] || kill "$WORKER_PID" 2>/dev/null || true
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

wait_for_state_value() {
    local file="$1" expression="$2" expected="$3"
    local attempt actual=""
    for attempt in {1..100}; do
        if [[ -f "$file" ]]; then
            actual="$(jq -r "$expression" "$file" 2>/dev/null || true)"
            [[ "$actual" == "$expected" ]] && return 0
        fi
        sleep 0.05
    done
    return 1
}

wait_for_process_exit() {
    local pid="$1" attempt
    for attempt in {1..100}; do
        kill -0 "$pid" 2>/dev/null || return 0
        sleep 0.05
    done
    return 1
}

export AGENT_TIMER_STATE_DIR="$TEMP_DIR/state"
export AGENT_TIMER_CONFIG_FILE="$TEMP_DIR/missing-config.toml"
export AGENT_TIMER_TMUX_BIN="$FIXTURES/tmux"
export AGENT_TIMER_SESH_BIN="$FIXTURES/sesh"
export AGENT_TIMER_PS_BIN="$FIXTURES/ps"
export AGENT_TIMER_CRONTAB_BIN="$FIXTURES/crontab"
export AGENT_TIMER_NOTIFIER_BIN="$FIXTURES/terminal-notifier"
export AGENT_TIMER_AFPLAY_BIN="$FIXTURES/afplay"
export AGENT_TIMER_SOUND_DIR="$TEMP_DIR/sounds"
export AGENT_TIMER_TEST_AGENT_PID="$$"
export AGENT_TIMER_NO_WORKER=1
export FAKE_TMUX_SNAPSHOT='$9|work|@1|%9|111|/dev/ttys999|node'
export FAKE_TMUX_LOG="$TEMP_DIR/tmux.log"
export FAKE_SESH_LOG="$TEMP_DIR/sesh.log"
export FAKE_NOTIFIER_LOG="$TEMP_DIR/notifier.log"
export FAKE_AFPLAY_LOG="$TEMP_DIR/afplay.log"
export FAKE_CRONTAB_STORE="$TEMP_DIR/crontab"
export FAKE_PS_COMMAND="node /example/bin/codex"
export FAKE_PS_STARTED="Sat Jul 11 12:00:00 2026"
export FAKE_SESH_JSON='[{"Src":"tmux","Name":"work","Path":"/tmp/work","Attached":0,"Windows":3},{"Src":"tmux","Name":"other","Path":"/tmp/other","Attached":1,"Windows":2}]'
: >"$FAKE_TMUX_LOG"
: >"$FAKE_NOTIFIER_LOG"
mkdir -p "$AGENT_TIMER_SOUND_DIR"
: >"$AGENT_TIMER_SOUND_DIR/Ping.aiff"
: >"$FAKE_AFPLAY_LOG"

printf '================================\n'
printf 'Agent Timer Tests\n'
printf '================================\n'

printf '\nTesting validation and immutable deadlines...\n'
if AGENT_TIMER_NOW=1000 "$TIMER" start --seconds nope --target %9 >/dev/null 2>"$TEMP_DIR/error"; then
    fail "invalid duration is rejected"
else
    assert_contains "$(cat "$TEMP_DIR/error")" "positive integer" "invalid duration is rejected clearly"
fi

state="$(AGENT_TIMER_NOW=1000 "$TIMER" start --seconds 100 --warning-seconds 20 --target %9 --id manual --turn-id turn-1 --json)"
assert_eq "1100" "$(jq -r '.deadlineAt' <<<"$state")" "deadline is computed from the supplied budget"
assert_eq "1080" "$(jq -r '.warningAt' <<<"$state")" "warning deadline is persisted"
assert_eq "work" "$(jq -r '.tmux.sessionName' <<<"$state")" "sesh session name is recorded"
assert_eq "$$" "$(jq -r '.agent.pid' <<<"$state")" "live agent process identity is recorded"

same="$(AGENT_TIMER_NOW=1010 "$TIMER" start --seconds 999 --warning-seconds 20 --target %9 --id manual --turn-id turn-1 --json)"
assert_eq "1100" "$(jq -r '.deadlineAt' <<<"$same")" "same-turn steering cannot reset the deadline"

next="$(AGENT_TIMER_NOW=1010 "$TIMER" start --seconds 50 --warning-seconds 10 --target %9 --id manual --turn-id turn-2 --json)"
assert_eq "1060" "$(jq -r '.deadlineAt' <<<"$next")" "a new turn receives a new deadline"
fingerprint_before="$(jq -c '{token,tmux,agent}' <<<"$next")"

printf '\nTesting exact warning and expiry steering...\n'
: >"$FAKE_TMUX_LOG"
AGENT_TIMER_NOW=1049 "$TIMER" tick
assert_eq "0" "$(wc -l <"$FAKE_TMUX_LOG" | tr -d ' ')" "timer stays quiet before warning"
AGENT_TIMER_NOW=1050 "$TIMER" tick
assert_eq "3" "$(wc -l <"$FAKE_TMUX_LOG" | tr -d ' ')" "warning types literal text, flushes the paste burst, and presses Enter"
assert_eq "0" "$(wc -l <"$FAKE_AFPLAY_LOG" | tr -d ' ')" "warning does not play the expiry sound"
AGENT_TIMER_NOW=1051 "$TIMER" tick
assert_eq "3" "$(wc -l <"$FAKE_TMUX_LOG" | tr -d ' ')" "warning is delivered only once"
export FAKE_TMUX_STATE_FILE="$AGENT_TIMER_STATE_DIR/manual.json"
export FAKE_TMUX_STATE_LOG="$TEMP_DIR/tmux-state-at-send.log"
: >"$FAKE_TMUX_STATE_LOG"
AGENT_TIMER_NOW=1060 "$TIMER" tick
assert_eq "6" "$(wc -l <"$FAKE_TMUX_LOG" | tr -d ' ')" "expiry adds one steer without interruption"
assert_eq "1" "$(wc -l <"$FAKE_AFPLAY_LOG" | tr -d ' ')" "expiry plays the configured sound exactly once"
assert_contains "$(cat "$FAKE_TMUX_LOG")" "send-keys -t %9 -l TASK CHECKPOINT DUE" "checkpoint message uses tmux literal input"
assert_contains "$(cat "$FAKE_TMUX_LOG")" "new 50s block is armed immediately" "checkpoint steer announces immediate re-arming"
assert_contains "$(cat "$FAKE_TMUX_LOG")" "continue open canonical tasks" "checkpoint steer continues open canonical tasks"
assert_contains "$(cat "$FAKE_TMUX_LOG")" "Delegate status collection to an available subagent" "checkpoint steer delegates non-blocking status collection"
assert_contains "$(cat "$FAKE_TMUX_LOG")" "commentary (not final)" "checkpoint steer keeps the root turn open"
assert_contains "$(cat "$FAKE_TMUX_LOG")" "If no subagent result is ready" "checkpoint steer has a timely no-slot fallback"
assert_eq "0" "$(grep -c 'kill-session' "$FAKE_TMUX_LOG" || true)" "warning and expiry never close the tmux session"
assert_eq "running:1110:1" "$(head -n 1 "$FAKE_TMUX_STATE_LOG")" "the next block is persisted before checkpoint steering"
assert_eq "running:1110:1:sent" "$(jq -r '[.status,.deadlineAt,.checkpointCount,.lastCheckpointDeliveryStatus] | map(tostring) | join(":")' "$AGENT_TIMER_STATE_DIR/manual.json")" "checkpoint delivery leaves the recurring timer armed"
assert_eq "$fingerprint_before" "$(jq -c '{token,tmux,agent}' "$AGENT_TIMER_STATE_DIR/manual.json")" "re-arming preserves the timer token and immutable fingerprints"
AGENT_TIMER_NOW=1060 "$TIMER" tick
assert_eq "6:1" "$(wc -l <"$FAKE_TMUX_LOG" | tr -d ' '):$(jq -r '.checkpointCount' "$AGENT_TIMER_STATE_DIR/manual.json")" "a worker/tick race cannot duplicate a checkpoint"
unset FAKE_TMUX_STATE_FILE FAKE_TMUX_STATE_LOG
AGENT_TIMER_NOW=1100 "$TIMER" tick
assert_eq "9" "$(wc -l <"$FAKE_TMUX_LOG" | tr -d ' ')" "the re-armed block reaches its own warning"

printf '\nTesting the Codex paste-burst submit boundary...\n'
AGENT_TIMER_NOW=1200 "$TIMER" start --seconds 100 --warning-seconds 20 --target %9 --id submit-boundary --turn-id boundary-turn --json >/dev/null
: >"$FAKE_TMUX_LOG"
AGENT_TIMER_NOW=1280 "$TIMER" tick
assert_eq "send-keys -t %9 End" "$(tail -n 2 "$FAKE_TMUX_LOG" | head -n 1)" "steering flushes Codex paste-burst state with a harmless End key"
assert_eq "send-keys -t %9 Enter" "$(tail -n 1 "$FAKE_TMUX_LOG")" "Enter remains the non-interrupting submit key"

printf '\nTesting stale panes and cancellation...\n'
AGENT_TIMER_NOW=2000 "$TIMER" start --seconds 100 --warning-seconds 20 --target %9 --id stale --json >/dev/null
export FAKE_TMUX_SNAPSHOT='$9|work|@1|%10|222|/dev/ttys998|node'
: >"$FAKE_TMUX_LOG"
AGENT_TIMER_NOW=2080 "$TIMER" tick
assert_eq "0" "$(wc -l <"$FAKE_TMUX_LOG" | tr -d ' ')" "reused pane never receives a stale steer"
assert_eq "stale" "$(jq -r '.status' "$AGENT_TIMER_STATE_DIR/stale.json")" "reused pane is surfaced as stale"
export FAKE_TMUX_SNAPSHOT='$9|work|@1|%9|111|/dev/ttys999|node'

AGENT_TIMER_NOW=3000 "$TIMER" start --seconds 100 --warning-seconds 20 --target %9 --id canceled --json >/dev/null
AGENT_TIMER_NOW=3010 "$TIMER" cancel --id canceled >/dev/null
: >"$FAKE_TMUX_LOG"
AGENT_TIMER_NOW=3100 "$TIMER" tick
assert_eq "0" "$(wc -l <"$FAKE_TMUX_LOG" | tr -d ' ')" "canceled timer never steers"
assert_eq "canceled" "$(jq -r '.status' "$AGENT_TIMER_STATE_DIR/canceled.json")" "cancellation is visible in state"

printf '\nTesting Codex hook behavior...\n'
hook_input='{"hook_event_name":"UserPromptSubmit","session_id":"session-a","turn_id":"turn-a","cwd":"/tmp/work"}'
unset TASK_TIMELIMIT_SECS
default_hook_input='{"hook_event_name":"UserPromptSubmit","session_id":"session-default","turn_id":"turn-default","cwd":"/tmp/work"}'
missing="$(TMUX_PANE=%9 AGENT_TIMER_NOW=4000 "$TIMER" hook <<<"$default_hook_input")"
assert_contains "$missing" "current 600s checkpoint block" "missing override uses the managed recurring 600-second default"
assert_contains "$(jq -r '.expiryMessage' "$AGENT_TIMER_STATE_DIR/codex-session-default.json")" "new 600s block is armed immediately" "default checkpoint steer names the newly armed 600-second block"

export TASK_TIMELIMIT_SECS=120
armed="$(TMUX_PANE=%9 AGENT_TIMER_NOW=4000 "$TIMER" hook <<<"$hook_input")"
assert_contains "$armed" "TASK TIMEBOX ACTIVE" "prompt hook injects the immutable deadline"
hook_deadline="$(jq -r '.deadlineAt' "$AGENT_TIMER_STATE_DIR/codex-session-a.json")"
TMUX_PANE=%9 AGENT_TIMER_NOW=4010 "$TIMER" hook <<<"$hook_input" >/dev/null
assert_eq "$hook_deadline" "$(jq -r '.deadlineAt' "$AGENT_TIMER_STATE_DIR/codex-session-a.json")" "in-flight user steer preserves hook deadline"

pretool='{"hook_event_name":"PreToolUse","session_id":"session-a","turn_id":"turn-a","cwd":"/tmp/work","tool_name":"Bash"}'
checkpointed="$(TMUX_PANE=%9 AGENT_TIMER_NOW=4120 "$TIMER" hook <<<"$pretool")"
assert_eq "none" "$(jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$checkpointed")" "checkpoint expiry never denies the next tool"
assert_contains "$checkpointed" "fresh 120s block" "PreToolUse receives the newly armed checkpoint context"
assert_eq "running:4240:1" "$(jq -r '[.status,.deadlineAt,.checkpointCount] | map(tostring) | join(":")' "$AGENT_TIMER_STATE_DIR/codex-session-a.json")" "PreToolUse re-arms before permitting continued work"

stop_input='{"hook_event_name":"Stop","session_id":"session-a","turn_id":"turn-a","cwd":"/tmp/work"}'
TMUX_PANE=%9 AGENT_TIMER_NOW=4121 "$TIMER" hook <<<"$stop_input" >/dev/null
assert_eq "completed" "$(jq -r '.status' "$AGENT_TIMER_STATE_DIR/codex-session-a.json")" "turn completion retires its timer"

printf '\nTesting sesh-backed durable session inventory...\n'
inventory="$(AGENT_TIMER_NOW=4121 "$TIMER" sessions --json)"
assert_eq "2" "$(jq 'length' <<<"$inventory")" "inventory comes from sesh tmux sessions"
assert_eq "1" "$(jq '[.[] | select(.name=="work")] | length' <<<"$inventory")" "sesh session names remain canonical"
assert_contains "$(AGENT_TIMER_NOW=4121 "$TIMER" sessions)" "SESSION" "human-readable session table is available"

AGENT_TIMER_NOW=4200 "$TIMER" start --seconds 100 --target %9 --id close-me --json >/dev/null
: >"$FAKE_TMUX_LOG"
AGENT_TIMER_NOW=4201 "$TIMER" close work --yes --force-active >/dev/null
assert_contains "$(cat "$FAKE_TMUX_LOG")" 'kill-session -t $9' "session close uses the immutable tmux ID after sesh validation"
assert_eq "closed" "$(jq -r '.status' "$AGENT_TIMER_STATE_DIR/close-me.json")" "closing a durable session retires its timers"

AGENT_TIMER_RETENTION_SECS=1 AGENT_TIMER_NOW=4300 "$TIMER" prune
if [[ ! -e "$AGENT_TIMER_STATE_DIR/close-me.json" ]]; then
    pass "terminal timer state is pruned after retention"
else
    fail "terminal timer state is pruned after retention" "state still exists"
fi

printf '\nTesting cron recovery installation...\n'
printf '15 3 * * * /usr/local/bin/unrelated\n' >"$FAKE_CRONTAB_STORE"
"$TIMER" install-cron >/dev/null
"$TIMER" install-cron >/dev/null
assert_eq "1" "$(grep -c 'agent-timer backstop' "$FAKE_CRONTAB_STORE")" "cron backstop installation is idempotent"
assert_contains "$(cat "$FAKE_CRONTAB_STORE")" "/usr/local/bin/unrelated" "cron installation preserves unrelated jobs"
"$TIMER" uninstall-cron >/dev/null
assert_eq "0" "$(grep -c 'agent-timer backstop' "$FAKE_CRONTAB_STORE" || true)" "cron backstop uninstalls cleanly"

printf '\nTesting workerless cron recovery across recurring blocks...\n'
export AGENT_TIMER_STATE_DIR="$TEMP_DIR/cron-state"
export AGENT_TIMER_NO_WORKER=1
: >"$FAKE_TMUX_LOG"
AGENT_TIMER_NOW=5000 "$TIMER" start --seconds 30 --warning-seconds 5 --target %9 --id cron-recovery --turn-id cron-turn --json >/dev/null
AGENT_TIMER_NOW=5030 "$TIMER" tick
assert_eq "1:5060:none" "$(jq -r '[.checkpointCount,.deadlineAt,(.worker.pid // "none")] | map(tostring) | join(":")' "$AGENT_TIMER_STATE_DIR/cron-recovery.json")" "cron recovery re-arms a block without creating a worker"
AGENT_TIMER_NOW=5060 "$TIMER" tick
assert_eq "2:5090:6" "$(jq -r '[.checkpointCount,.deadlineAt] | map(tostring) | join(":")' "$AGENT_TIMER_STATE_DIR/cron-recovery.json"):$(wc -l <"$FAKE_TMUX_LOG" | tr -d ' ')" "successive cron ticks continue the same recurring timer"

printf '\nTesting checkpoint delivery failure after re-arm...\n'
export AGENT_TIMER_STATE_DIR="$TEMP_DIR/delivery-failure-state"
export FAKE_TMUX_FAIL_SEND=1
: >"$FAKE_NOTIFIER_LOG"
AGENT_TIMER_NOW=6000 "$TIMER" start --seconds 30 --warning-seconds 5 --target %9 --id delivery-failure --turn-id failure-turn --json >/dev/null
AGENT_TIMER_NOW=6030 "$TIMER" tick
assert_eq "running:6060:1:failed" "$(jq -r '[.status,.deadlineAt,.checkpointCount,.lastCheckpointDeliveryStatus] | map(tostring) | join(":")' "$AGENT_TIMER_STATE_DIR/delivery-failure.json")" "failed steering never rolls back the newly armed block"
assert_contains "$(cat "$FAKE_NOTIFIER_LOG")" "Agent checkpoint delivery failed" "checkpoint delivery failure is surfaced"
unset FAKE_TMUX_FAIL_SEND

printf '\nTesting one exact worker across recurring blocks...\n'
export AGENT_TIMER_STATE_DIR="$TEMP_DIR/worker-state"
unset AGENT_TIMER_NO_WORKER AGENT_TIMER_NOW
: >"$FAKE_TMUX_LOG"
worker_state="$(AGENT_TIMER_WORKER_POLL_SECONDS=1 "$TIMER" start --seconds 2 --warning-seconds 1 --target %9 --id worker --turn-id worker-turn --json)"
WORKER_PID="$(jq -r '.worker.pid' <<<"$worker_state")"
if wait_for_state_value "$AGENT_TIMER_STATE_DIR/worker.json" '.lastCheckpointDeliveryStatus // ""' sent; then
    pass "detached worker reaches its first recurring checkpoint"
else
    fail "detached worker reaches its first recurring checkpoint" "checkpoint was not recorded"
fi
assert_eq "6" "$(wc -l <"$FAKE_TMUX_LOG" | tr -d ' ')" "one worker sends one warning and checkpoint for the first block"
assert_eq "running" "$(jq -r '.status' "$AGENT_TIMER_STATE_DIR/worker.json")" "the worker keeps the timer active after checkpoint delivery"
same_worker="$(AGENT_TIMER_WORKER_POLL_SECONDS=1 "$TIMER" start --seconds 99 --target %9 --id worker --turn-id worker-turn --json)"
assert_eq "$WORKER_PID" "$(jq -r '.worker.pid' <<<"$same_worker")" "same-turn hooks never create a duplicate recurring worker"
"$TIMER" cancel --id worker >/dev/null
if wait_for_process_exit "$WORKER_PID"; then
    pass "cancel terminates the recurring worker"
else
    fail "cancel terminates the recurring worker" "worker $WORKER_PID is still alive"
fi
WORKER_PID=""

printf '\nTesting chezmoi enable and uninstall lifecycle...\n'
DOTFILES_DIR="$(cd "$MODULE_DIR/../.." && pwd)"
DESTINATION="$TEMP_DIR/home"
CHEZMOI_STATE="$TEMP_DIR/chezmoi-state.db"
mkdir -p "$DESTINATION"
if chezmoi -S "$DOTFILES_DIR" -D "$DESTINATION" --persistent-state "$CHEZMOI_STATE" apply --exclude=scripts,externals --force >/dev/null; then
    pass "enabled profile applies to a clean home"
else
    fail "enabled profile applies to a clean home"
fi
if [[ -x "$DESTINATION/bin/agent-timer" ]]; then
    pass "enabled profile installs the global command"
else
    fail "enabled profile installs the global command" "missing executable"
fi
assert_contains "$(cat "$DESTINATION/.agents/AGENTS.md")" "Time-boxed Delivery" "enabled profile installs global agent behavior"
assert_contains "$(cat "$DESTINATION/.agents/AGENTS.md")" "Checkpoint expiry is never a termination condition" "enabled profile installs recurring checkpoint behavior"
assert_contains "$(cat "$DESTINATION/.agents/AGENTS.md")" "Never wait for checkpoint collection" "enabled profile installs non-blocking checkpoint delegation"
assert_contains "$(cat "$DESTINATION/.config/agent-timer/config.toml")" "default_seconds = 600" "enabled profile installs the global TOML budget"
assert_contains "$(cat "$DESTINATION/.config/agent-timer/config.toml")" 'expiry_sound = "Ping"' "enabled profile installs the expiry sound"
assert_contains "$(cat "$DESTINATION/.config/agent-timer/config.toml")" '"codex", "claude", "opencode"' "enabled profile prefers Codex first"
assert_contains "$(cat "$DESTINATION/.codex/hooks.json")" "UserPromptSubmit" "enabled profile installs Codex hooks"
assert_contains "$(cat "$DESTINATION/.codex/hooks.json")" "Arming recurring task checkpoint" "enabled profile installs recurring hook status"
assert_contains "$(cat "$DESTINATION/.tmux.conf")" "agent-timer manage" "enabled profile installs tmux lifecycle access"

if chezmoi -S "$DOTFILES_DIR" -D "$DESTINATION" --persistent-state "$CHEZMOI_STATE" --override-data '{"modules":{"agentTimer":{"enabled":false}}}' apply --exclude=scripts,externals --force >/dev/null; then
    pass "disabled profile reapplies cleanly"
else
    fail "disabled profile reapplies cleanly"
fi
if [[ ! -e "$DESTINATION/bin/agent-timer" ]]; then
    pass "disabled profile removes the global command"
else
    fail "disabled profile removes the global command" "target still exists"
fi
if [[ ! -e "$DESTINATION/.codex/hooks.json" ]]; then
    pass "disabled profile removes Codex hooks"
else
    fail "disabled profile removes Codex hooks" "target still exists"
fi
if [[ ! -e "$DESTINATION/.config/agent-timer/config.toml" ]]; then
    pass "disabled profile removes the global timer configuration"
else
    fail "disabled profile removes the global timer configuration" "target still exists"
fi
if ! grep -q 'Time-boxed Delivery' "$DESTINATION/.agents/AGENTS.md"; then
    pass "disabled profile removes global timer behavior"
else
    fail "disabled profile removes global timer behavior" "policy still rendered"
fi
if ! grep -q 'agent-timer manage' "$DESTINATION/.tmux.conf"; then
    pass "disabled profile removes tmux lifecycle access"
else
    fail "disabled profile removes tmux lifecycle access" "binding still rendered"
fi
if yq eval '.' "$DESTINATION/.config/tmux/which-key.yaml" >/dev/null 2>&1; then
    pass "disabled profile preserves valid command-center YAML"
else
    fail "disabled profile preserves valid command-center YAML" "parse error"
fi

printf '\nResults: %d passed, %d failed\n' "$PASSED" "$FAILED"
[[ "$FAILED" -eq 0 ]]
