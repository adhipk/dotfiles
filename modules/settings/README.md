# settings

Central catalog and CLI for user preferences that would otherwise require
editing scattered config files: terminal and GUI editor, coding assistant,
alt-1..4 app-focus hotkey slots, terminal app, theme, and agent-timer knobs.

## How it works

- Preference values live in chezmoi data: cross-cutting preferences under
  `preferences:` in `home/.chezmoidata/20-preferences.yaml`, module-specific
  knobs under their module's key in `home/.chezmoidata/10-modules.yaml`.
- `registry.yaml` declares every changeable setting: its data path, value
  constraints, the source-state bridges that render it, and the services to
  reload after a change. `dotfiles-settings validate` checks the registry
  against the repository.
- Modules contribute their own settings through the fragment contract below;
  fragments are merged with the core registry at runtime, so the picker, the
  Textual control panel, and the JSON API see one uniform catalog. A fragment
  is a `modules/<id>/settings.yaml` file with `kind: SettingsFragment` whose
  `settings:` entries use the exact same schema as `registry.yaml`. Entries
  from a fragment whose module is disabled (the `enabled` flag under its
  `dataKey` in `home/.chezmoidata/10-modules.yaml`) are hidden from `list`,
  `get`, `set`, and the picker. `list --json` reports each entry's owning
  `module` (`settings` for core registry entries), and `validate` checks
  every fragment envelope — even for disabled modules — plus all merged
  entries and cross-fragment key collisions.
- `dotfiles-settings set KEY VALUE` acquires the repository lock, atomically
  edits the data file, verifies the value is not masked by a machine override
  in `~/.config/chezmoi`, re-renders only the affected bridges through
  `chezmoi apply --source-path`, reloads declared services (skhd, tmux,
  colors), regenerates the shortcut catalog when hotkey text changed, and
  rolls the data file back if apply fails.
- `dotfiles-settings` (or `pick`) opens a two-level fzf flow: choose a
  setting, then choose a value from its provider (installed macOS apps,
  commands on PATH, checked-in colorschemes, system sounds, or a static
  enum); free-text entries are accepted where the registry allows them.
- Runtime consumers read `~/.config/dotfiles/preferences.toml` (rendered from
  `config/preferences.toml.tmpl`) through `dotfiles_pref KEY FALLBACK` in the
  shared `prefs.sh` library, so modules keep working with their historical
  defaults when this module is disabled. `DOTFILES_PREF_<UPPERCASE_KEY>`
  overrides a value for one session.

## Usage

```
dotfiles-settings                 # interactive picker
dotfiles-settings list [--json]
dotfiles-settings get KEY [--json]
dotfiles-settings set KEY VALUE [--json] [--no-apply] [--no-reload]
dotfiles-settings validate [--json]
```

Changing a hotkey slot or the terminal app rewrites the generated
`modules/shortcut-guide/generated/shortcuts.{json,md}` artifacts; commit the
resulting repository diff like any other configuration change.

## Writing a fragment

```yaml
# modules/<id>/settings.yaml
apiVersion: dotfiles/v1
kind: SettingsFragment
schemaVersion: 1
module: <id>              # must match the module directory name
dataKey: modules.<camelId> # optional; gates entries on `.enabled` in 10-modules.yaml
settings:
  - key: <id>.someKnob     # same entry schema as registry.yaml:
    description: ...       # dataPath, file, type, values, bridges, reload,
    ...                    # regenerate all work identically
```

Rules:

- `module` must equal the fragment's directory name under `modules/`.
- Keys share one global namespace with the core registry; prefix them with
  the module id to avoid collisions (`validate` rejects duplicates).
- `dataPath`/`file` point at chezmoi data like any registry entry; module
  knobs belong under the module's key in `home/.chezmoidata/10-modules.yaml`.
- Bridges must be real source-state files under `home/`; a change re-renders
  only those bridges and runs the declared `reload`/`regenerate` steps.

## Testing

- `make test-settings` runs `tests/test_module.sh`: manifest and registry
  contracts, cold-home default and override rendering, CLI round-trips and
  input rejection against an isolated data file, apply-failure rollback, and
  `prefs.sh` behavior.
