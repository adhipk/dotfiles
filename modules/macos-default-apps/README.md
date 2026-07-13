# macOS default-apps adapter

This module exposes the independently released
[`adhipk/macos-default-apps`](https://github.com/adhipk/macos-default-apps)
command at `~/bin/default-apps`. Chezmoi clones and pins the project under
`~/projects/macos-default-apps`; this folder owns only the module manifest,
stable symlink adapter, catalog metadata, and parent lifecycle test.

Disabling or uninstalling the module removes the `~/bin` link and preserves
the external checkout. The upstream project owns command behavior, packaging,
standalone installation, rollback, and release tests.
