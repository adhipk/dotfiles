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

wait_for_file_content() {
    local file="$1" attempt
    for attempt in {1..100}; do
        [[ -s "$file" ]] && return 0
        sleep 0.05
    done
    return 1
}

wait_for_file_pattern() {
    local file="$1" pattern="$2" attempt
    for attempt in {1..100}; do
        if [[ -f "$file" ]] && grep -q -- "$pattern" "$file"; then
            return 0
        fi
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
export FAKE_CODEX_LOG="$TEMP_DIR/codex.log"
HOOK_CWD="$TEMP_DIR/work"
mkdir -p "$HOOK_CWD"
mkdir -p "$TEMP_DIR/fake-codex-bin"
cat >"$TEMP_DIR/fake-codex-bin/codex" <<'EOF'
#!/bin/sh
printf 'auto_start=%s|%s\n' "${AGENT_TIMER_AUTO_START:-unset}" "$*" >>"$FAKE_CODEX_LOG"
report=""
previous=""
for argument in "$@"; do
    if [ "$previous" = "--output-last-message" ]; then report="$argument"; fi
    previous="$argument"
done
if [ -n "${FAKE_CODEX_GATE:-}" ]; then
    while [ ! -e "$FAKE_CODEX_GATE" ]; do sleep 0.02; done
fi
if [ -n "${FAKE_CODEX_CHILD_PID_FILE:-}" ]; then
    /usr/bin/perl -e '$SIG{TERM} = "IGNORE"; open(my $fh, ">", $ENV{"FAKE_CODEX_CHILD_PID_FILE"}) or die $!; print {$fh} "$$\n"; close($fh); sleep 300' &
    child_pid=$!
    wait "$child_pid"
    exit $?
fi
if [ "${FAKE_CODEX_FAIL:-0}" = "1" ]; then exit 7; fi
printf 'detached checkpoint report\n' >"$report"
EOF
chmod +x "$TEMP_DIR/fake-codex-bin/codex"
export FAKE_PS_COMMAND="node $TEMP_DIR/fake-codex-bin/codex"
export FAKE_PS_STARTED="Sat Jul 11 12:00:00 2026"
export FAKE_SESH_JSON='[{"Src":"tmux","Name":"work","Path":"/tmp/work","Attached":0,"Windows":3},{"Src":"tmux","Name":"other","Path":"/tmp/other","Attached":1,"Windows":2}]'
: >"$FAKE_TMUX_LOG"
: >"$FAKE_NOTIFIER_LOG"
mkdir -p "$AGENT_TIMER_SOUND_DIR"
: >"$AGENT_TIMER_SOUND_DIR/Ping.aiff"
: >"$FAKE_AFPLAY_LOG"
: >"$FAKE_CODEX_LOG"

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

printf '\nTesting detached report request containment...\n'
forged_request="$AGENT_TIMER_STATE_DIR/forged.request"
forged_report="$AGENT_TIMER_STATE_DIR/forged.md"
forged_log="$AGENT_TIMER_STATE_DIR/forged.log"
jq -n \
    --arg stateFile "$AGENT_TIMER_STATE_DIR/manual.json" \
    --arg launcher "$TEMP_DIR/fake-codex-bin/codex" \
    --arg cwd "$HOOK_CWD" \
    --arg reportPath "$forged_report" \
    --arg logPath "$forged_log" \
    '{id:"forged",token:"forged",stateFile:$stateFile,launcher:$launcher,cwd:$cwd,message:"forged",reportPath:$reportPath,logPath:$logPath,timeoutSeconds:1}' \
    >"$forged_request"
codex_log_lines="$(wc -l <"$FAKE_CODEX_LOG" | tr -d ' ')"
if "$TIMER" _report-worker "$forged_request" >/dev/null 2>&1; then
    fail "detached worker rejects a forged direct-child request"
else
    pass "detached worker rejects a forged direct-child request"
fi
assert_eq "$codex_log_lines" "$(wc -l <"$FAKE_CODEX_LOG" | tr -d ' ')" "forged request cannot launch an executable"
rm -f "$forged_request" "$forged_report" "$forged_log"

traversal_request="$AGENT_TIMER_STATE_DIR/../forged-traversal.request"
printf '{}\n' >"$traversal_request"
if "$TIMER" _report-worker "$traversal_request" >/dev/null 2>&1; then
    fail "detached worker rejects request-path traversal"
else
    pass "detached worker rejects request-path traversal"
fi
rm -f "$traversal_request"

same="$(AGENT_TIMER_NOW=1010 "$TIMER" start --seconds 999 --warning-seconds 20 --target %9 --id manual --turn-id turn-1 --json)"
assert_eq "1100" "$(jq -r '.deadlineAt' <<<"$same")" "same-turn steering cannot reset the deadline"

next="$(AGENT_TIMER_NOW=1010 "$TIMER" start --seconds 50 --warning-seconds 10 --target %9 --id manual --turn-id turn-2 --json)"
assert_eq "1060" "$(jq -r '.deadlineAt' <<<"$next")" "a new turn receives a new deadline"
fingerprint_before="$(jq -c '{token,tmux,agent}' <<<"$next")"

printf '\nTesting exact warning and expiry delivery...\n'
: >"$FAKE_TMUX_LOG"
AGENT_TIMER_NOW=1049 "$TIMER" tick
assert_eq "0" "$(wc -l <"$FAKE_TMUX_LOG" | tr -d ' ')" "timer stays quiet before warning"
AGENT_TIMER_NOW=1050 "$TIMER" tick
assert_eq "0" "$(wc -l <"$FAKE_TMUX_LOG" | tr -d ' ')" "warning never types into the active agent"
assert_eq "1" "$(wc -l <"$FAKE_NOTIFIER_LOG" | tr -d ' ')" "warning uses the native notification path"
assert_eq "native-notification" "$(jq -r '.warningDeliveryMode' "$AGENT_TIMER_STATE_DIR/manual.json")" "warning records its non-disruptive delivery mode"
assert_eq "0" "$(wc -l <"$FAKE_AFPLAY_LOG" | tr -d ' ')" "warning does not play the expiry sound"
AGENT_TIMER_NOW=1051 "$TIMER" tick
assert_eq "0:1" "$(wc -l <"$FAKE_TMUX_LOG" | tr -d ' '):$(wc -l <"$FAKE_NOTIFIER_LOG" | tr -d ' ')" "warning is delivered only once"
AGENT_TIMER_NOW=1060 "$TIMER" tick
assert_eq "0" "$(wc -l <"$FAKE_TMUX_LOG" | tr -d ' ')" "expiry never injects keys into tmux"
assert_eq "1" "$(wc -l <"$FAKE_AFPLAY_LOG" | tr -d ' ')" "expiry plays the configured sound exactly once"
assert_eq "codex-exec" "$(jq -r '.lastCheckpointDeliveryMode' "$AGENT_TIMER_STATE_DIR/manual.json")" "checkpoint records detached Codex execution"
assert_eq "0" "$(grep -c 'kill-session' "$FAKE_TMUX_LOG" || true)" "warning and expiry never close the tmux session"
assert_eq "running:1110:1:sent" "$(jq -r '[.status,.deadlineAt,.checkpointCount,.lastCheckpointDeliveryStatus] | map(tostring) | join(":")' "$AGENT_TIMER_STATE_DIR/manual.json")" "checkpoint delivery leaves the recurring timer armed"
assert_eq "$fingerprint_before" "$(jq -c '{token,tmux,agent}' "$AGENT_TIMER_STATE_DIR/manual.json")" "re-arming preserves the timer token and immutable fingerprints"
if wait_for_state_value "$AGENT_TIMER_STATE_DIR/manual.json" '.sideReport.status // ""' completed; then
    pass "detached read-only checkpoint completes asynchronously"
else
    fail "detached read-only checkpoint completes asynchronously" "$(jq -c '.sideReport' "$AGENT_TIMER_STATE_DIR/manual.json")"
fi
codex_args="$(cat "$FAKE_CODEX_LOG")"
assert_contains "$codex_args" 'auto_start=false|--ask-for-approval never exec --ephemeral --ignore-user-config --sandbox read-only -C' "detached Codex uses the locked-down execution surface"
assert_contains "$codex_args" '--output-last-message' "detached Codex writes its report under timer state"
assert_contains "$codex_args" 'Do not modify files, use the network' "detached checkpoint explicitly forbids external actions"
report_path="$(jq -r '.sideReport.reportPath' "$AGENT_TIMER_STATE_DIR/manual.json")"
assert_eq "detached checkpoint report" "$(cat "$report_path")" "checkpoint report artifact preserves the side result"
if wait_for_file_pattern "$FAKE_NOTIFIER_LOG" 'Agent checkpoint report ready'; then pass "completion sends a second native notification"; else fail "completion sends a second native notification"; fi
if wait_for_file_pattern "$FAKE_NOTIFIER_LOG" 'detached checkpoint report'; then pass "completion notification includes a bounded report excerpt"; else fail "completion notification includes a bounded report excerpt"; fi
AGENT_TIMER_NOW=1060 "$TIMER" tick
assert_eq "0:1" "$(wc -l <"$FAKE_TMUX_LOG" | tr -d ' '):$(jq -r '.checkpointCount' "$AGENT_TIMER_STATE_DIR/manual.json")" "a worker/tick race cannot duplicate a checkpoint"
AGENT_TIMER_NOW=1100 "$TIMER" tick
assert_eq "0" "$(wc -l <"$FAKE_TMUX_LOG" | tr -d ' ')" "the re-armed warning remains outside the terminal input"

printf '\nTesting report artifact identity and cross-turn cleanup...\n'
main_state_dir="$AGENT_TIMER_STATE_DIR"
export AGENT_TIMER_STATE_DIR="$TEMP_DIR/artifact-state"
AGENT_TIMER_NOW=1150 "$TIMER" start --seconds 10 --warning-seconds 2 --target %9 --id artifact --turn-id artifact-turn-1 --json >/dev/null
AGENT_TIMER_NOW=1160 "$TIMER" tick
if wait_for_state_value "$AGENT_TIMER_STATE_DIR/artifact.json" '.sideReport.status // ""' completed; then pass "tokenized report completes"; else fail "tokenized report completes"; fi
artifact_token="$(jq -r '.token' "$AGENT_TIMER_STATE_DIR/artifact.json")"
old_report_path="$(jq -r '.sideReport.reportPath' "$AGENT_TIMER_STATE_DIR/artifact.json")"
old_log_path="$(jq -r '.sideReport.logPath' "$AGENT_TIMER_STATE_DIR/artifact.json")"
assert_contains "$old_report_path" "$artifact_token-1.md" "report path includes the immutable turn token"
AGENT_TIMER_NOW=1161 "$TIMER" start --seconds 10 --warning-seconds 2 --target %9 --id artifact --turn-id artifact-turn-2 --json >/dev/null
assert_eq "missing:missing" "$([[ -e "$old_report_path" ]] && printf present || printf missing):$([[ -e "$old_log_path" ]] && printf present || printf missing)" "a replacement turn removes superseded report artifacts"
AGENT_TIMER_NOW=1162 "$TIMER" cancel --id artifact >/dev/null
export AGENT_TIMER_STATE_DIR="$main_state_dir"

printf '\nTesting single-flight detached reports and cancellation...\n'
main_state_dir="$AGENT_TIMER_STATE_DIR"
export AGENT_TIMER_STATE_DIR="$TEMP_DIR/overlap-state"
export FAKE_CODEX_GATE="$TEMP_DIR/release-overlap-report"
: >"$FAKE_CODEX_LOG"
AGENT_TIMER_NOW=1200 "$TIMER" start --seconds 10 --warning-seconds 2 --target %9 --id overlap --turn-id overlap-turn --json >/dev/null
AGENT_TIMER_NOW=1210 "$TIMER" tick
if wait_for_state_value "$AGENT_TIMER_STATE_DIR/overlap.json" '.sideReport.status // ""' running; then pass "first detached report remains observable while running"; else fail "first detached report remains observable while running"; fi
side_worker_pid="$(jq -r '.sideReport.workerPid' "$AGENT_TIMER_STATE_DIR/overlap.json")"
AGENT_TIMER_NOW=1220 "$TIMER" tick
assert_eq "overlap-skipped:native-notification" "$(jq -r '[.lastCheckpointSideReportStatus,.lastCheckpointDeliveryMode] | join(":")' "$AGENT_TIMER_STATE_DIR/overlap.json")" "a running report prevents overlapping Codex quota use"
assert_eq "1:0" "$(wc -l <"$FAKE_CODEX_LOG" | tr -d ' '):$(wc -l <"$FAKE_TMUX_LOG" | tr -d ' ')" "single-flight reporting never injects tmux keys"
"$TIMER" cancel --id overlap >/dev/null
if wait_for_process_exit "$side_worker_pid"; then pass "cancel terminates the fingerprinted report worker"; else fail "cancel terminates the fingerprinted report worker"; fi
assert_eq "canceled:canceled" "$(jq -r '[.status,.sideReport.status] | join(":")' "$AGENT_TIMER_STATE_DIR/overlap.json")" "cancel records report retirement without a completion race"
unset FAKE_CODEX_GATE
export AGENT_TIMER_STATE_DIR="$main_state_dir"

printf '\nTesting bounded detached-report supervision...\n'
export AGENT_TIMER_STATE_DIR="$TEMP_DIR/timeout-state"
export AGENT_TIMER_REPORT_TIMEOUT_SECS=1
export FAKE_CODEX_CHILD_PID_FILE="$TEMP_DIR/codex-child.pid"
AGENT_TIMER_NOW=1300 "$TIMER" start --seconds 10 --warning-seconds 2 --target %9 --id timeout --turn-id timeout-turn --json >/dev/null
AGENT_TIMER_NOW=1310 "$TIMER" tick
if wait_for_state_value "$AGENT_TIMER_STATE_DIR/timeout.json" '.sideReport.exitCode // 0' 124; then pass "bounded watchdog records a timed-out report"; else fail "bounded watchdog records a timed-out report"; fi
timed_child_pid="$(cat "$FAKE_CODEX_CHILD_PID_FILE")"
if wait_for_process_exit "$timed_child_pid"; then pass "watchdog terminates the launcher's descendant tree"; else fail "watchdog terminates the launcher's descendant tree" "child $timed_child_pid survived"; fi
assert_eq "0" "$(wc -l <"$FAKE_TMUX_LOG" | tr -d ' ')" "report timeout performs no tmux input"
unset AGENT_TIMER_REPORT_TIMEOUT_SECS FAKE_CODEX_CHILD_PID_FILE
export AGENT_TIMER_STATE_DIR="$main_state_dir"

printf '\nTesting Stop and shutdown report-tree cleanup...\n'
export AGENT_TIMER_STATE_DIR="$TEMP_DIR/stop-report-state"
export AGENT_TIMER_AUTO_START=true
export TASK_TIMELIMIT_SECS=10
export FAKE_CODEX_CHILD_PID_FILE="$TEMP_DIR/stop-report-child.pid"
stop_report_prompt="$(jq -cn --arg cwd "$HOOK_CWD" '{hook_event_name:"UserPromptSubmit",session_id:"stop-report",turn_id:"stop-report-turn",cwd:$cwd}')"
stop_report_event="$(jq -cn --arg cwd "$HOOK_CWD" '{hook_event_name:"Stop",session_id:"stop-report",turn_id:"stop-report-turn",cwd:$cwd}')"
TMUX_PANE=%9 AGENT_TIMER_NOW=1350 "$TIMER" hook <<<"$stop_report_prompt" >/dev/null
AGENT_TIMER_NOW=1360 "$TIMER" tick
if wait_for_file_content "$FAKE_CODEX_CHILD_PID_FILE"; then pass "Stop fixture exposes a detached Codex descendant"; else fail "Stop fixture exposes a detached Codex descendant"; fi
stop_report_worker_pid="$(jq -r '.sideReport.workerPid' "$AGENT_TIMER_STATE_DIR/codex-stop-report.json")"
stop_report_child_pid="$(cat "$FAKE_CODEX_CHILD_PID_FILE")"
TMUX_PANE=%9 AGENT_TIMER_NOW=1361 "$TIMER" hook <<<"$stop_report_event" >/dev/null
if wait_for_process_exit "$stop_report_worker_pid" && wait_for_process_exit "$stop_report_child_pid"; then pass "Codex Stop terminates the fingerprinted report tree"; else fail "Codex Stop terminates the fingerprinted report tree"; fi
assert_eq "completed:canceled" "$(jq -r '[.status,.sideReport.status] | join(":")' "$AGENT_TIMER_STATE_DIR/codex-stop-report.json")" "Codex Stop records report cancellation without a completion race"

export AGENT_TIMER_STATE_DIR="$TEMP_DIR/shutdown-report-state"
export FAKE_CODEX_CHILD_PID_FILE="$TEMP_DIR/shutdown-report-child.pid"
AGENT_TIMER_NOW=1370 "$TIMER" start --seconds 10 --warning-seconds 2 --target %9 --id shutdown-report --turn-id shutdown-turn --json >/dev/null
AGENT_TIMER_NOW=1380 "$TIMER" tick
if wait_for_file_content "$FAKE_CODEX_CHILD_PID_FILE"; then pass "shutdown fixture exposes a detached Codex descendant"; else fail "shutdown fixture exposes a detached Codex descendant"; fi
shutdown_report_worker_pid="$(jq -r '.sideReport.workerPid' "$AGENT_TIMER_STATE_DIR/shutdown-report.json")"
shutdown_report_child_pid="$(cat "$FAKE_CODEX_CHILD_PID_FILE")"
AGENT_TIMER_NOW=1381 "$TIMER" shutdown --reason test-shutdown >/dev/null
if wait_for_process_exit "$shutdown_report_worker_pid" && wait_for_process_exit "$shutdown_report_child_pid"; then pass "shutdown terminates the fingerprinted report tree"; else fail "shutdown terminates the fingerprinted report tree"; fi
assert_eq "disabled:canceled" "$(jq -r '[.status,.sideReport.status] | join(":")' "$AGENT_TIMER_STATE_DIR/shutdown-report.json")" "shutdown records report cancellation without a completion race"
"$TIMER" enable >/dev/null
unset AGENT_TIMER_AUTO_START TASK_TIMELIMIT_SECS FAKE_CODEX_CHILD_PID_FILE
export AGENT_TIMER_STATE_DIR="$main_state_dir"

printf '\nTesting automatic-only lifecycle retirement...\n'
selective_state_dir="$AGENT_TIMER_STATE_DIR"
export AGENT_TIMER_STATE_DIR="$TEMP_DIR/selective-shutdown-state"
AGENT_TIMER_NOW=1450 "$TIMER" start --seconds 100 --warning-seconds 20 --target %9 --id manual-survivor --turn-id manual-turn --json >/dev/null
selective_hook="$(jq -cn --arg cwd "$HOOK_CWD" '{hook_event_name:"UserPromptSubmit",session_id:"selective",turn_id:"automatic-turn",cwd:$cwd}')"
TMUX_PANE=%9 AGENT_TIMER_AUTO_START=true TASK_TIMELIMIT_SECS=100 AGENT_TIMER_NOW=1450 "$TIMER" hook <<<"$selective_hook" >/dev/null
jq 'del(.origin)' "$AGENT_TIMER_STATE_DIR/codex-selective.json" >"$TEMP_DIR/legacy-automatic.json"
mv "$TEMP_DIR/legacy-automatic.json" "$AGENT_TIMER_STATE_DIR/codex-selective.json"
AGENT_TIMER_NOW=1451 "$TIMER" shutdown --reason auto-start-disabled --automatic-only >/dev/null
assert_eq "running:manual" "$(jq -r '[.status,.origin] | join(":")' "$AGENT_TIMER_STATE_DIR/manual-survivor.json")" "automatic-only retirement preserves an active manual timer"
assert_eq "disabled:auto-start-disabled" "$(jq -r '[.status,.shutdownReason] | join(":")' "$AGENT_TIMER_STATE_DIR/codex-selective.json")" "automatic-only retirement recognizes and stops a legacy hook timer"
assert_contains "$(cat "$AGENT_TIMER_STATE_DIR/module-disabled")" "reason=auto-start-disabled" "automatic-only retirement latches reconciliation"
"$TIMER" enable >/dev/null
AGENT_TIMER_NOW=1452 "$TIMER" cancel --id manual-survivor >/dev/null
export AGENT_TIMER_STATE_DIR="$selective_state_dir"

printf '\nTesting agents without a side-conversation surface...\n'
export FAKE_PS_COMMAND="claude"
AGENT_TIMER_NOW=1400 "$TIMER" start --seconds 30 --warning-seconds 5 --target %9 --id claude-native --turn-id claude-turn --json >/dev/null
: >"$FAKE_TMUX_LOG"
: >"$FAKE_NOTIFIER_LOG"
AGENT_TIMER_NOW=1430 "$TIMER" tick
assert_eq "0" "$(wc -l <"$FAKE_TMUX_LOG" | tr -d ' ')" "Claude expiry never types a follow-up into the active agent"
assert_eq "native-notification" "$(jq -r '.lastCheckpointDeliveryMode' "$AGENT_TIMER_STATE_DIR/claude-native.json")" "Claude expiry records native-only delivery"
assert_eq "sent" "$(jq -r '.lastCheckpointDeliveryStatus' "$AGENT_TIMER_STATE_DIR/claude-native.json")" "native-only expiry completes its delivery state"
assert_contains "$(cat "$FAKE_NOTIFIER_LOG")" "Agent checkpoint due" "native-only expiry surfaces the checkpoint outside terminal input"
export FAKE_PS_COMMAND="node $TEMP_DIR/fake-codex-bin/codex"

printf '\nTesting stale panes and cancellation...\n'
AGENT_TIMER_NOW=2000 "$TIMER" start --seconds 100 --warning-seconds 20 --target %9 --id stale --json >/dev/null
export FAKE_TMUX_SNAPSHOT='$9|work|@1|%10|222|/dev/ttys998|node'
: >"$FAKE_TMUX_LOG"
AGENT_TIMER_NOW=2080 "$TIMER" tick
assert_eq "0" "$(wc -l <"$FAKE_TMUX_LOG" | tr -d ' ')" "reused pane receives no stale delivery"
assert_eq "stale" "$(jq -r '.status' "$AGENT_TIMER_STATE_DIR/stale.json")" "reused pane is surfaced as stale"
export FAKE_TMUX_SNAPSHOT='$9|work|@1|%9|111|/dev/ttys999|node'

AGENT_TIMER_NOW=3000 "$TIMER" start --seconds 100 --warning-seconds 20 --target %9 --id canceled --json >/dev/null
AGENT_TIMER_NOW=3010 "$TIMER" cancel --id canceled >/dev/null
: >"$FAKE_TMUX_LOG"
AGENT_TIMER_NOW=3100 "$TIMER" tick
assert_eq "0" "$(wc -l <"$FAKE_TMUX_LOG" | tr -d ' ')" "canceled timer performs no delivery"
assert_eq "canceled" "$(jq -r '.status' "$AGENT_TIMER_STATE_DIR/canceled.json")" "cancellation is visible in state"

printf '\nTesting Codex hook behavior...\n'
missing_pretool="$(jq -cn --arg cwd "$HOOK_CWD" '{hook_event_name:"PreToolUse",session_id:"missing-state",turn_id:"missing-turn",cwd:$cwd,tool_name:"Bash"}')"
missing_pretool_result="$(TMUX_PANE=%9 AGENT_TIMER_NOW=3999 "$TIMER" hook <<<"$missing_pretool")"
assert_eq "{}" "$missing_pretool_result" "PreToolUse with no timer state returns exact fail-open JSON"
hook_input="$(jq -cn --arg cwd "$HOOK_CWD" '{hook_event_name:"UserPromptSubmit",session_id:"session-a",turn_id:"turn-a",cwd:$cwd}')"
unset TASK_TIMELIMIT_SECS
default_hook_input="$(jq -cn --arg cwd "$HOOK_CWD" '{hook_event_name:"UserPromptSubmit",session_id:"session-default",turn_id:"turn-default",cwd:$cwd}')"
auto_disabled="$(TMUX_PANE=%9 AGENT_TIMER_NOW=4000 "$TIMER" hook <<<"$default_hook_input")"
assert_eq "{}" "$auto_disabled" "managed default leaves automatic Codex timing disabled"
assert_eq "missing" "$([[ -e "$AGENT_TIMER_STATE_DIR/codex-session-default.json" ]] && printf present || printf missing)" "disabled automatic hook creates no timer state"

export AGENT_TIMER_AUTO_START=true
auto_enabled="$(TMUX_PANE=%9 AGENT_TIMER_NOW=4000 "$TIMER" hook <<<"$default_hook_input")"
assert_contains "$auto_enabled" "current 600s checkpoint block" "explicit automatic start uses the managed recurring 600-second default"
assert_contains "$(jq -r '.expiryMessage' "$AGENT_TIMER_STATE_DIR/codex-session-default.json")" "new 600s block is already armed" "default checkpoint request names the newly armed 600-second block"

export TASK_TIMELIMIT_SECS=120
armed="$(TMUX_PANE=%9 AGENT_TIMER_NOW=4000 "$TIMER" hook <<<"$hook_input")"
assert_contains "$armed" "TASK TIMEBOX ACTIVE" "prompt hook injects the immutable deadline"
hook_deadline="$(jq -r '.deadlineAt' "$AGENT_TIMER_STATE_DIR/codex-session-a.json")"
TMUX_PANE=%9 AGENT_TIMER_NOW=4010 "$TIMER" hook <<<"$hook_input" >/dev/null
assert_eq "$hook_deadline" "$(jq -r '.deadlineAt' "$AGENT_TIMER_STATE_DIR/codex-session-a.json")" "in-flight user steer preserves hook deadline"

pretool="$(jq -cn --arg cwd "$HOOK_CWD" '{hook_event_name:"PreToolUse",session_id:"session-a",turn_id:"turn-a",cwd:$cwd,tool_name:"Bash"}')"
checkpointed="$(TMUX_PANE=%9 AGENT_TIMER_NOW=4120 "$TIMER" hook <<<"$pretool")"
assert_eq "{}" "$checkpointed" "PreToolUse never injects checkpoint instructions into the root turn"
assert_eq "none" "$(jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$checkpointed")" "checkpoint expiry never denies the next tool"
if wait_for_state_value "$AGENT_TIMER_STATE_DIR/codex-session-a.json" '.checkpointCount' 1; then pass "expired PreToolUse schedules re-arming asynchronously"; else fail "expired PreToolUse schedules re-arming asynchronously"; fi
assert_eq "running:4240:1" "$(jq -r '[.status,.deadlineAt,.checkpointCount] | map(tostring) | join(":")' "$AGENT_TIMER_STATE_DIR/codex-session-a.json")" "asynchronous PreToolUse fire installs the next block"
if wait_for_state_value "$AGENT_TIMER_STATE_DIR/codex-session-a.json" '.lastCheckpointDeliveryStatus // ""' sent; then pass "asynchronous PreToolUse fire completes native delivery"; else fail "asynchronous PreToolUse fire completes native delivery"; fi
assert_eq "codex-exec" "$(jq -r '.lastCheckpointDeliveryMode' "$AGENT_TIMER_STATE_DIR/codex-session-a.json")" "PreToolUse schedules a detached read-only Codex report"

