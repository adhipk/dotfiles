# todo adapter module

This module exposes the command from the independently distributed
[`tuxedo-project-todo`](https://github.com/adhipk/tuxedo-project-todo)
checkout at `~/projects/tuxedo-project-todo/bin/todo`.

It provides two equivalent command entrypoints:

- `todo [TUXEDO COMMAND ...]` preserves the existing direct CLI.
- `chezmoi todo [TUXEDO COMMAND ...]` uses chezmoi's native external-command
  dispatch through the `chezmoi-todo` executable.

The external project owns command behavior, locking, packaging, lifecycle
scripts, and behavioral tests. This module owns only its manifest, one path
template, documentation, and the parent integration contract. The parent
repository contributes two conditional symlink adapters under `home/bin`.

## Checkout and lifecycle

The checkout must exist at `~/projects/tuxedo-project-todo`, with its command
at `bin/todo`. Dependency bootstrap owns cloning and pinning that checkout;
this adapter never copies or modifies it. Use the external project's
`install.sh`, `uninstall.sh`, and test suite for standalone lifecycle and
command behavior.

Disabling `modules.todo` removes both managed symlinks while preserving the
external checkout and every project's cwd-relative `todo.txt` and `done.txt`
ledgers. `.agent-write-lock` remains transient command-owned state.

## Chezmoi integration

The parent repository renders the same in-module path template through two
gated symlink adapters:

```text
home/bin/symlink_todo.tmpl          -> ~/bin/todo
home/bin/symlink_chezmoi-todo.tmpl  -> ~/bin/chezmoi-todo
```

Both links resolve to `~/projects/tuxedo-project-todo/bin/todo`. Because the
path template is evaluated only while the module is enabled, a disabled parent
continues rendering safely after this adapter module is removed.

## Test

```sh
./modules/todo/tests/test_todo.sh
```

The contract test renders both symlinks in an isolated home, verifies direct
and native `chezmoi todo` dispatch, checks disable-time data preservation, and
proves the disabled parent remains healthy after removing the module folder.
