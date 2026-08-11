# Runtime access to managed user preferences.
#
# Public API:
#   dotfiles_prefs_file
#   dotfiles_pref KEY FALLBACK
#
# DOTFILES_PREFS_FILE selects another TOML file. DOTFILES_PREFS_YQ_BIN selects
# the yq executable used to read it. DOTFILES_PREF_<UPPERCASE_KEY> overrides a
# single value for one session. Missing files and missing keys return the
# fallback so consumers remain usable as copied bundles.

dotfiles_prefs_file() {
  printf '%s\n' "${DOTFILES_PREFS_FILE:-$HOME/.config/dotfiles/preferences.toml}"
}

dotfiles_pref() {
  local key="$1"
  local fallback="${2:-}"
  local prefs_file
  local value=""
  local override_name override_value
  local yq_bin="${DOTFILES_PREFS_YQ_BIN:-yq}"

  override_name="DOTFILES_PREF_$(printf '%s' "$key" | tr '[:lower:]' '[:upper:]')"
  override_value="${!override_name:-}"
  if [[ -n "$override_value" ]]; then
    printf '%s\n' "$override_value"
    return 0
  fi

  prefs_file=$(dotfiles_prefs_file)
  if [[ -r "$prefs_file" ]] && command -v "$yq_bin" >/dev/null 2>&1; then
    value=$(command "$yq_bin" -p=toml -r ".${key} // \"\"" "$prefs_file" 2>/dev/null || true)
  fi

  if [[ -n "$value" && "$value" != "null" ]]; then
    printf '%s\n' "$value"
  else
    printf '%s\n' "$fallback"
  fi
}
