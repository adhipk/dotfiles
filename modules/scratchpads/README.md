# scratchpads

This module owns the transient Ghostty scratchpad workflow:

- `Fn+Comma` toggles one opaque terminal panel on the `dotfiles` tmux session.
- `Fn+1` reuses that panel for the separate `projects` tmux session.
- Repeating the active shortcut hides the panel even after focus moved away.
- Concurrent launches are serialized and same-title launch-race duplicates are
  removed without touching ordinary Ghostty windows.
- `scratchpads open quick` and the legacy quick-terminal helper remain
  available as a bottom-third terminal scratchpad.

Chezmoi keeps the public `~/bin/scratchpads` path stable through a thin bridge.
The checked-in TOML defaults are installed at
`~/.config/scratchpads/config.toml`; `SCRATCHPADS_CONFIG_FILE` can select a
different file, and the existing `SCRATCHPAD_*` environment variables still
override individual runtime values.

## Boundary

The module owns its command, config adapter, default config, skhd bindings,
yabai rule registration, tests, and documentation. The parent retains only
conditional target includes and unconditional removal of historical yabai
rules/signals so disabling or physically removing this module cleans prior
runtime registration safely.

The following are intentional public dependencies left outside the module:

- `~/bin/tmux-session-template` optionally adds the standard typed windows;
  without it, each scratchpad session still starts with its raw terminal.
- `~/bin/tmux-border-accent` optionally suppresses the exact scratchpad border.
- app focus, space creation, the shortcut guide, and border rendering may
  recognize yabai's public `.scratchpad` label but do not own this module.

The runtime requires macOS, Bash, `jq`, `yq`, `tmux`, yabai, and Ghostty. It
stores only temporary launch locks/logs and tmux options; there is no persistent
user data to purge.

## Validate

From the dotfiles repository root:

```sh
modules/scratchpads/tests/test_scratchpads.sh
modules/scratchpads/tests/test_module.sh
chezmoi -S "$PWD" cat ~/.skhdrc
chezmoi -S "$PWD" cat ~/.yabairc
```
