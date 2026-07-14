# terminal-window-types

This module owns the standard tmux window-type workflow as one vertical slice:

- ordinary sessions receive `terminal:0`, `codex:1`, `nvim:2`, `tuxedo:3`, and
  `awrit:4`;
- `Ctrl+0/1/2/3` and Ghostty's `Cmd+Backtick/1/2/3` cycle by stable type;
- `Ctrl+Shift+0/1/2/3` creates a typed window in the active pane directory;
- `Shift+Enter` reaches Codex as an explicit CSI-u multiline-input sequence
  without enabling tmux-wide extended-key rewriting;
- Right Command+D/R in Ghostty duplicate and rename typed windows;
- the tmux command center exposes the same cycle, create, duplicate, and rename actions.

The canonical Awrit slot is a lazy typed shell: creating ordinary sessions or
scratchpads never launches a graphical browser. Explicit command-center
create/duplicate actions run `awrit` in that pane through Awrit's native tmux
renderer. Awrit is intentionally the first type without a new global shortcut. `Ctrl+4`
through `Ctrl+9` keep their direct-index contract, so `Ctrl+4` selects the
canonical Awrit slot while the command center's `a` action or the public CLI
cycles renamed/duplicated Awrit windows. The module enables tmux graphics
passthrough for Awrit while its launcher temporarily promotes only the browser
pane to hidden passthrough and restores that pane's inherited or explicit value
on exit. Other panes retain the safer visible-only policy, the existing mouse
policy, and the narrow Shift+Enter adapter; broad tmux extended-key rewriting
remains disabled.

Chezmoi keeps the public command at `~/bin/tmux-session-template` and mounts the
module-owned fragments into tmux, Ghostty, skhd, and tmux-which-key. Set
`modules.terminalWindowTypes.enabled` to `false` to remove every rendered
contribution and the installed helper without deleting unrelated target files.

## Public contracts

The helper tags each managed window with `@dotfiles_window_type` and each
managed session with `@dotfiles_tmux_template`. Other features may read those
options but must tolerate their absence. Scratchpads call the stable
`~/bin/tmux-session-template ensure` entrypoint when it is installed and fall
back to their single terminal window when the module is disabled.

The runtime requires Bash, tmux, and the public `core.sh` and `tmux.sh`
procedures installed at `~/.local/lib/dotfiles`. The standard profile also
supplies the `codex`, `nvim`, `todo`, and `awrit` commands declared by the
manifest. `todo` is a stable command dependency supplied by this repository's
separate `todo` module. `awrit` is the launch contract installed by the local
`~/awrit` checkout pinned from `adhipk/awrit` and keeps its project-local
Bun/Electron runtime. Chezmoi owns the stable `~/bin/awrit` symlink.

## Validate

From the repository root:

```sh
modules/terminal-window-types/tests/test_tmux_session_template.sh
modules/terminal-window-types/tests/test_module.sh
```
