# Hyperspace

This folder owns the parked pinned-tmux-session experiment, its optional skhd
bindings, and the Spotlight Ghostty shell. It is explicitly disabled through
`modules.hyperspace.enabled=false`; none of its historical targets are rendered
and `home/dot_skhdrc.tmpl` does not load its skhd fragment.

The CLI can still be tested directly from source:

```sh
HYPERSPACE_NOTIFY=0 modules/hyperspace/bin/hyperspace list
```

Pinned slots and the optional environment file are preserved state. Enabling
the module only restores the parked files below
`~/.config/skhd/modules/hyperspace`; it deliberately does not activate the
experimental keybindings.

This module does not own or replace an independently installed
`~/bin/hyperspace`. The two commands must remain separate until that external
PATH command is intentionally reconciled.
