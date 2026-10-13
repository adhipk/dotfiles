# Bash reads BASH_ENV in simulated subprocesses. Record only fatal locations,
# not commands, arguments, environment, prompts, or state contents.
if [[ -n "${TIMER_FIXTURE_ERROR_LOG:-}" ]]; then
    set -E
    trap 'timer_fixture_error_status=$?; printf "status=%s pid=%s shell=%s source=%s line=%s functions=%s callers=%s\n" "$timer_fixture_error_status" "${BASHPID:-$$}" "$BASH_VERSION" "${BASH_SOURCE[0]:-main}" "$LINENO" "${FUNCNAME[*]:-main}" "${BASH_LINENO[*]:-}" >>"$TIMER_FIXTURE_ERROR_LOG"' ERR
fi
