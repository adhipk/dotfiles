# gh-create-repo adapter

This module exposes the independently released
[`adhipk/gh-create-repo`](https://github.com/adhipk/gh-create-repo) command at
`~/bin/gh-create-repo`. Chezmoi clones and pins the project under
`~/projects/gh-create-repo`; this folder owns only the module manifest, stable
symlink adapter, catalog metadata, and parent lifecycle test.

Disabling or uninstalling the module removes the `~/bin` link and preserves
the external checkout. The upstream project owns command behavior, packaging,
standalone installation, rollback, and release tests.
