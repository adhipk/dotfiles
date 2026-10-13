# dotfiles-manager

This is the human-first control panel for the dotfiles repository. The module
bundles a Textual settings UI, its editable theme, the `Fn+Comma` hotkey, window rules, and contract tests.

`dotfiles-manager open` launches a dedicated `dotfiles-manager` tmux session
directly into the settings UI. One thin tmux row remains visible across its
two persistent surfaces: `Ctrl+Backtick` opens the terminal; `Ctrl+1` and
`Ctrl+2` return to Settings.

Settings is also the everyday system browser. Its left rail includes the
editable preference registry plus live Utilities, Shortcuts, Modules,
Dependencies, and System inventories. Utilities are runnable actions declared
by their owning module in `module.yaml`; the control panel executes the exact
argument array without a shell. Shortcuts rebind through the one-purpose
`shortcut-rebind` command, and Modules previews the guarded lifecycle plan
before enabling or disabling through `dotfiles-module`. The shortcut catalog
remains derived from rendered skhd; module, dependency, and uninstall state
comes from the public JSON interfaces owned by their respective modules. Those
inventories prefetch concurrently and remain cached for instant section
changes; `r` explicitly refreshes the active section. Destructive uninstall
and purge actions retain their dedicated exact-confirmation workflows.

Press `Enter` to edit a setting, rebind a shortcut, toggle a module, or run a
selected utility action. Use `/` to search the active section, `r` to reload
it, and `Ctrl+P` for
Textual's command palette.

Every setting is loaded from the checked-in registry and written through
`dotfiles-settings`, which performs the normal validation, targeted apply,
service reload, and rollback. No setting is duplicated inside the UI.

For visual customization, run `dotfiles-manager theme edit`. This creates the
preserved `~/.config/dotfiles-manager/theme.tcss` override from the managed
example; subsequent source applies do not replace it.

## Boundary

- This folder owns the control panel, dependency lock, example theme, manager
  command, tmux session shape, hotkey, yabai identity, docs, and tests.
- The settings registry, shortcut catalog, module lifecycle, dependency
  inventory, and uninstall planner remain shared/external providers consumed
  only through their file or command interfaces.
- Utility modules own their runnable `actions` declarations. The manager owns
  discovery, presentation, exact argv execution, timeout, and result feedback;
  it never invents feature-specific buttons or shell command strings.
- The parent contains thin ChezMoi bridges and conditional registration only.
- `scratchpads open command` is the declared external window-transport API.
  Removing this module leaves quick terminals, the projects scratchpad, and
  the session manager operational.
- The panel does not launch or configure an assistant. The separate Hermes
  adapter is disabled; upstream Hermes installation and profile data are preserved.

## Setup

Normal `make install` installs the panel and its pinned dependency lock.
No Hermes installation or profile is required.

## Validate

```sh
modules/dotfiles-manager/tests/test_module.sh
modules/scratchpads/tests/test_scratchpads.sh
modules/scratchpads/tests/test_module.sh
```
