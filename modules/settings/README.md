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

## Testing

- `make test-settings` runs `tests/test_module.sh`: manifest and registry
  contracts, cold-home default and override rendering, CLI round-trips and
  input rejection against an isolated data file, apply-failure rollback, and
  `prefs.sh` behavior.
