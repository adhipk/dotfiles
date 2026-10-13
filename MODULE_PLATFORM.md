# Dotfiles module platform

> Public 1.0 direction: the native macOS app with executable extensions in
> [RELEASE_READINESS.md](RELEASE_READINESS.md) and the shared-library contract in
> [EXTENSION_STDLIB_AUDIT.md](EXTENSION_STDLIB_AUDIT.md) supersede this document's
> proposed Textual-only UI and repository-bound packaging. The material below
> records the earlier design; its ownership and conflict-handling principles
> remain useful during migration. The development implementation and its limits
> are documented in [NATIVE_APP.md](NATIVE_APP.md) and
> [EXTENSION_AUTHORING.md](EXTENSION_AUTHORING.md).

The dotfiles repository should behave as one extension platform, not as a
collection of utilities that each learn how to edit shared system files.

## Ownership rule

A utility owns its implementation and declares its intent. The dotfiles core
owns every shared integration surface and is the only layer allowed to compose
or mutate it.

Utilities declare:

- commands and runnable UI actions;
- settings and their rendered configuration targets;
- keyboard-shortcut intents;
- required executables and other module dependencies;
- system capabilities such as notifications, window rules, launch agents, or
  tmux contributions;
- exclusive targets, shared contributions, runtime state, and cleanup policy;
- conflicts, health checks, and user-facing documentation.

Utilities do not directly append to `.skhdrc`, `.yabairc`, tmux configuration,
the Brewfile, launchd state, or the control-center UI.

## Platform layers

1. **Module package** — `modules/<id>/` contains implementation, manifest,
   defaults, settings/action contributions, tests, and system context.
2. **Registry and compiler** — one schema-aware core discovers modules,
   validates declarations, resolves dependencies, detects collisions, and
   produces a complete plan before changing the machine.
3. **Backend adapters** — skhd, yabai, tmux, launchd, Homebrew, and ChezMoi are
   render/apply targets behind the compiler. A module declares intent without
   knowing how another module is merged into the same target.
4. **Transactional reconciler** — apply uses the compiled plan, records target
   ownership, validates rendered output, reloads affected services once, and
   rolls back the whole transaction on failure.
5. **One control center** — `dotfiles-manager` consumes the same registry and
   plan APIs. It renders settings, runnable actions, shortcuts, module health,
   dependencies, conflicts, and guarded lifecycle operations without
   feature-specific UI code.
6. **Scaffolder** — `dotfiles-module new ID` creates the standard directory,
   manifest, settings/actions stubs, context document, and focused tests. A new
   utility should not require edits to parent templates or the UI.

## Declarative contract

`module.yaml` remains the identity and lifecycle source. Extension fragments
may stay as separate validated files when their schema evolves independently:

```text
modules/example/
├── module.yaml          # identity, dependencies, targets, state, capabilities
├── settings.yaml        # settings contributed to dotfiles-settings
├── actions.yaml         # safe argv-based actions contributed to the UI
├── shortcuts.yaml       # semantic shortcut intents, not raw skhd text
├── bin/                 # owned commands
├── config/              # defaults and rendered configuration
├── docs/system-context.md
└── tests/
```

Every contributed ID is globally unique. Every action is an executable plus an
argument array; shell strings are forbidden. Every shortcut names an action
reference and a semantic layer. Every system effect declares whether it is an
exclusive resource or a mergeable contribution.

## Conflict handling

Compilation must fail before apply when two enabled modules:

- claim the same exclusive destination;
- bind the same chord in the same keyboard layer and scope;
- register the same yabai/launchd/tmux identity;
- contribute duplicate settings or action IDs;
- require incompatible versions or mutually exclusive capabilities;
- write state outside their declared roots.

The plan reports both owners, the exact resource, and remediation choices.
Ordering is explicit only for genuinely mergeable contributions; file-system
order is never policy.

## Unified UX

The canonical human surface is the Textual `dotfiles-manager` opened by
`Fn+Comma`. CLIs remain the automation and recovery API, not competing control
centers. Purpose-specific overlays such as the shortcut guide may remain when
they are non-mutating views of the same registry.

The control center should have these top-level views:

- **Home** — health, pending changes, conflicts, and recent failures;
- **Utilities** — module-contributed runnable actions;
- **Settings** — merged core and module settings;
- **Shortcuts** — resolved bindings with ownership and collision state;
- **Modules** — enablement, dependencies, capabilities, and guarded lifecycle;
- **System** — compiled effects, dependency health, and uninstall/restore.

Compatibility command names may delegate to this UI during migration, but
there must be only one UI implementation.

## Migration sequence

1. Freeze new handwritten parent integration and validate the current module,
   settings-fragment, and action contracts.
2. Add shortcut and system-capability schemas plus cross-module collision
   validation.
3. Generate shared target composition from the registry and delete manual
   parent include lists.
4. Move lifecycle/dependency/system operations into the canonical manager via
   the existing JSON APIs.
5. Redirect compatibility launchers to `dotfiles-manager`, then remove the
   native Swift control-center implementation after feature parity is tested.
6. Add `dotfiles-module new` and migrate remaining utilities through it.

## Current reference module

`modules/notifications` is the first reference slice: it owns command behavior,
configuration, settings, a runnable control-center action, tests, compatibility
path, and shared system context. Its consumers only request a notification;
they do not implement delivery or settings themselves.

The current action field is an initial vertical slice, not yet the final global
schema. Do not replicate it across every module until the compiler validates
action IDs, argv shape, enablement, availability, and permissions centrally.
