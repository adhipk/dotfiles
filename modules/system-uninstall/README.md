# System uninstall

`dotfiles-uninstall` inventories the applied target state directly from
Chezmoi. Its default `plan` is read-only and `plan --json` is the stable input
for a future management UI. Plans, execution ledgers, and restore results use
the same `schemaVersion: 1` JSON contract.

Execution requires the exact destination-bound confirmation printed by the
plan:

```sh
dotfiles-uninstall execute --confirm "REMOVE DOTFILES FROM $HOME"
```

Before deleting anything, execution acquires the repository lifecycle lock,
captures the Chezmoi leaf and directory inventories, snapshots every module
manifest and the JSON plan, and backs up every existing managed leaf. This is
stronger than backing up only changed targets and permits an exact restore.
Backups, ledgers, and snapshots live under
`${XDG_STATE_HOME:-~/.local/state}/dotfiles/system-uninstall/runs`, with private
directory and file modes. The agent timer is stopped before deletion. Regular
files and symlinks are then unlinked without following symlinks; managed
directories are removed deepest-first only when empty. The lifecycle controller
and installed uninstaller are removed last.

Each target transition is written atomically to `ledger.json`. A failure exits
nonzero and leaves both a partial ledger and `failure.txt`; it does not attempt
an implicit rollback. Restore refuses to overwrite post-uninstall files and
validates every ledger path and backup fingerprint again:

```sh
# The installed command removes itself, so invoke the preserved source copy.
~/dotfiles/modules/system-uninstall/bin/dotfiles-uninstall restore RUN_ID \
  --confirm "RESTORE DOTFILES TO $HOME"
```

After restoring the timer command, restore runs `agent-timer enable` to clear
the preserved disabled latch.

The source repository, `~/projects`, the actual XDG state root, manifest-declared
module state, shared Homebrew packages, tmux plugins, sessions, and desktop
services remain preserved by policy. Nonempty managed directories are retained
because their unmanaged children are not owned by this project. The command
never calls `chezmoi destroy`, `chezmoi purge`, or `chezmoi forget`.
