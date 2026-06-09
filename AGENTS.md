# Agent Notes

## Key Bindings (skhd)
- `alt + n` creates a new space and focuses it.
- `alt + backtick` and `alt + ~` focus Ghostty (app focus shortcut).

## Terminal Defaults
- `home/dot_config/skhd/executable_open_terminal_window.sh` defaults to Ghostty.

## Chezmoi
- `.chezmoiroot` points to `home/`, the desired state for `$HOME`.
- `install.sh` applies the source state with chezmoi.
- Add helper commands under `home/bin/` with the `executable_` attribute.
- Add one-time setup scripts under `home/.chezmoiscripts/` with a `run_once_` prefix.
- Add personal agent defaults under `home/dot_agents/`; chezmoi applies this to `~/.agents/`.

## Keycode Note
- The tilde binding uses keycode `0x32` in `home/dot_skhdrc` for reliability.
