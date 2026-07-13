# Shared, policy-free shell primitives for managed dotfiles commands.
#
# Public API:
#   dotfiles_program_name
#   dotfiles_log LEVEL MESSAGE...
#   dotfiles_error MESSAGE...
#   dotfiles_die MESSAGE...
#   dotfiles_require_command COMMAND [INSTALL_HINT]
#   dotfiles_now_ms

dotfiles_program_name() {
  printf '%s\n' "${DOTFILES_PROGRAM_NAME:-${0##*/}}"
}

dotfiles_log() {
  local level="${1:-info}"
  local program

  if [ "$#" -gt 0 ]; then
    shift
  fi
  program=$(dotfiles_program_name)
  printf '%s: %s: %s\n' "$program" "$level" "$*" >&2
}

dotfiles_error() {
  dotfiles_log error "$@"
}

# Return instead of exiting so callers retain control over process policy.
dotfiles_die() {
  dotfiles_error "$@"
  return 1
}

dotfiles_require_command() {
  local required="${1:-}"
  local install_hint="${2:-}"

  if [ -z "$required" ]; then
    dotfiles_error "dotfiles_require_command requires a command name"
    return 2
  fi
  if command -v "$required" >/dev/null 2>&1; then
    return 0
  fi

  if [ -n "$install_hint" ]; then
    dotfiles_error "$required is required; $install_hint"
  else
    dotfiles_error "$required is required"
  fi
  return 127
}

# Millisecond timestamps are used only for bounded polling and lock deadlines.
# Perl is present on supported macOS clients; the fallbacks keep tests and
# portable plugins functional on systems where it is absent.
dotfiles_now_ms() {
  local candidate=""

  if command -v perl >/dev/null 2>&1; then
    command perl -MTime::HiRes=time -e 'printf "%.0f\n", time() * 1000'
    return
  fi

  candidate=$(command date +%s%3N 2>/dev/null || true)
  case "$candidate" in
    ''|*[!0-9]*) ;;
    *)
      printf '%s\n' "$candidate"
      return
      ;;
  esac

  candidate=$(command date +%s) || return
  printf '%s000\n' "$candidate"
}
