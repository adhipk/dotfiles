# Failure-only diagnostics for simulated timer fixtures. Never print command
# arguments, settings, environment, prompts, or report contents.
dump_timer_fixture() {
    local file="$1" pid lock_path owner path field
    printf '  fixture diagnostics: shell=%s env-bash=%s jq=%s\n' "$BASH_VERSION" "$(command -v bash)" "$(command -v jq)"
    if [[ ! -f "$file" ]]; then printf '  fixture state missing: %s\n' "${file##*/}"; return; fi
    jq '{id,status,checkpointCount,startedAt,warningAt,deadlineAt,workerLaunchStatus,lastCheckpointDeliveryStatus,lastCheckpointDeliveryMode,lastCheckpointSideReportStatus,worker,sideReport:(.sideReport | if . == null then null else {id,status,startedAt,completedAt,exitCode,workerPid,workerStartedAt,workerPgid,timeoutSeconds} end)}' "$file"
    while IFS= read -r pid; do
        [[ "$pid" =~ ^[0-9]+$ ]] || continue
        printf '  fixture process fingerprint (without command arguments):\n'
        /bin/ps -p "$pid" -o pid=,ppid=,pgid=,lstart=,stat= 2>/dev/null || printf '  pid=%s absent\n' "$pid"
    done < <(jq -r '[.agent.pid,.worker.pid,.sideReport.workerPid] | unique[] | select(. != null)' "$file")
    lock_path="${file%.json}.lock"
    if [[ -d "$lock_path" ]]; then
        owner="$(cat "$lock_path/pid" 2>/dev/null || true)"
        printf '  fixture lock=%s owner=%s\n' "${lock_path##*/}" "$owner"
        if [[ "$owner" =~ ^[0-9]+$ ]]; then /bin/ps -p "$owner" -o pid=,ppid=,pgid=,lstart=,stat= 2>/dev/null || true; fi
    else printf '  fixture state lock absent\n'; fi
    for field in requestPath reportPath logPath; do
        path="$(jq -r --arg field "$field" '.sideReport[$field] // empty' "$file")"
        [[ -n "$path" ]] || continue
        if [[ -f "$path" ]]; then printf '  fixture %s exists bytes=%s\n' "$field" "$(wc -c <"$path" | tr -d ' ')";
        else printf '  fixture %s absent\n' "$field"; fi
    done
}
