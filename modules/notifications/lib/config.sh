# Configuration adapter for the notifications module.
#
# DESKTOP_NOTIFY_CONFIG_FILE selects another TOML file. DESKTOP_NOTIFY_YQ_BIN
# selects the yq executable used to read it. A copied module falls back to its
# checked-in defaults; installed commands use ~/.config/notifications/config.toml.

desktop_notify_config_file() {
  if [[ -n "${DESKTOP_NOTIFY_CONFIG_FILE:-}" ]]; then
    printf '%s\n' "$DESKTOP_NOTIFY_CONFIG_FILE"
    return
  fi

  local config_dir
  config_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../config" 2>/dev/null && pwd || true)"
  if [[ -n "$config_dir" && -r "$config_dir/defaults.toml" ]]; then
    printf '%s\n' "$config_dir/defaults.toml"
  else
    printf '%s\n' "$HOME/.config/notifications/config.toml"
  fi
}

desktop_notify_config_value() {
  local key="$1" fallback="$2" config_file value=""
  local yq_bin="${DESKTOP_NOTIFY_YQ_BIN:-yq}"
  config_file=$(desktop_notify_config_file)

  if [[ -r "$config_file" ]] && command -v "$yq_bin" >/dev/null 2>&1; then
    value=$(command "$yq_bin" -p=toml -r "$key // \"\"" "$config_file" 2>/dev/null || true)
  fi

  if [[ -n "$value" && "$value" != "null" ]]; then
    printf '%s\n' "$value"
  else
    printf '%s\n' "$fallback"
  fi
}
