# Ghostty window discovery through yabai. Source core.sh and yabai.sh first.
# Launch policy and window appearance remain feature-owned.
#
# Public API:
#   dotfiles_ghostty_window_ids_json [APP_NAME]
#   dotfiles_ghostty_find_new_window_id TITLE BEFORE_IDS_JSON [APP_NAME]
#   dotfiles_ghostty_wait_for_window TITLE BEFORE_IDS_JSON [TIMEOUT_MS]
#                                     [POLL_SECONDS] [APP_NAME]

_dotfiles_ghostty_error() {
  if command -v dotfiles_error >/dev/null 2>&1; then
    dotfiles_error "$@"
  else
    printf 'dotfiles: error: %s\n' "$*" >&2
  fi
}

_dotfiles_ghostty_jq() {
  local jq_bin="${DOTFILES_JQ_BIN:-jq}"

  if ! command -v "$jq_bin" >/dev/null 2>&1; then
    _dotfiles_ghostty_error "$jq_bin is required"
    return 127
  fi
  command "$jq_bin" "$@"
}

_dotfiles_ghostty_now_ms() {
  if command -v dotfiles_now_ms >/dev/null 2>&1; then
    dotfiles_now_ms
  else
    printf '%s000\n' "$(command date +%s)"
  fi
}

_dotfiles_ghostty_windows_json() {
  if ! command -v dotfiles_yabai_query_windows >/dev/null 2>&1; then
    _dotfiles_ghostty_error "source yabai.sh before ghostty.sh"
    return 2
  fi
  dotfiles_yabai_query_windows
}

dotfiles_ghostty_window_ids_json() {
  local app_name="${1:-${DOTFILES_GHOSTTY_APP_NAME:-Ghostty}}"
  local windows_json

  windows_json=$(_dotfiles_ghostty_windows_json) || return
  printf '%s\n' "$windows_json" \
    | _dotfiles_ghostty_jq -ce --arg app "$app_name" \
      '[.[] | select(.app == $app) | .id]'
}

dotfiles_ghostty_find_new_window_id() {
  local title="${1:-}"
  local before_json="${2:-}"
  local app_name="${3:-${DOTFILES_GHOSTTY_APP_NAME:-Ghostty}}"
  local windows_json

  if [ -z "$before_json" ]; then
    _dotfiles_ghostty_error "dotfiles_ghostty_find_new_window_id requires a before-ID array"
    return 2
  fi
  if ! printf '%s\n' "$before_json" | _dotfiles_ghostty_jq -e '
      type == "array" and all(.[]; type == "number" and . >= 1 and floor == .)
    ' >/dev/null; then
    _dotfiles_ghostty_error "before-ID value must be a JSON array of numbers"
    return 2
  fi

  windows_json=$(_dotfiles_ghostty_windows_json) || return
  printf '%s\n' "$windows_json" | _dotfiles_ghostty_jq -er \
    --arg app "$app_name" \
    --arg title "$title" \
    --argjson before "$before_json" '
      [
        .[]
        | select(.app == $app)
        | select((.id as $id | $before | index($id)) == null)
      ] as $new
      | (($new | map(select($title != "" and .title == $title)) | last)
          // ($new | last)
          // empty)
      | .id
    '
}

dotfiles_ghostty_wait_for_window() {
  local title="${1:-}"
  local before_json="${2:-}"
  local timeout_ms="${3:-5000}"
  local poll_seconds="${4:-0.02}"
  local app_name="${5:-${DOTFILES_GHOSTTY_APP_NAME:-Ghostty}}"
  local deadline
  local window_id

  case "$timeout_ms" in
    ''|*[!0-9]*)
      _dotfiles_ghostty_error "Ghostty wait timeout must be a non-negative integer in milliseconds"
      return 2
      ;;
  esac
  if ! [[ "$poll_seconds" =~ ^([0-9]+([.][0-9]+)?|[.][0-9]+)$ ]]; then
    _dotfiles_ghostty_error "Ghostty poll interval must be a positive number of seconds"
    return 2
  fi
  if ! [[ "$poll_seconds" =~ [1-9] ]]; then
    _dotfiles_ghostty_error "Ghostty poll interval must be greater than zero"
    return 2
  fi
  if [ -z "$before_json" ] \
      || ! printf '%s\n' "$before_json" \
        | _dotfiles_ghostty_jq -e '
            type == "array" and all(.[]; type == "number" and . >= 1 and floor == .)
          ' >/dev/null; then
    _dotfiles_ghostty_error "before-ID value must be a JSON array of numbers"
    return 2
  fi

  deadline=$(( $(_dotfiles_ghostty_now_ms) + timeout_ms ))
  while :; do
    if window_id=$(dotfiles_ghostty_find_new_window_id "$title" "$before_json" "$app_name" 2>/dev/null); then
      printf '%s\n' "$window_id"
      return 0
    fi
    if [ "$(_dotfiles_ghostty_now_ms)" -ge "$deadline" ]; then
      return 1
    fi
    command sleep "$poll_seconds"
  done
}
