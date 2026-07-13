# tmux-sessions

This module owns the durable tmux session workflow as one removable vertical
slice:

- sesh-backed session and project pickers;
- shell and tmux session-selection controls;
- import-free `.tmux.tsx` workspace layouts and their Bun runtime;
- per-client last-session and safe session-close behavior;
- tmux-resurrect/continuum configuration plus workspace metadata sidecars;
- session, persistence, and layout actions in the tmux command center.

Chezmoi keeps the public commands at `~/bin/tmux-session-picker`,
`~/bin/tmux-sessionizer`, `~/bin/tmux-sessionizer-zoxide`, and
`~/bin/tmux-workspace`. The source of truth for all four commands, the sesh
configuration, and the managed layouts lives in this folder. Thin guarded
templates under `home/` are the only source-state integration points.

Set `modules.tmuxSessions.enabled` to `false` to remove the commands, sesh
configuration, managed layouts, shell key bindings, tmux session bindings,
persistence plugins, and command-center contributions. The guarded `.zshrc`
source line remains harmless when the generated shell fragment is absent.
Disabling or uninstalling preserves both tmux-resurrect snapshots and
`tmux-workspace` metadata; an explicitly confirmed purge may delete them.

## Boundaries

The module requires Bash, Bun, fzf, sesh, tmux, and zoxide. Its workspace
runtime accepts `TMUX_WORKSPACE_LAYOUT_DIR`, `TMUX_WORKSPACE_TMUX_SOCKET`, and
`TMUX_WORKSPACE_STATE_HOME`, which keeps its tests and standalone use isolated
from the parent repository.

Window-type and Yazi process declarations remain in their own modules. The
parent tmux bridge composes those optional process names into the single
`@resurrect-processes` option while this module owns the persistence engine.
The base tmux prefix, panes, copy mode, appearance, TPM bootstrap, and the base
command-center document are shared parent concerns and remain outside this
folder.

## Validate

From the repository root:

```sh
modules/tmux-sessions/tests/test_module.sh
modules/tmux-sessions/tests/test_tmux_workspace.sh
modules/tmux-sessions/tests/test_tmux_persistence.sh
tests/test_tmux_which_key.sh
```
