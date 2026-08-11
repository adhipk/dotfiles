# tmux-sessions

This module owns the durable tmux session workflow as one removable vertical
slice:

- sesh-backed session and project pickers;
- shell and tmux session-selection controls;
- import-free `.tmux.tsx` workspace layouts and their Bun runtime;
- per-client last-session and safe session-close behavior;
- tmux-resurrect/continuum configuration plus workspace metadata sidecars;
- session, persistence, and layout actions in the tmux command center;
- a persistent `hub` session that stays on the normal tmux server, derives
  `WAIT`/`ERR`/`READY`/`WORK` from live panes, summarizes active projects and
  their open global tasks, previews the selected pane, accepts explicit manual
  replies, and joins the global todo queue without owning a second session
  registry. Full agent, task, and session inventories stay in searchable
  drilldowns instead of filling the default screen.

Chezmoi keeps the public commands at `~/bin/daemon`, `~/bin/tmux-session-picker`,
`~/bin/tmux-sessionizer`, `~/bin/tmux-sessionizer-zoxide`, `~/bin/tmux-hub`,
and `~/bin/tmux-workspace`. The source of truth for these commands, the sesh
configuration, and the managed layouts lives in this folder. Thin guarded
templates under `home/` are the only source-state integration points.

Set `modules.tmuxSessions.enabled` to `false` to remove the commands, sesh
configuration, managed layouts, shell key bindings, tmux session bindings,
persistence plugins, and command-center contributions. The guarded `.zshrc`
source line remains harmless when the generated shell fragment is absent.
Disabling or uninstalling preserves both tmux-resurrect snapshots and
`tmux-workspace` metadata; an explicitly confirmed purge may delete them.

## Boundaries

The module requires Bash, Bun, fzf, Neovim, sesh, tmux, and zoxide. Its workspace
runtime accepts `TMUX_WORKSPACE_LAYOUT_DIR`, `TMUX_WORKSPACE_TMUX_SOCKET`, and
`TMUX_WORKSPACE_STATE_HOME`, which keeps its tests and standalone use isolated
from the parent repository.

Window-type and Yazi process declarations remain in their own modules. The
parent tmux bridge composes those optional process names into the single
`@resurrect-processes` option while this module owns the persistence engine.
The base tmux prefix, panes, copy mode, appearance, TPM bootstrap, and the base
command-center document are shared parent concerns and remain outside this
folder.

The hub is intentionally an observer and manual control surface over ordinary
tmux. It does not create agent-specific sessions, run a daemon, open a private
tmux socket, inject MCP configuration, or maintain a database. `READY` means a
supported agent process is alive with no strong visible busy, blocking, or error
signal; vanilla tmux cannot distinguish an idle prompt from a just-finished turn
without introducing agent-specific durable state. Pressing `Space` on a
`WAIT`/`READY`/`ERR` agent is the only path that submits terminal input. It
resolves the immutable pane ID again and uses tmux's bracket-aware paste buffer;
the hub never answers agents automatically.

## Hub controls

- The default view shows attention items, one compact row per active or
  task-backed project, up to five open task titles, and one stale-session
  cleanup summary.
- `Enter` shows or hides the agents inside the selected project; on an agent or
  task row it jumps to the associated tmux target.
- `x` confirms and closes the selected agent's or session's tmux session.
- `X` opens the cleanup picker; use `Tab` to mark multiple sessions and
  `Enter` to review one confirmation before closing them.
- `Space` prompts for a one-line reply to the selected non-working agent.
- `o` attaches the selected session in a fresh Ghostty window.
- `s`, `a`, `p`, and `t` search sessions, agents, attention requests, or todos.
- The right-hand split follows the cursor and shows the selected live pane.

The manager session is excluded from both close paths. Every close command
resolves an immutable tmux session ID immediately before `kill-session`, and
the confirmation names attached and actively working sessions before their
processes are stopped.

## Validate

From the repository root:

```sh
modules/tmux-sessions/tests/test_module.sh
modules/tmux-sessions/tests/test_tmux_workspace.sh
modules/tmux-sessions/tests/test_tmux_persistence.sh
tests/test_tmux_which_key.sh
```
