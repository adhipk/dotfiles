# Configuration adapter for the scratchpads module.
#
# SCRATCHPADS_CONFIG_FILE selects another TOML file. SCRATCHPADS_YQ_BIN selects
# the yq executable used to read it. Missing files and keys retain the current
# behavior so a copied module remains usable before its config is installed.

scratchpads_config_file() {
  printf '%s\n' "${SCRATCHPADS_CONFIG_FILE:-$HOME/.config/scratchpads/config.toml}"
}

scratchpads_config_string() {
  local key="$1"
  local fallback="$2"
  local config_file
  local value=""
  local yq_bin="${SCRATCHPADS_YQ_BIN:-yq}"

  config_file=$(scratchpads_config_file)
  if [[ -r "$config_file" ]] && command -v "$yq_bin" >/dev/null 2>&1; then
    value=$(command "$yq_bin" -p=toml -r "$key // \"\"" "$config_file" 2>/dev/null || true)
  fi

  if [[ -n "$value" && "$value" != "null" ]]; then
    printf '%s\n' "$value"
  else
    printf '%s\n' "$fallback"
  fi
}

scratchpads_home_path() {
  local value="$1"

  case "$value" in
    '~') printf '%s\n' "$HOME" ;;
    '~/'*) printf '%s/%s\n' "$HOME" "${value#\~/}" ;;
    /*) printf '%s\n' "$value" ;;
    *) printf '%s/%s\n' "$HOME" "$value" ;;
  esac
}