stop_input="$(jq -cn --arg cwd "$HOOK_CWD" '{hook_event_name:"Stop",session_id:"session-a",turn_id:"turn-a",cwd:$cwd}')"
TMUX_PANE=%9 AGENT_TIMER_NOW=4121 "$TIMER" hook <<<"$stop_input" >/dev/null
assert_eq "completed" "$(jq -r '.status' "$AGENT_TIMER_STATE_DIR/codex-session-a.json")" "turn completion retires its timer"
unset AGENT_TIMER_AUTO_START

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

close_report="$AGENT_TIMER_STATE_DIR/close-me.checkpoint-prune.md"
close_log="$AGENT_TIMER_STATE_DIR/close-me.checkpoint-prune.log"
close_request="$AGENT_TIMER_STATE_DIR/close-me.checkpoint-prune.request"
: >"$close_report"
: >"$close_log"
: >"$close_request"
jq --arg reportPath "$close_report" --arg logPath "$close_log" --arg requestPath "$close_request" \
    '.sideReport={status:"completed",reportPath:$reportPath,logPath:$logPath,requestPath:$requestPath}' \
    "$AGENT_TIMER_STATE_DIR/close-me.json" >"$TEMP_DIR/close-me-with-report.json"
mv "$TEMP_DIR/close-me-with-report.json" "$AGENT_TIMER_STATE_DIR/close-me.json"

