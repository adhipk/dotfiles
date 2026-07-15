# terminal-window-types

This module owns the standard tmux window-type workflow as one vertical slice:

- ordinary sessions receive `terminal:0`, `codex:1`, `nvim:2`, and `tuxedo:3`;
- `Ctrl+0/1/2/3` and Ghostty's `Cmd+Backtick/1/2/3` cycle by stable type;
- `Ctrl+Shift+0/1/2/3` creates a typed window in the active pane directory;
- `Shift+Enter` reaches Codex as an explicit CSI-u multiline-input sequence
  without enabling tmux-wide extended-key rewriting;
- Right Command+D/R in Ghostty duplicate and rename typed windows;
- the tmux command center exposes the same cycle, create, duplicate, and rename actions.

Chezmoi keeps the public command at `~/bin/tmux-session-template` and mounts the
module-owned fragments into tmux, Ghostty, skhd, and tmux-which-key. Set
`modules.terminalWindowTypes.enabled` to `false` to remove every rendered
contribution and the installed helper without deleting unrelated target files.

A run-on-change ChezMoi migration removes only the legacy managed
`~/bin/awrit -> ~/awrit/awrit` symlink. It preserves the `~/awrit` checkout and
leaves regular files or symlinks with any other target unchanged.

## Public contracts

The helper tags each managed window with `@dotfiles_window_type` and each
managed session with `@dotfiles_tmux_template`. Other features may read those
options but must tolerate their absence. Scratchpads call the stable
`~/bin/tmux-session-template ensure` entrypoint when it is installed and fall
back to their single terminal window when the module is disabled.

The runtime requires Bash, tmux, and the public `core.sh` and `tmux.sh`
procedures installed at `~/.local/lib/dotfiles`. The standard profile also
supplies the `codex`, `nvim`, and `todo` commands declared by the manifest.
`todo` is a stable command dependency supplied by this repository's separate
`todo` module.

## Validate

From the repository root:

```sh
modules/terminal-window-types/tests/test_tmux_session_template.sh
modules/terminal-window-types/tests/test_module.sh
```
