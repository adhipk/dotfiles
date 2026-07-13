# Module lifecycle controller

`dotfiles-module` is the parent-side controller for module inventory, removal
planning, and source-preserving module lifecycle operations. It consumes only
the public `module.yaml` contract and keeps chezmoi as the target-state engine.

Every manifest target declares one of two ownership modes:

- `exclusive`: the entire installed target belongs to that module.
- `contribution`: the module renders into a shared target; lifecycle code must
  ask chezmoi to re-render the file and must never unlink it directly.

The executable module operations have deliberately distinct state boundaries:

- `dotfiles-module enable MODULE` sets the module's checked-in enable flag to
  `true`, applies only its declared bridges through chezmoi, and preserves all
  module source and state.
- `dotfiles-module disable MODULE` sets the module's checked-in enable flag to
  `false`, applies only its declared bridges through chezmoi, and preserves all
  module source and state.
- `dotfiles-module uninstall MODULE` performs the same target-state apply, then
  removes only declared ephemeral filesystem state. It preserves the module
  folder, parent bridges, and declared persistent state.
- `dotfiles-module purge MODULE --confirm MODULE` additionally removes declared
  persistent filesystem state. The confirmation must exactly match the module
  ID.

Relative state entries such as `./todo.txt` are never interpreted relative to
the source repository or the caller's current directory. An uninstall or purge
that reaches one requires `--state-root ABSOLUTE_DIR`. Home-relative entries
must remain beneath a real, non-symlink `$HOME`; parent symlink traversal is
rejected. Recognized non-filesystem handles, currently tmux pane options and
wait channels, are retained with an explicit warning until their modules
declare typed cleanup hooks.

Mutating operations share a repository lock. The data file is copied to a
backup, changed with `yq` in a temporary file, and atomically replaced. If the
targeted chezmoi apply fails, the original data file is restored and the same
bridges are reapplied to roll back any partial target changes.

Run `dotfiles-module validate [--json]` before automation, use
`dotfiles-module status` for inventory, preview module work with
`dotfiles-module plan enable|disable|uninstall|purge MODULE`, or inspect the
still read-only whole-system design with `dotfiles-module plan system-uninstall`.
Every module action plan and successful action accepts `--json` and exposes a
stable schema-v1 object for the native management UI. JSON plans describe the
target ownership, declared state, confirmation, and state-root requirements;
JSON results report the completed operation and final enable state. The
executor never calls `chezmoi destroy` or deletes module source.
