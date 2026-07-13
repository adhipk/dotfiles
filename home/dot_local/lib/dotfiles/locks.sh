# Stale-safe filesystem locks for short, local critical sections.
# Source core.sh first for consistent diagnostics and millisecond deadlines.
#
# Public API:
#   dotfiles_lock_acquire LOCK_DIR [TIMEOUT_MS] [POLL_SECONDS]
#   dotfiles_lock_release LOCK_DIR
#   dotfiles_lock_with LOCK_DIR TIMEOUT_MS [--] COMMAND [ARG...]

_dotfiles_lock_error() {
  if command -v dotfiles_error >/dev/null 2>&1; then
    dotfiles_error "$@"
  else
    printf 'dotfiles: error: %s\n' "$*" >&2
  fi
}

_dotfiles_lock_now_ms() {
  if command -v dotfiles_now_ms >/dev/null 2>&1; then
    dotfiles_now_ms
  else
    printf '%s000\n' "$(command date +%s)"
  fi
}

_dotfiles_lock_mtime_seconds() {
  local path="$1"
  local value=""

  value=$(command stat -f '%m' "$path" 2>/dev/null || true)
  case "$value" in
    ''|*[!0-9]*) value=$(command stat -c '%Y' "$path" 2>/dev/null || true) ;;
  esac
  case "$value" in
    ''|*[!0-9]*) return 1 ;;
  esac
  printf '%s\n' "$value"
}

_dotfiles_lock_owner_is_alive() {
  local lock_dir="$1"
  local owner_pid=""

  if [ -r "$lock_dir/pid" ]; then
    IFS= read -r owner_pid < "$lock_dir/pid" || true
  fi
  case "$owner_pid" in
    ''|*[!0-9]*) return 1 ;;
  esac
  command kill -0 "$owner_pid" 2>/dev/null
}

_dotfiles_lock_is_stale() {
  local lock_dir="$1"
  local owner_pid=""
  local modified=""
  local now_seconds
  local orphan_after_seconds="${DOTFILES_LOCK_ORPHAN_AFTER_SECONDS:-10}"

  # Never follow or replace a pre-existing symbolic link at a lock path.
  [ ! -L "$lock_dir" ] || return 1

  if [ -r "$lock_dir/pid" ]; then
    IFS= read -r owner_pid < "$lock_dir/pid" || true
  fi

  case "$owner_pid" in
    *[!0-9]*|'')
      case "$orphan_after_seconds" in
        ''|*[!0-9]*) orphan_after_seconds=10 ;;
      esac
      modified=$(_dotfiles_lock_mtime_seconds "$lock_dir") || return 1
      now_seconds=$(command date +%s) || return 1
      [ $((now_seconds - modified)) -ge "$orphan_after_seconds" ]
      ;;
    *)
      ! _dotfiles_lock_owner_is_alive "$lock_dir"
      ;;
  esac
}

# Atomically move a stale lock out of the acquisition path before cleaning it.
# Only files created by this library are removed; unexpected content is left in
# the quarantine directory for inspection.
_dotfiles_lock_reap_stale() {
  local lock_dir="$1"
  local quarantine

  _dotfiles_lock_is_stale "$lock_dir" || return 1
  quarantine="${lock_dir}.stale.$$.$RANDOM.$RANDOM"
  [ ! -e "$quarantine" ] && [ ! -L "$quarantine" ] || return 1
  if ! command mv "$lock_dir" "$quarantine" 2>/dev/null; then
    return 1
  fi

  command rm -f "$quarantine/pid" >/dev/null 2>&1 || true
  command rmdir "$quarantine" >/dev/null 2>&1 || true
  return 0
}

dotfiles_lock_acquire() {
  local lock_dir="${1:-}"
  local timeout_ms="${2:-0}"
  local poll_seconds="${3:-0.05}"
  local deadline
  local parent

  if [ -z "$lock_dir" ]; then
    _dotfiles_lock_error "dotfiles_lock_acquire requires a lock directory"
    return 2
  fi
  case "$timeout_ms" in
    ''|*[!0-9]*)
      _dotfiles_lock_error "lock timeout must be a non-negative integer in milliseconds"
      return 2
      ;;
  esac
  if ! [[ "$poll_seconds" =~ ^([0-9]+([.][0-9]+)?|[.][0-9]+)$ ]] \
      || ! [[ "$poll_seconds" =~ [1-9] ]]; then
    _dotfiles_lock_error "lock poll interval must be a positive number of seconds"
    return 2
  fi

  parent=$(command dirname "$lock_dir") || return
  command mkdir -p "$parent" || return
  deadline=$(( $(_dotfiles_lock_now_ms) + timeout_ms ))

  while :; do
    if command mkdir "$lock_dir" 2>/dev/null; then
      if ! command chmod 700 "$lock_dir"; then
        command rmdir "$lock_dir" >/dev/null 2>&1 || true
        return 1
      fi
      if ! printf '%s\n' "$$" > "$lock_dir/pid"; then
        command rmdir "$lock_dir" >/dev/null 2>&1 || true
        return 1
      fi
      return 0
    fi

    if _dotfiles_lock_reap_stale "$lock_dir"; then
      continue
    fi

    if [ "$timeout_ms" -eq 0 ] || [ "$(_dotfiles_lock_now_ms)" -ge "$deadline" ]; then
      if [ "$timeout_ms" -gt 0 ]; then
        _dotfiles_lock_error "timed out waiting for lock: $lock_dir"
      fi
      return 1
    fi
    command sleep "$poll_seconds"
  done
}

dotfiles_lock_release() {
  local lock_dir="${1:-}"
  local owner_pid=""

  if [ -z "$lock_dir" ]; then
    _dotfiles_lock_error "dotfiles_lock_release requires a lock directory"
    return 2
  fi
  [ -d "$lock_dir" ] || return 0
  if [ -L "$lock_dir" ]; then
    _dotfiles_lock_error "refusing to release a symbolic-link lock: $lock_dir"
    return 1
  fi

  if [ -r "$lock_dir/pid" ]; then
    IFS= read -r owner_pid < "$lock_dir/pid" || true
  fi
  if [ "$owner_pid" != "$$" ]; then
    _dotfiles_lock_error "refusing to release a lock owned by another process: $lock_dir"
    return 1
  fi

  command rm -f "$lock_dir/pid" || return
  command rmdir "$lock_dir"
}

dotfiles_lock_with() (
  local lock_dir="${1:-}"
  local timeout_ms="${2:-}"

  if [ "$#" -lt 3 ]; then
    _dotfiles_lock_error "usage: dotfiles_lock_with LOCK_DIR TIMEOUT_MS [--] COMMAND [ARG...]"
    return 2
  fi
  shift 2
  if [ "${1:-}" = "--" ]; then
    shift
  fi
  if [ "$#" -eq 0 ]; then
    _dotfiles_lock_error "dotfiles_lock_with requires a command"
    return 2
  fi

  dotfiles_lock_acquire "$lock_dir" "$timeout_ms" || return
  DOTFILES_LOCK_WITH_DIR="$lock_dir"
  trap 'dotfiles_lock_release "$DOTFILES_LOCK_WITH_DIR" >/dev/null 2>&1 || true' EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
  "$@"
)
