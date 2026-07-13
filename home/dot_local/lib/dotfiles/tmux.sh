# Tmux command routing and wait-for lock mechanics.
#
# DOTFILES_TMUX_BIN overrides the executable for tests or packaged plugins.
# DOTFILES_TMUX_SOCKET_NAME selects tmux -L; DOTFILES_TMUX_SOCKET_PATH selects
# tmux -S. The two socket selectors are intentionally mutually exclusive.
#
# Public API:
#   dotfiles_tmux_cmd ARG...
#   dotfiles_tmux_wait_lock_acquire CHANNEL
#   dotfiles_tmux_wait_lock_release CHANNEL
#   dotfiles_tmux_with_lock CHANNEL [--] COMMAND [ARG...]

_dotfiles_tmux_error() {
  if command -v dotfiles_error >/dev/null 2>&1; then
    dotfiles_error "$@"
  else
    printf 'dotfiles: error: %s\n' "$*" >&2
  fi
}

dotfiles_tmux_cmd() {
  local tmux_bin="${DOTFILES_TMUX_BIN:-tmux}"
  local socket_name="${DOTFILES_TMUX_SOCKET_NAME:-}"
  local socket_path="${DOTFILES_TMUX_SOCKET_PATH:-}"

  if [ -n "$socket_name" ] && [ -n "$socket_path" ]; then
    _dotfiles_tmux_error "set only one of DOTFILES_TMUX_SOCKET_NAME or DOTFILES_TMUX_SOCKET_PATH"
    return 2
  fi
  if ! command -v "$tmux_bin" >/dev/null 2>&1; then
    _dotfiles_tmux_error "$tmux_bin is required"
    return 127
  fi

  if [ -n "$socket_name" ]; then
    command "$tmux_bin" -L "$socket_name" "$@"
  elif [ -n "$socket_path" ]; then
    command "$tmux_bin" -S "$socket_path" "$@"
  else
    command "$tmux_bin" "$@"
  fi
}

dotfiles_tmux_wait_lock_acquire() {
  local channel="${1:-}"

  if [ -z "$channel" ]; then
    _dotfiles_tmux_error "tmux wait-for lock requires a channel"
    return 2
  fi
  dotfiles_tmux_cmd wait-for -L "$channel"
}

dotfiles_tmux_wait_lock_release() {
  local channel="${1:-}"

  if [ -z "$channel" ]; then
    _dotfiles_tmux_error "tmux wait-for unlock requires a channel"
    return 2
  fi
  dotfiles_tmux_cmd wait-for -U "$channel"
}

dotfiles_tmux_with_lock() (
  local channel="${1:-}"

  if [ "$#" -lt 2 ]; then
    _dotfiles_tmux_error "usage: dotfiles_tmux_with_lock CHANNEL [--] COMMAND [ARG...]"
    return 2
  fi
  shift
  if [ "${1:-}" = "--" ]; then
    shift
  fi
  if [ "$#" -eq 0 ]; then
    _dotfiles_tmux_error "dotfiles_tmux_with_lock requires a command"
    return 2
  fi

  dotfiles_tmux_wait_lock_acquire "$channel" || return
  DOTFILES_TMUX_ACTIVE_LOCK="$channel"
  trap 'dotfiles_tmux_wait_lock_release "$DOTFILES_TMUX_ACTIVE_LOCK" >/dev/null 2>&1 || true' EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
  "$@"
)
