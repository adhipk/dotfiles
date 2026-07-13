# Configuration adapter for the app-focus module.
#
# APP_FOCUS_CONFIG_FILE selects another TOML file. APP_FOCUS_YQ_BIN selects the
# yq executable used to read it. Missing files and missing keys retain the
# checked-in defaults so the module remains usable as a copied bundle.

app_focus_config_file() {
  printf '%s\n' "${APP_FOCUS_CONFIG_FILE:-$HOME/.config/app-focus/config.toml}"
}

app_focus_config_string() {
  local key="$1"
  local fallback="$2"
  local config_file
  local value=""
  local yq_bin="${APP_FOCUS_YQ_BIN:-yq}"

  config_file=$(app_focus_config_file)
  if [[ -r "$config_file" ]] && command -v "$yq_bin" >/dev/null 2>&1; then
    value=$(command "$yq_bin" -p=toml -r "$key // \"\"" "$config_file" 2>/dev/null || true)
  fi

  if [[ -n "$value" && "$value" != "null" ]]; then
    printf '%s\n' "$value"
  else
    printf '%s\n' "$fallback"
  fi
}

app_focus_config_list() {
  local key="$1"
  local fallback="$2"
  local config_file
  local value=""
  local yq_bin="${APP_FOCUS_YQ_BIN:-yq}"

  config_file=$(app_focus_config_file)
  if [[ -r "$config_file" ]] && command -v "$yq_bin" >/dev/null 2>&1; then
    value=$(command "$yq_bin" -p=toml -r "($key // []) | join(\" \")" "$config_file" 2>/dev/null || true)
  fi

  printf '%s\n' "${value:-$fallback}"
}

app_focus_home_path() {
  local value="$1"

  case "$value" in
    '~') printf '%s\n' "$HOME" ;;
    '~/'*) printf '%s/%s\n' "$HOME" "${value#\~/}" ;;
    /*) printf '%s\n' "$value" ;;
    *) printf '%s/%s\n' "$HOME" "$value" ;;
  esac
}

app_focus_state_directory() {
  local configured
  configured=$(app_focus_config_string '.modes.state_directory' '.config/skhd')
  app_focus_home_path "$configured"
}
