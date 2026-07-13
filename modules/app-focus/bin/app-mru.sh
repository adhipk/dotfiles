#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -r "$SCRIPT_DIR/../lib/config.sh" ]]; then
  DEFAULT_CONFIG_LIB="$SCRIPT_DIR/../lib/config.sh"
else
  DEFAULT_CONFIG_LIB="$HOME/.config/app-focus/config.sh"
fi
APP_FOCUS_CONFIG_LIB="${APP_FOCUS_CONFIG_LIB:-$DEFAULT_CONFIG_LIB}"
if [[ ! -r "$APP_FOCUS_CONFIG_LIB" ]]; then
  printf 'app-mru.sh: missing app-focus config adapter: %s\n' "$APP_FOCUS_CONFIG_LIB" >&2
  return 1 2>/dev/null || exit 1
fi
# shellcheck source=../lib/config.sh
source "$APP_FOCUS_CONFIG_LIB"

APP_MRU_DIR="${APP_MRU_DIR:-$(app_focus_state_directory)/app-mru}"

app_mru_require_tools() {
  if ! command -v yabai >/dev/null 2>&1; then
    echo "app-mru: yabai is not installed" >&2
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "app-mru: jq is not installed" >&2
    return 1
  fi
}

app_mru_state_file() {
  local app="$1"
  local slug

  slug=$(printf '%s' "$app" | tr '/' '_')
  printf '%s/%s.ids' "$APP_MRU_DIR" "$slug"
}