AGENT_TIMER_RETENTION_SECS=1 AGENT_TIMER_NOW=4300 "$TIMER" prune
if [[ ! -e "$AGENT_TIMER_STATE_DIR/close-me.json" ]]; then
    pass "terminal timer state is pruned after retention"
else
    fail "terminal timer state is pruned after retention" "state still exists"
fi
assert_eq "missing:missing:missing" "$([[ -e "$close_report" ]] && printf present || printf missing):$([[ -e "$close_log" ]] && printf present || printf missing):$([[ -e "$close_request" ]] && printf present || printf missing)" "terminal-state pruning removes its report artifacts"

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
assert_eq "2:5090:0" "$(jq -r '[.checkpointCount,.deadlineAt] | map(tostring) | join(":")' "$AGENT_TIMER_STATE_DIR/cron-recovery.json"):$(wc -l <"$FAKE_TMUX_LOG" | tr -d ' ')" "successive cron ticks continue without terminal injection"
if wait_for_state_value "$AGENT_TIMER_STATE_DIR/cron-recovery.json" '.sideReport.status // ""' completed; then pass "successive report completes"; else fail "successive report completes"; fi
assert_eq "1:1" "$(find "$AGENT_TIMER_STATE_DIR" -maxdepth 1 -name 'cron-recovery.checkpoint-*.md' | wc -l | tr -d ' '):$(find "$AGENT_TIMER_STATE_DIR" -maxdepth 1 -name 'cron-recovery.checkpoint-*.log' | wc -l | tr -d ' ')" "recurring checkpoints retain only the latest report and log"

