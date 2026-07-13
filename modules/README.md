# Dotfiles modules

This directory contains feature-first vertical slices. Chezmoi remains the
configuration and apply engine; modules only provide feature-owned source that
thin templates under `home/` include into the target state.

## Boundary

Each module owns its runtime commands, target-service fragments, tests,
documentation, defaults, and package declarations. It may depend on:

- the public runtime library installed at `~/.local/lib/dotfiles`;
- external commands declared in `module.yaml`;
- another module only through a documented stable command or state contract.

The parent source state may touch a module only through a small integration
point:

- a target template that calls `includeTemplate`;
- an executable target bridge that renders a module-owned command;
- a chezmoi lifecycle script that renders a module-owned hook.

Removing or disabling a module must leave unrelated target rendering and tests
working. A module intended for external distribution must also run from an
isolated fixture with only its declared dependencies.

## Profile data

Checked-in enablement defaults live in
`home/.chezmoidata/10-modules.yaml`. Machine-specific values can override those
keys from the `data` section of the local chezmoi configuration.

Use camel-case data keys so Go templates can access them directly, while module
directory and manifest IDs use kebab case:

```yaml
modules:
  tmuxYazi:
    enabled: true
```

## Target composition

Target-service files remain in the chezmoi source state, but contain only
ordered module integration points:

```gotemplate
{{ if .modules.tmuxYazi.enabled -}}
{{ includeTemplate "../modules/tmux-yazi/targets/tmux.conf.tmpl" . }}
{{ end -}}
```

Stable installed commands use the same pattern:

```gotemplate
{{ includeTemplate "../modules/tmux-yazi/bin/tmux-yazi-pane" . }}
```

This keeps runtime paths such as `~/bin/tmux-yazi-pane` stable while the module
folder remains the authored source of truth.

## Common procedures

Feature-neutral runtime mechanics belong in
`home/dot_local/lib/dotfiles/`. Feature policy stays in the module. For
example, the library can acquire a lock or resolve a tmux target; the module
decides the lock key and which window should exist.

## Validation

For every module change:

1. Run the module's focused behavior test.
2. Render affected targets with `chezmoi cat`.
3. Verify enabled and disabled profile variants.
4. Run native validators for the affected services.
5. Run a cold-home chezmoi dry apply and the repository test suite.

## Lifecycle

Use `dotfiles-module status` to inspect the normalized manifest inventory and
`dotfiles-module plan disable|uninstall|purge MODULE` to preview module
removal. `dotfiles-module plan system-uninstall` describes whole-system
removal without touching the machine.

The source-preserving executor exposes `disable MODULE`, `uninstall MODULE`,
and `purge MODULE --confirm MODULE`. It serializes mutations, atomically updates
module data, applies only manifest-declared bridges through chezmoi, and rolls
the data and target state back when apply fails. Disable preserves all state;
uninstall removes only declared ephemeral filesystem state; purge also removes
declared persistent filesystem state. Relative state requires an explicit
absolute `--state-root`. The whole-system operation remains plan-only.

The controller must not use `chezmoi destroy` as an uninstall shortcut because
that command also removes source-state entries.

## Remaining utilities

[`utility-inventory.md`](utility-inventory.md) records why helpers that still
live under `home/bin` are not yet clean plugin boundaries. Keep coupled desktop,
tmux, external-checkout, and lifecycle helpers there until their owning
vertical module can absorb them without hidden parent dependencies.
