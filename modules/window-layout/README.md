# window-layout

This macOS vertical slice owns focused-window layout actions while yabai and
skhd remain shared target services. It preserves the existing cycling,
half-screen snapping, directional swapping and resizing, fullscreen, split,
balance, rotate, mirror, remembered float, stack, close, and minimize behavior.

## Boundary

The module owns both runtime helpers, every associated skhd binding, yabai's
BSP, pointer, split, balance, and non-tileable-window policy, its manifest, and
focused tests. The parent keeps only conditional target includes, stable
executable bridges, and harmless rule cleanup needed to reconcile a disable.
Appearance, PiP, spaces, displays, service reload, app focus, and scratchpads
remain outside this folder.

`~/.config/skhd/notify.sh` is an optional shared adapter used for float notices.
The module's only persistent state is
`~/.config/yabai/floating-windows.json`; uninstall preserves it and purge may
remove it after explicit confirmation.

Set `modules.windowLayout.enabled` to `false` to remove the installed helpers
and rendered contributions. Once disabled, deleting this folder leaves the
parent skhd and yabai targets renderable.

## Dependencies and validation

The manifest declares Bash, bc, jq, yabai, and yq. macOS supplies the small
POSIX utilities used for hashing and atomic state writes; `terminal-notifier`
is optional through the shared notification adapter.

From the repository root:

```sh
tests/test_window_layout.sh
dotfiles-module validate --json
```