printf '\nTesting detached report failure after re-arm...\n'
export AGENT_TIMER_STATE_DIR="$TEMP_DIR/delivery-failure-state"
export FAKE_CODEX_FAIL=1
: >"$FAKE_NOTIFIER_LOG"
AGENT_TIMER_NOW=6000 "$TIMER" start --seconds 30 --warning-seconds 5 --target %9 --id delivery-failure --turn-id failure-turn --json >/dev/null
AGENT_TIMER_NOW=6030 "$TIMER" tick
if wait_for_state_value "$AGENT_TIMER_STATE_DIR/delivery-failure.json" '.sideReport.status // ""' failed; then pass "failed detached report is recorded"; else fail "failed detached report is recorded"; fi
assert_eq "running:6060:1:sent" "$(jq -r '[.status,.deadlineAt,.checkpointCount,.lastCheckpointDeliveryStatus] | map(tostring) | join(":")' "$AGENT_TIMER_STATE_DIR/delivery-failure.json")" "failed report never rolls back native delivery or the next block"
if wait_for_file_pattern "$FAKE_NOTIFIER_LOG" 'Agent checkpoint report failed'; then pass "detached report failure is surfaced natively"; else fail "detached report failure is surfaced natively"; fi
unset FAKE_CODEX_FAIL

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
assert_eq "0" "$(wc -l <"$FAKE_TMUX_LOG" | tr -d ' ')" "one worker checkpoints without typing into tmux"
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
assert_contains "$(cat "$DESTINATION/.agents/AGENTS.md")" "managed .*auto_start.* default is .*false" "enabled profile documents opt-in automatic timing"
assert_contains "$(cat "$DESTINATION/.agents/AGENTS.md")" "detached read-only Codex" "enabled profile documents detached checkpoint reports"
assert_contains "$(cat "$DESTINATION/.config/agent-timer/config.toml")" "auto_start = false" "enabled profile keeps automatic timing off by default"
assert_contains "$(cat "$DESTINATION/.config/agent-timer/config.toml")" "default_seconds = 600" "enabled profile installs the global TOML budget"
assert_contains "$(cat "$DESTINATION/.config/agent-timer/config.toml")" "report_timeout_seconds = 120" "enabled profile installs the bounded detached-report timeout"
assert_contains "$(cat "$DESTINATION/.config/agent-timer/config.toml")" 'expiry_sound = "Ping"' "enabled profile installs the expiry sound"
assert_contains "$(cat "$DESTINATION/.config/agent-timer/config.toml")" '"codex", "claude", "opencode"' "enabled profile prefers Codex first"
assert_contains "$(cat "$DESTINATION/.codex/hooks.json")" "UserPromptSubmit" "enabled profile installs Codex hooks"
assert_contains "$(cat "$DESTINATION/.codex/hooks.json")" 'cat >\/dev\/null' "enabled profile installs a missing-command guard for cached hooks"
assert_contains "$(cat "$DESTINATION/.tmux.conf")" "agent-timer manage" "enabled profile installs tmux lifecycle access"

MISSING_HOOK_HOME="$TEMP_DIR/missing-hook-home"
mkdir -p "$MISSING_HOOK_HOME"
hook_command="$(jq -r '.hooks.UserPromptSubmit[0].hooks[0].command' "$DESTINATION/.codex/hooks.json")"
missing_hook_result="$(HOME="$MISSING_HOOK_HOME" /bin/sh -c "$hook_command" <<<'{"hook_event_name":"UserPromptSubmit"}')"
assert_eq "{}" "$missing_hook_result" "cached Codex hook fails open after its timer command is removed"
mkdir -p "$MISSING_HOOK_HOME/bin"
cat >"$MISSING_HOOK_HOME/bin/agent-timer" <<'EOF'
#!/bin/sh
printf '{"partial":true}'
exit 2
EOF
chmod +x "$MISSING_HOOK_HOME/bin/agent-timer"
failed_hook_result="$(HOME="$MISSING_HOOK_HOME" /bin/sh -c "$hook_command" <<<'{"hook_event_name":"UserPromptSubmit"}')"
assert_eq "{}" "$failed_hook_result" "cached Codex hook discards partial output when the timer command fails"

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
