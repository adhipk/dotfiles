# space-display

This macOS vertical slice owns yabai space creation/removal, adjacent-display
movement, scripting-addition loading, the fixed four-space policy, legacy
space bookmarks, and yabai repair/setup commands.

## Active behavior

- `Option+Shift+[` / `Option+Shift+]` moves the focused window to the previous
  or next display and follows it without losing the original window ID.
- `Option+n` creates and focuses a space, moving the focused non-scratchpad
  window only when another normal window remains. `Control+Option+n` forces
  that move when a normal window is focused.
- `Option+k` removes empty spaces from highest index to lowest, but refuses to
  remove every space and rechecks the remaining count before each deletion.
- On yabai load, the scripting addition is attempted and a labeled Dock-restart
  signal reloads it. Display 1 is brought to at least four spaces when the SA
  is available, with stable `browser`, `editor`, `comms`, and `empty` labels.

Legacy bookmark state remains at `~/.config/yabai/space-bookmarks.json` and is
declared preserved. `~/.config/skhd/notify.sh` is an optional shared notice
adapter; no bookmark shortcut is installed.

## Package authority

`reset-yabai` no longer carries a private tap or hard-coded yabai version. It
reads the yabai formula from `${DOTFILES_BREWFILE:-$HOME/dotfiles/Brewfile}`,
reinstalls/links/pins that formula through Homebrew, installs the service, and
delegates checksum-scoped sudoers validation and SA loading to
`setup-yabai-sa`. This makes the Brewfile the single package authority.

## Boundary and removal

The parent owns only conditional executable bridges, guarded skhd/yabai mounts,
and idempotent cleanup of the labeled Dock-restart signal. Appearance padding
may inspect spaces after this module runs, but this module does not depend on
appearance, window-layout, app-focus, scratchpad, or tmux internals.

Set `modules.spaceDisplay.enabled` to `false` to remove all commands, bindings,
and fixed-space policy while preserving bookmark state. After disable, this
folder can be physically removed without breaking unrelated target rendering.

Validate from the repository root:

```sh
tests/test_space_display.sh
dotfiles-module validate --json
```
