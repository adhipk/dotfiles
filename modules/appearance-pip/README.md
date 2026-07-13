# appearance-pip

This macOS vertical slice owns tiled-window spacing, opacity and shadow policy,
session-colored JankyBorders, exact scratchpad border suppression, and managed
Picture-in-Picture windows.

## Boundary

The module owns `tmux-border-accent`, `tile-pip-window`, yabai signal/style/
display-padding/startup fragments, tmux border-update hooks, tests, and this
manifest. The parent retains only conditional mounts, stable executable
bridges, and idempotent removal of PiP signal/rule labels so disabling the
module reconciles previously loaded yabai state.

Spaces and their labels remain outside the module. The per-space padding
fragment consumes the spaces that already exist but neither creates, removes,
nor labels them. Scratchpads remain independent and optionally call the stable
`~/bin/tmux-border-accent suppress-scratchpads` contract. When their yabai
windows expose a non-empty `scratchpad` property, border updates restore an
exact transparent per-window override; normal Ghostty windows keep their
session accent.

PiP signals call the stable `~/.config/yabai/tile-pip-window` path. The helper
only acts on the literal `Picture in Picture` title, removes sticky/float state,
and restores the automatic sub-layer so yabai can tile the window normally.

## Removal and portability

Set `modules.appearancePip.enabled` to `false` to remove both commands and all
rendered yabai/tmux contributions. Signal and rule cleanup remains in the
shared yabai target, so it still renders after this folder is physically
removed. No filesystem state is owned by the module.

The module requires macOS, Bash, JankyBorders' `borders` command, jq, tmux, and
yabai. `tmux-border-accent` reads the public `@dotfiles_status_accent` option
when available and safely falls back to black when no focused tmux accent is
published. It also relies on JankyBorders' launchd command endpoint for exact
window overrides.

Validate from the repository root:

```sh
tests/test_tmux_border_accent.sh
dotfiles-module validate --json
```
