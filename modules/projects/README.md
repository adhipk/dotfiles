# Projects

This module owns the dormant yabai project-context CLI, its ProjectDeck UI,
manual build/install script, behavior tests, and design notes. It is disabled
by default through `modules.projects.enabled=false`, so Chezmoi installs no
`projects` command and no project-context shortcuts are active.

The source CLI remains intentionally usable for experiments without activating
the module:

```sh
modules/projects/bin/projects list --json
make build-projectdeck
```

The Make target is the only parent-side build adapter. It builds
`projectdeck/ProjectDeck.swift` and installs the binary to
`~/.config/yabai/projectdeck` (or `PROJECTDECK_INSTALL_PATH`). Normal install
and bootstrap do not build it. Mutable project data at
`~/.config/yabai/projects.json` is preserved across disable and uninstall.

When explicitly enabled, three thin Chezmoi bridges restore the historical
`~/bin/projects`, `~/bin/projects-pick`, and `~/.config/yabai/projects` paths.
No skhd binding is activated.
