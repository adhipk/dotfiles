# tmux-yazi

This module owns the terminal-facing Yazi workflow:

- `Cmd+B` toggles one full-height, 40%-wide Yazi pane beside the active pane.
- The pane shows hidden files by default and sends opened files to the current
  tmux session's typed Neovim window, creating that window when absent.
- `Cmd+Shift+B` opens or selects a dedicated Yazi tmux window.
- The tmux command center exposes both actions.
- tmux-resurrect includes the dedicated Yazi process while the module is enabled.

The installed commands are `~/bin/tmux-yazi-pane` and `~/bin/tmux-yazi-open`.
Chezmoi renders those stable paths from `bin/`; target-service files include
the fragments under `targets/` when `modules.tmuxYazi.enabled` is true.

## Dependencies

The runtime requires Bash, `tmux`, `yazi`, the typed-window
`tmux-session-template` helper, and the public `core.sh` and `tmux.sh`
procedures from `~/.local/lib/dotfiles`. The parent dotfiles profile provides
the commands through the shared Brewfile and installs the standard library
with chezmoi.

The module stores no files of its own. Its pane marker and per-window lock are
declared as ephemeral tmux state in `module.yaml`, so disabling the module
removes its rendered command and integrations without deleting user data.

## Validate

From the dotfiles repository root:

```sh
modules/tmux-yazi/tests/test_tmux_yazi_pane.sh
modules/tmux-yazi/tests/test_tmux_yazi_open.sh
chezmoi -S "$PWD" cat ~/.tmux.conf
chezmoi -S "$PWD" cat ~/.config/tmux/which-key.yaml
```
