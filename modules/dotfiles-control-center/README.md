# Dotfiles Control Center

`dotfiles-control-center` is a native SwiftUI/AppKit client for the repository's
public JSON command interfaces. It delegates all authority to
`dotfiles-module`, `dotfiles-deps`, and `dotfiles-uninstall`; the app never
edits chezmoi data, manifests, dependency locks, or target files directly.

The three views are intentionally bounded:

- **Modules** inventories modules, previews the schema-v1 lifecycle plan, and
  delegates enable, disable, uninstall, or purge. Uninstall and purge require
  the selected module ID to be typed exactly. Purge also forwards the backend's
  exact confirmation and an explicitly selected state root when required.
- **Dependencies** opens with the offline status, can explicitly run the
  manager-backed check, and previews a read-only snapshot. It does not install,
  update, remove, or rewrite the lock file.
- **System Uninstall** previews the schema-v1 whole-system plan, requires its
  destination-bound confirmation verbatim, and displays the durable ledger,
  backup path, and preserved-source restore command after execution.

The launcher records its caller's physical working directory in
`DOTFILES_CONTROL_CENTER_CWD`. Every `Foundation.Process` receives that same
`currentDirectoryURL`, so opening the app from a tmux project keeps backend
commands in that project context. Commands are launched with an executable URL
and argument array; no shell, browser, local server, or port is involved.

For development, command paths can be overridden without changing source:

```sh
DOTFILES_MODULE_BIN=/path/to/dotfiles-module \
DOTFILES_DEPS_BIN=/path/to/dotfiles-deps \
DOTFILES_UNINSTALL_BIN=/path/to/dotfiles-uninstall \
swift run --package-path modules/dotfiles-control-center dotfiles-control-center
```

Run focused validation with:

```sh
swift test --package-path modules/dotfiles-control-center
swift build --package-path modules/dotfiles-control-center --configuration release
bash modules/dotfiles-control-center/tests/test_module.sh
```

The parent repository must provide the conditional chezmoi bridge at
`home/bin/executable_dotfiles-control-center.tmpl` and the boolean data entry
`modules.dotfilesControlCenter.enabled`. Those integration files deliberately
remain outside this transportable module folder. The bridge must export the
source-root `DOTFILES_DIR` before including the launcher; direct source launches
fall back to resolving the package relative to the launcher itself.
