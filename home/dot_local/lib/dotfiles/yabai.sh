# Thin yabai query and focus-origin procedures. Feature-specific labels, rules,
# filtering, and movement policy belong to their owning modules.
#
# Public API:
#   dotfiles_yabai_cmd ARG...
#   dotfiles_yabai_query_windows
#   dotfiles_yabai_query_window [WINDOW_ID]
#   dotfiles_yabai_query_focused_space
#   dotfiles_yabai_query_focused_display
#   dotfiles_yabai_capture_focus_origin
#   dotfiles_yabai_restore_focus_origin [ORIGIN_JSON]

_dotfiles_yabai_error() {
  if command -v dotfiles_error >/dev/null 2>&1; then
    dotfiles_error "$@"
  else
    printf 'dotfiles: error: %s\n' "$*" >&2
  fi
}

_dotfiles_yabai_jq() {
  local jq_bin="${DOTFILES_JQ_BIN:-jq}"

  if ! command -v "$jq_bin" >/dev/null 2>&1; then
    _dotfiles_yabai_error "$jq_bin is required"
    return 127
  fi
  command "$jq_bin" "$@"
}

dotfiles_yabai_cmd() {
  local yabai_bin="${DOTFILES_YABAI_BIN:-yabai}"

  if ! command -v "$yabai_bin" >/dev/null 2>&1; then
    _dotfiles_yabai_error "$yabai_bin is required"
    return 127
  fi
  command "$yabai_bin" -m "$@"
}

dotfiles_yabai_query_windows() {
  dotfiles_yabai_cmd query --windows
}

dotfiles_yabai_query_window() {
  if [ "$#" -gt 0 ] && [ -n "${1:-}" ]; then
    dotfiles_yabai_cmd query --windows --window "$1"
  else
    dotfiles_yabai_cmd query --windows --window
  fi
}

dotfiles_yabai_query_focused_space() {
  dotfiles_yabai_cmd query --spaces --space
}

dotfiles_yabai_query_focused_display() {
  dotfiles_yabai_cmd query --displays --display
}

dotfiles_yabai_capture_focus_origin() {
  local display_json
  local space_json
  local window_json="null"
  local candidate=""

  display_json=$(dotfiles_yabai_query_focused_display) || return
  space_json=$(dotfiles_yabai_query_focused_space) || return
  if candidate=$(dotfiles_yabai_query_window 2>/dev/null); then
    window_json="$candidate"
  fi

  _dotfiles_yabai_jq -cen \
    --argjson display "$display_json" \
    --argjson space "$space_json" \
    --argjson window "$window_json" '
      def positive_integer:
        (type == "number") and (. >= 1) and (floor == .);
      if (($display.index | positive_integer) | not) or (($space.index | positive_integer) | not) then
        error("focused display and space must have numeric indices")
      else
        {
          displayIndex: $display.index,
          spaceIndex: $space.index,
          windowId: (if (($window | type) == "object" and ($window.id | positive_integer)) then $window.id else null end)
        }
      end
    '
}

dotfiles_yabai_restore_focus_origin() {
  local origin_json="${1:-}"
  local values
  local display_index
  local space_index
  local window_id
  local status=0

  if [ -z "$origin_json" ]; then
    origin_json=$(command cat) || return
  fi
  if ! values=$(printf '%s\n' "$origin_json" | _dotfiles_yabai_jq -er '
      def positive_integer:
        (type == "number") and (. >= 1) and (floor == .);
      if (.displayIndex | positive_integer)
        and (.spaceIndex | positive_integer)
        and ((.windowId == null) or (.windowId | positive_integer))
      then [.displayIndex, .spaceIndex, (.windowId // "")] | @tsv
      else error("invalid focus origin")
      end
    '); then
    _dotfiles_yabai_error "focus origin must contain positive integer display/space IDs and an optional window ID"
    return 2
  fi
  IFS="$(printf '\t')" read -r display_index space_index window_id <<EOF
$values
EOF

  dotfiles_yabai_cmd display --focus "$display_index" >/dev/null 2>&1 || status=1
  dotfiles_yabai_cmd space --focus "$space_index" >/dev/null 2>&1 || status=1
  if [ -n "$window_id" ]; then
    dotfiles_yabai_cmd window --focus "$window_id" >/dev/null 2>&1 || status=1
  fi
  return "$status"
}
