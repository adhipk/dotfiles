#!/usr/bin/env bash
# man-me: name=install.sh
# man-me: category=Repository Setup
# man-me: usage=./install.sh [chezmoi apply args...]
# man-me: description=Apply this source state, install tmux plugins and the managed command center, reload tmux and Ghostty, and build the native shortcut-guide app on macOS.
# man-me: tags=install setup apply chezmoi dotfiles todo tasks tuxedo tmux ghostty plugins tpm command center whichkey shortcut guide bootstrap
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
CHEZMOI_SOURCE_ROOT="$DOTFILES_DIR"
CHEZMOI_DESTINATION="${HOME:?HOME is not set}"
MODULE_CONTROLLER="$DOTFILES_DIR/modules/module-lifecycle/bin/dotfiles-module"
DEPENDENCY_CONTROLLER="${DOTFILES_DEPS_BIN:-$DOTFILES_DIR/modules/dependencies/bin/dotfiles-deps}"

activate_homebrew_path() {
    local brew_prefix

    command -v brew >/dev/null 2>&1 || return 0
    brew_prefix=$(brew --prefix 2>/dev/null) || return 0
    [[ -d "$brew_prefix/bin" ]] || return 0
    export PATH="$brew_prefix/bin:$PATH"
    hash -r
}

require_dependency_python() {
    [[ "$DEPENDENCY_CONTROLLER" == "$DOTFILES_DIR/modules/dependencies/bin/dotfiles-deps" ]] || return 0

    if ! command -v python3 >/dev/null 2>&1 \
        || ! python3 -c 'import tomllib' >/dev/null 2>&1; then
        echo "A Python 3.11+ runtime with tomllib is required. Run ./bootstrap.sh or brew install python." >&2
        return 1
    fi
}

activate_homebrew_path

if ! command -v chezmoi >/dev/null 2>&1; then
    echo "chezmoi is not installed. Run ./bootstrap.sh or brew install chezmoi." >&2
    exit 1
fi

validate_modules() {
    if [[ ! -x "$MODULE_CONTROLLER" ]]; then
        echo "Module lifecycle controller is missing or not executable: $MODULE_CONTROLLER" >&2
        return 1
    fi

    echo "[dotfiles] validating module manifests..."
    DOTFILES_DIR="$DOTFILES_DIR" "$MODULE_CONTROLLER" validate --json >/dev/null
}

is_dry_run=false
for arg in "$@"; do
    if [[ "$arg" == "--dry-run" || "$arg" == "-n" ]]; then
        is_dry_run=true
        break
    fi
done

show_status() {
    local status

    status=$(chezmoi -S "$CHEZMOI_SOURCE_ROOT" status)
    if [[ -n "$status" ]]; then
        printf '%s\n' "$status"
        if grep -qE '^[[:space:]]*R[[:space:]]+\.chezmoiscripts/' <<<"$status"; then
            echo "  note: R .chezmoiscripts entries are run-after hooks evaluated on every apply."
        fi
    else
        echo "  (none)"
    fi
}

show_managed_file_summary() {
    local status

    status=$(chezmoi -S "$CHEZMOI_SOURCE_ROOT" status --exclude=scripts)
    if [[ -n "$status" ]]; then
        echo "[dotfiles] managed files still differ after apply:"
        printf '%s\n' "$status"
    else
        echo "[dotfiles] managed files are up to date."
    fi
}

build_whichkey() {
    local build_script="$DOTFILES_DIR/scripts/build-whichkey.sh"

    [[ "$(uname -s)" == "Darwin" ]] || return 0
    [[ -x "$build_script" ]] || return 0

    echo "[dotfiles] building shortcut guide..."
    WHICHKEY_INSTALL_PATH="$CHEZMOI_DESTINATION/.config/skhd/whichkey" \
        "$build_script"
}

ensure_workspace_directories() {
    mkdir -p "$CHEZMOI_DESTINATION/projects"
}

