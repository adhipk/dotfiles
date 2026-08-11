# app-focus

This vertical slice owns application focus and its two runtime modes without
owning skhd or yabai as whole services.

Current shortcuts remain literal:

- `Alt+Backtick` focuses or MRU-cycles normal Ghostty windows and launches a
  normal terminal when none exists. Scratchpads are never focus candidates.
- `Alt+1` resolves the current macOS HTTPS handler, `Alt+2` focuses the editor,
  `Alt+3` focuses Microsoft Teams, and `Alt+4` focuses Slack. Entering an app
  restores its most-recent window; repeating its shortcut chooses the
  least-recently-used eligible window and promotes it, so repeated presses
  traverse windows by recency. Scratchpads remain excluded. Focus events caused
  by the shortcut are suppressed briefly so the explicit promotion is not
  applied twice; manual focus still promotes a window normally.
- `Fn+1..9` focuses open normal tmux Ghostty windows in creation order.
  Scratchpads, detached persistent sessions, and non-tmux terminal windows do
  not consume a slot.
- `Fn+Tab` cycles forward through those same windows and wraps after the last.
- `Alt+Backslash` toggles presentation mode. Repeating an app shortcut while
  that app is already focused stays on the current window instead of cycling.
- `Alt+Shift+Backslash` toggles zen mode. The configured slots `3`, `4`, and
  `5` become no-ops, while terminal, browser, and editor focus remain active.
- `Alt+Shift+Backtick` opens a normal terminal on the originating yabai space
  and display, with the existing key-repeat guard.

## Boundary

Owned source lives in this folder: `hotkeys`, `focus_app.sh`, `app-mru.sh`,
`focus-open-tmux-window.sh`, the TOML defaults, target-service fragments, and
tests. The parent only provides stable target bridges and conditional
`includeTemplate` calls in `.skhdrc` and `.yabairc`. Disabling
`modules.appFocus.enabled` removes all exclusive targets and rendered bindings;
yabai keeps one harmless signal-removal line so a previously registered
`app_mru_update` hook is cleaned up on reload.

The shared `~/.config/skhd/notify.sh` helper intentionally remains outside the
module because other desktop features use it. It is an optional adapter: set
`APP_FOCUS_NOTIFY_COMMAND` to another executable, or omit it for silent mode.

## Configuration

ChezMoi installs the standard TOML file at
`~/.config/app-focus/config.toml`. It controls the default editor, terminal,
mode-state directory, zen-blocked slots, and notification adapter. Override its
location with `APP_FOCUS_CONFIG_FILE`; `EDITOR_APP`, `TERMINAL_APP`,
`ZEN_BLOCKED_SLOTS`, and `APP_MRU_DIR` remain runtime overrides.

The current state paths are preserved for behavior compatibility and declared
as ephemeral in `module.yaml`:

- `~/.config/skhd/app-mru/`
- `~/.config/skhd/presentation_mode`
- `~/.config/skhd/zen_mode`

## Portability

The bundle targets macOS and declares Bash, jq, yabai, and yq. macOS supplies
`open`, `osascript`, `stat`, and `date`; Perl is used for the millisecond
terminal-launch guard. `terminal-notifier` is optional. A copied bundle can run
its commands directly because they discover `../lib/config.sh`, or a packager
can install the manifest targets at their documented stable paths.

Validate from the repository root:

```sh
modules/app-focus/tests/test_module.sh
chezmoi -S "$PWD" cat ~/.skhdrc
chezmoi -S "$PWD" cat ~/.yabairc
```
