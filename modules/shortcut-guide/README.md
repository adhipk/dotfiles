# Shortcut Guide

This module owns the native WhichKey application, its build adapter, the stable
launcher implementation, and the derived desktop-shortcut catalog.

The shortcut definitions remain authoritative in rendered skhd configuration.
`bin/shortcut-catalog` renders the desired state with:

```sh
chezmoi -S ROOT cat "$HOME/.skhdrc"
```

It then uses the same Swift parser as the interactive guide. Module manifests do
not repeat shortcut keys or commands.

## Ownership markers

Rendered configuration may change ownership with a comment:

```text
# dotfiles-owner: app-focus
```

Unmarked bindings belong to `root`. Non-root owners must match an `id` from a
`modules/*/module.yaml` manifest. These comments record rendered provenance;
they do not define shortcuts.

## Catalog workflow

```sh
modules/shortcut-guide/bin/shortcut-catalog update
modules/shortcut-guide/bin/shortcut-catalog check
```

`update` atomically writes `generated/shortcuts.json` and
`generated/shortcuts.md`. `check` regenerates in memory and fails without
writing when either checked artifact is stale. Outputs contain no timestamps.
Stable identifiers are SHA-256 values derived from the shortcut owner, raw key,
and command.

The JSON artifact is the machine-readable input intended for the future module
management UI. The Markdown artifact is the human-readable desktop shortcut
reference.

## Runtime build

`install/build-whichkey.sh` compiles and installs the Swift application. The
repository-level `scripts/build-whichkey.sh` remains a compatibility wrapper.
The build requires macOS and the Xcode Command Line Tools.

## Parent integration

The parent source state supplies only thin bridges for `shortcut-catalog`,
`show_keys.sh`, and `targets/skhdrc.tmpl`, plus the module-enabled data flag.
Deleting or disabling this module removes those mounts without requiring a
second shortcut registry.