install_tmux_plugins() {
    local installer="$CHEZMOI_DESTINATION/.tmux/plugins/tpm/bin/install_plugins"

    if [[ ! -x "$installer" ]]; then
        echo "[dotfiles] tmux plugin manager is missing after chezmoi apply: $installer" >&2
        return 1
    fi

    echo "[dotfiles] installing tmux plugins..."
    HOME="$CHEZMOI_DESTINATION" \
        TMUX_PLUGIN_MANAGER_PATH="$CHEZMOI_DESTINATION/.tmux/plugins/" \
        "$installer"
}

apply_tmux_plugin_pins() {
    if [[ ! -x "$DEPENDENCY_CONTROLLER" ]]; then
        echo "[dotfiles] dependency pin controller is missing: $DEPENDENCY_CONTROLLER" >&2
        return 1
    fi

    echo "[dotfiles] applying immutable tmux plugin pins..."
    HOME="$CHEZMOI_DESTINATION" DOTFILES_DIR="$DOTFILES_DIR" \
        "$DEPENDENCY_CONTROLLER" pins apply --manager tpm
}

install_tmux_command_center() {
    local plugin_dir="$CHEZMOI_DESTINATION/.tmux/plugins/tmux-which-key"
    local managed_config="$CHEZMOI_DESTINATION/.config/tmux/which-key.yaml"

    if [[ ! -d "$plugin_dir" ]]; then
        echo "[dotfiles] tmux-which-key is missing after TPM installation: $plugin_dir" >&2
        return 1
    fi
    if [[ ! -f "$managed_config" ]]; then
        echo "[dotfiles] managed tmux command-center config is missing: $managed_config" >&2
        return 1
    fi

    echo "[dotfiles] linking tmux command-center configuration..."
    ln -sfn "$managed_config" "$plugin_dir/config.yaml"
}

reload_tmux_config() {
    command -v tmux >/dev/null 2>&1 || return 0
    tmux list-sessions >/dev/null 2>&1 || return 0

    echo "[dotfiles] reloading tmux configuration..."
    if ! tmux source-file "$CHEZMOI_DESTINATION/.tmux.conf"; then
        echo "[dotfiles] warning: tmux configuration reload failed; run 'make reload' after fixing tmux errors." >&2
    fi
}

reload_ghostty_config() {
    [[ "$(uname -s)" == "Darwin" ]] || return 0
    command -v pkill >/dev/null 2>&1 || return 0

    # Ghostty does not watch its config. SIGUSR2 reloads every independently
    # launched app process, including the opaque scratchpad instance.
    if pkill -USR2 -f '/Ghostty[.]app/Contents/MacOS/ghostty([[:space:]]|$)' 2>/dev/null; then
        echo "[dotfiles] reloaded Ghostty configuration..."
    fi
}

echo "[dotfiles] repository:  $DOTFILES_DIR"
echo "[dotfiles] source:      $CHEZMOI_SOURCE_ROOT"
echo "[dotfiles] destination: $CHEZMOI_DESTINATION"
if [[ "$is_dry_run" == false ]]; then
    require_dependency_python
fi
validate_modules
echo "[dotfiles] pending changes before apply:"
show_status
if [[ "${DOTFILES_DEBUG:-0}" == "1" ]]; then
    echo "[dotfiles] running: chezmoi -S \"$CHEZMOI_SOURCE_ROOT\" apply --verbose $*"
    chezmoi -S "$CHEZMOI_SOURCE_ROOT" apply --verbose "$@"
else
    echo "[dotfiles] running: chezmoi -S \"$CHEZMOI_SOURCE_ROOT\" apply $*"
    chezmoi -S "$CHEZMOI_SOURCE_ROOT" apply "$@"
fi

if [[ "$is_dry_run" == true ]]; then
    echo "[dotfiles] dry run complete; no files were changed."
else
    ensure_workspace_directories
    install_tmux_plugins
    apply_tmux_plugin_pins
    install_tmux_command_center
    reload_tmux_config
    reload_ghostty_config
    build_whichkey
    echo "[dotfiles] pending changes after apply:"
    show_status
    show_managed_file_summary
    echo "[dotfiles] apply complete."
fi
