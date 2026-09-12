# dotfiles-manager

This is the human-first control panel for the dotfiles repository. The module
bundles a Textual settings UI, its editable theme, the optional Hermes profile
entrypoint and skin, the `Fn+Comma` hotkey, window rules, and contract tests.

`dotfiles-manager open` launches a dedicated `dotfiles-manager` tmux session
directly into the settings UI. One thin tmux row remains visible across its
three persistent surfaces: `Ctrl+Backtick` opens the terminal, `Ctrl+1` creates
or selects the optional Hermes agent, and `Ctrl+2` returns to Settings. The
agent is still started lazily.

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
it, `a` to create or select the optional Hermes window, and `Ctrl+P` for
Textual's command palette.

Every setting is loaded from the checked-in registry and written through
`dotfiles-settings`, which performs the normal validation, targeted apply,
service reload, and rollback. No setting is duplicated inside the UI.

The `Hermes` category exposes `Skin`, Hermes' native combined color-theme and
startup-artwork setting. `dotfiles-manager` is the checked-in Catppuccin
default with compact custom logo and hero art; Hermes' built-in skins remain
available from the same selector. The equivalent terminal command is
`dotfiles-settings set hermes.skin NAME`.

For visual customization, run `dotfiles-manager theme edit`. This creates the
preserved `~/.config/dotfiles-manager/theme.tcss` override from the managed
example; subsequent source applies do not replace it.

## Boundary

- This folder owns the control panel, dependency lock, example theme, manager
  command, skin, tmux session shape, hotkey, yabai identity, docs, and tests.
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
- Upstream Hermes still owns credentials, sessions, memories, updates, and the
  rest of `~/.hermes/profiles/dotfiles`. This module adds one presentation
  symlink below the profile's `skins/` directory and selects that skin.
- The separate Hermes adapter owns the `hermes-dotfiles` compatibility command;
  this manager invokes Hermes only when the user asks for the agent view.
- The agent process receives a profile-private `AGENT_TODO_DIR` under
  `~/.hermes/profiles/dotfiles/tasks`; the global task queue is not inherited.

## Setup

Normal `make install` installs the panel and its pinned dependency lock. After
the upstream `dotfiles` Hermes profile exists, its skin can be reconciled
directly:

```sh
dotfiles-manager configure
```

Normal applies reconcile the selected skin automatically when the `dotfiles`
profile already exists. The explicit command is only needed after creating the
profile for the first time without running another apply.

## Validate

```sh
modules/dotfiles-manager/tests/test_module.sh
modules/scratchpads/tests/test_scratchpads.sh
modules/scratchpads/tests/test_module.sh
```