app_mru_eligible_ids() {
  local app="$1"
  local windows_json="${2:-}"

  if [ -z "$windows_json" ]; then
    windows_json=$(yabai -m query --windows)
  fi

  jq -r --arg app "$app" '
    [.[]
      | select(.app == $app)
      | select(."is-minimized" == false)
      | select(."is-hidden" == false)
      | select((.scratchpad // "") == "")
    ]
    | sort_by(.id)
    | .[].id
  ' <<<"$windows_json"
}

app_mru_write_stack() {
  local state_file="$1"
  shift
  local -a ids=("$@")
  local dir

  dir=$(dirname "$state_file")
  mkdir -p "$dir"

  if ((${#ids[@]} == 0)); then
    : >"$state_file"
    return
  fi

  printf '%s\n' "${ids[@]}" >"$state_file"
}

app_mru_id_in_list() {
  local candidate="$1"
  shift
  local id

  for id in "$@"; do
    [[ "$id" == "$candidate" ]] && return 0
  done

  return 1
}

app_mru_read_stack() {
  local app="$1"
  local state_file windows_json
  local -a stack=()
  local -a valid=()
  local -a live=()
  local id seen

  state_file=$(app_mru_state_file "$app")
  windows_json=$(yabai -m query --windows)
  live=($(app_mru_eligible_ids "$app" "$windows_json"))

  if ((${#live[@]} == 0)); then
    app_mru_write_stack "$state_file"
    return 0
  fi

  if [[ -f "$state_file" ]]; then
    while IFS= read -r id; do
      [[ -n "$id" ]] || continue
      stack+=("$id")
    done <"$state_file"
  fi

  for id in "${stack[@]}"; do
    if app_mru_id_in_list "$id" "${live[@]}"; then
      valid+=("$id")
    fi
  done

  for id in "${live[@]}"; do
    seen=false
    for existing in "${valid[@]}"; do
      if [[ "$existing" == "$id" ]]; then
        seen=true
        break
      fi
    done
    if [[ "$seen" == false ]]; then
      valid+=("$id")
    fi
  done

  app_mru_write_stack "$state_file" "${valid[@]}"
  printf '%s\n' "${valid[@]}"
}

app_mru_record_focus() {
  local app="$1"
  local wid="$2"
  local state_file
  local -a stack=()
  local -a next=()
  local id

  [[ -n "$app" && -n "$wid" ]] || return 0

  state_file=$(app_mru_state_file "$app")
  stack=()
  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    stack+=("$id")
  done < <(app_mru_read_stack "$app")

  next=("$wid")
  for id in "${stack[@]}"; do
    [[ "$id" == "$wid" ]] && continue
    next+=("$id")
  done

  app_mru_write_stack "$state_file" "${next[@]}"
}

app_mru_update_from_focus() {
  local focused_json app wid

  focused_json=$(yabai -m query --windows --window 2>/dev/null || true)
  app=$(jq -r '
    select(."is-minimized" == false)
    | select(."is-hidden" == false)
    | select((.scratchpad // "") == "")
    | .app // empty
  ' <<<"$focused_json")
  wid=$(jq -r '
    select(."is-minimized" == false)
    | select(."is-hidden" == false)
    | select((.scratchpad // "") == "")
    | .id // empty
  ' <<<"$focused_json")

  app_mru_record_focus "$app" "$wid"
}

app_mru_focus_window() {
  local win_id="$1"
  local windows_json current_space current_display target_space target_display

  windows_json=$(yabai -m query --windows)
  current_space=$(yabai -m query --spaces --space | jq -r '.index')
  current_display=$(yabai -m query --displays --display | jq -r '.index')

  target_space=$(jq -r --argjson win_id "$win_id" \
    '[.[] | select(.id == $win_id)] | first | .space // empty' <<<"$windows_json")
  target_display=$(jq -r --argjson win_id "$win_id" \
    '[.[] | select(.id == $win_id)] | first | .display // empty' <<<"$windows_json")

  if [[ -n "$target_space" && "$target_space" != "$current_space" ]]; then
    yabai -m space --focus "$target_space"
  elif [[ -n "$target_display" && "$target_display" != "$current_display" ]]; then
    yabai -m display --focus "$target_display"
  fi

  yabai -m window --focus "$win_id"
}

app_mru_focused_is_eligible_for_app() {
  local app="$1"
  local focused_json focused_id focused_app

  focused_json=$(yabai -m query --windows --window 2>/dev/null || true)
  focused_id=$(jq -r '.id // empty' <<<"$focused_json")
  focused_app=$(jq -r '.app // empty' <<<"$focused_json")

  if [[ "$focused_app" != "$app" || -z "$focused_id" ]]; then
    return 1
  fi

  jq -e --arg app "$app" --argjson id "$focused_id" '
    any(.[];
      .id == $id
      and .app == $app
      and ."is-minimized" == false
      and ."is-hidden" == false
      and ((.scratchpad // "") | length == 0)
    )
  ' <<<"$(yabai -m query --windows)" >/dev/null
}

app_mru_cycle() {
  local app="$1"
  local launch_cmd="${2:-}"
  local presentation_mode="${3:-false}"
  local focused_id
  local -a stack=()
  local index=-1
  local next_id=""
  local i

  stack=()
  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    stack+=("$id")
  done < <(app_mru_read_stack "$app")

  if ((${#stack[@]} == 0)); then
    if [[ -n "$launch_cmd" ]]; then
      eval "$launch_cmd"
    else
      open -a "$app"
    fi
    return 0
  fi

  focused_id=$(yabai -m query --windows --window 2>/dev/null | jq -r '.id // empty' || true)

  if app_mru_focused_is_eligible_for_app "$app"; then
    if [[ "$presentation_mode" == true ]]; then
      return 0
    fi

    if ((${#stack[@]} == 1)); then
      return 0
    fi

    for i in "${!stack[@]}"; do
      if [[ "${stack[$i]}" == "$focused_id" ]]; then
        index=$i
        break
      fi
    done

    if ((index >= 0)); then
      if ((index + 1 < ${#stack[@]})); then
        next_id="${stack[$((index + 1))]}"
      else
        next_id="${stack[0]}"
      fi
    else
      next_id="${stack[0]}"
    fi
  else
    next_id="${stack[0]}"
  fi

  app_mru_focus_window "$next_id"
}

app_mru_list() {
  local app="$1"
  local id

  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    printf '%s\n' "$id"
  done < <(app_mru_read_stack "$app")
}

app_mru_main() {
  local command="${1:-}"

  app_mru_require_tools || exit 1

  case "$command" in
    update)
      app_mru_update_from_focus
      ;;
    cycle)
      shift
      local app="${1:-}"
      local launch_cmd="${2:-}"
      local presentation_mode="${3:-false}"
      if [[ -z "$app" ]]; then
        echo "app-mru: cycle requires an app name" >&2
        exit 1
      fi
      app_mru_cycle "$app" "$launch_cmd" "$presentation_mode"
      ;;
    list)
      shift
      local app="${1:-}"
      if [[ -z "$app" ]]; then
        echo "app-mru: list requires an app name" >&2
        exit 1
      fi
      app_mru_list "$app"
      ;;
    *)
      cat <<EOF >&2
Usage:
  app-mru.sh update
  app-mru.sh cycle APP [LAUNCH_CMD] [PRESENTATION_MODE]
  app-mru.sh list APP
EOF
      exit 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  app_mru_main "$@"
fi
