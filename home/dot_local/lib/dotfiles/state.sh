# XDG-scoped state paths and atomic file replacement.
# Source core.sh first for consistent diagnostics.
#
# Public API:
#   dotfiles_state_home
#   dotfiles_state_dir NAMESPACE
#   dotfiles_state_file NAMESPACE RELATIVE_PATH
#   dotfiles_state_ensure_dir NAMESPACE
#   dotfiles_atomic_write DESTINATION [MODE] < input
#   dotfiles_state_write NAMESPACE RELATIVE_PATH [MODE] < input

_dotfiles_state_error() {
  if command -v dotfiles_error >/dev/null 2>&1; then
    dotfiles_error "$@"
  else
    printf 'dotfiles: error: %s\n' "$*" >&2
  fi
}

_dotfiles_state_namespace_is_valid() {
  case "${1:-}" in
    ''|.|..|*[!A-Za-z0-9._-]*) return 1 ;;
    *) return 0 ;;
  esac
}

_dotfiles_state_relative_path_is_valid() {
  local relative="${1:-}"

  case "$relative" in
    ''|/*|*/) return 1 ;;
  esac
  case "/$relative/" in
    *'/../'*|*'/./'*|*'//'* ) return 1 ;;
  esac
  return 0
}

dotfiles_state_home() {
  local root="${XDG_STATE_HOME:-}"

  if [ -n "$root" ]; then
    case "$root" in
      /*) ;;
      *)
        _dotfiles_state_error "XDG_STATE_HOME must be an absolute path"
        return 2
        ;;
    esac
  else
    if [ -z "${HOME:-}" ]; then
      _dotfiles_state_error "HOME is required when XDG_STATE_HOME is unset"
      return 2
    fi
    case "$HOME" in
      /*) root="$HOME/.local/state" ;;
      *)
        _dotfiles_state_error "HOME must be an absolute path"
        return 2
        ;;
    esac
  fi
  printf '%s\n' "$root"
}

dotfiles_state_dir() {
  local namespace="${1:-}"
  local state_home

  if ! _dotfiles_state_namespace_is_valid "$namespace"; then
    _dotfiles_state_error "invalid state namespace: ${namespace:-<empty>}"
    return 2
  fi
  state_home=$(dotfiles_state_home) || return
  printf '%s/dotfiles/%s\n' "$state_home" "$namespace"
}

dotfiles_state_file() {
  local namespace="${1:-}"
  local relative="${2:-}"
  local state_dir

  if ! _dotfiles_state_relative_path_is_valid "$relative"; then
    _dotfiles_state_error "invalid relative state path: ${relative:-<empty>}"
    return 2
  fi
  state_dir=$(dotfiles_state_dir "$namespace") || return
  printf '%s/%s\n' "$state_dir" "$relative"
}

dotfiles_state_ensure_dir() {
  local state_dir

  state_dir=$(dotfiles_state_dir "${1:-}") || return
  command mkdir -p "$state_dir" || return
  command chmod 700 "$state_dir"
}

dotfiles_atomic_write() (
  local destination="${1:-}"
  local mode="${2:-600}"
  local parent

  if [ -z "$destination" ]; then
    _dotfiles_state_error "dotfiles_atomic_write requires a destination"
    return 2
  fi
  if [ -d "$destination" ]; then
    _dotfiles_state_error "atomic write destination must not be a directory: $destination"
    return 2
  fi
  case "$mode" in
    ''|*[!0-7]*)
      _dotfiles_state_error "atomic write mode must contain only octal digits"
      return 2
      ;;
  esac

  umask 077
  parent=$(command dirname "$destination") || return
  command mkdir -p "$parent" || return
  DOTFILES_ATOMIC_TEMP=$(command mktemp "${destination}.tmp.XXXXXX") || return
  trap 'command rm -f "$DOTFILES_ATOMIC_TEMP" >/dev/null 2>&1 || true' EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM

  command cat > "$DOTFILES_ATOMIC_TEMP" || return
  command chmod "$mode" "$DOTFILES_ATOMIC_TEMP" || return
  command mv -f "$DOTFILES_ATOMIC_TEMP" "$destination" || return
  DOTFILES_ATOMIC_TEMP=""
  trap - EXIT HUP INT TERM
)

dotfiles_state_write() {
  local namespace="${1:-}"
  local relative="${2:-}"
  local mode="${3:-600}"
  local destination

  destination=$(dotfiles_state_file "$namespace" "$relative") || return
  dotfiles_atomic_write "$destination" "$mode"
}
