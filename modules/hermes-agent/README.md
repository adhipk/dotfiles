# hermes-agent adapter

This module makes an existing upstream Hermes installation available as the
stable `hermes-dotfiles` assistant command. It does not install or update
Hermes and does not manage credentials, sessions, memories, Kanban data, or
gateway services.

The checked-in assistant preference points the stable tmux `codex` window type
at `hermes-dotfiles`. The launcher selects the dedicated `dotfiles` Hermes
profile and opens the modern TUI when called without arguments. Other arguments
pass through unchanged, so `hermes-dotfiles config get model` operates on the
same profile.

## Initial profile setup

Install and configure Hermes through its upstream lifecycle, then create the
profile from the configured default profile:

```sh
hermes profile create dotfiles --clone-from default --no-alias \
  --description "Maintains the dotfiles repository while preserving its AGENTS.md and canonical todo contracts."
hermes -p dotfiles skills opt-out --remove --yes
hermes -p dotfiles config set approvals.mode manual
hermes -p dotfiles config set memory.write_approval true
hermes -p dotfiles config set skills.write_approval true
```

The local profile may expose `~/.agents/skills` through Hermes' external skill
directories, but those files remain ChezMoi-rendered state. Skill write
approval must stay enabled so Hermes stages proposed changes instead of
silently editing that shared directory.

The launcher exports `AGENT_TODO_DIR` as
`~/.hermes/profiles/dotfiles/tasks`. The managed `todo` command therefore
creates and reads a profile-private ledger inside the dotfiles agent, while
ordinary terminals and other agents continue to use `~/.agents/tasks`.

## Ownership and switching

- Upstream Hermes owns `~/.hermes`, `~/.local/bin/hermes`, updates, and setup.
- This module owns only `~/bin/hermes-dotfiles`.
- The managed `todo` wrapper remains the command boundary, but this profile's
  ledger is private to the dotfiles agent; Hermes Kanban is not initialized.
- Disabling or uninstalling the module removes the launcher and preserves the
  `dotfiles` profile. An explicit module purge may remove the declared profile
  state.

Switch assistants without changing tmux window metadata:

```sh
dotfiles-settings set assistant codex
dotfiles-settings set assistant hermes-dotfiles
```

## Validate

```sh
modules/hermes-agent/tests/test_module.sh
```
