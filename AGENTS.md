# Agent Notes

## Key Bindings (skhd)
- `alt + n` creates a new space and focuses it.
- `alt + shift + ~` opens a new Ghostty window in the current space.
- `alt + backtick` focuses Ghostty (app focus shortcut).

## Terminal Defaults
- `home/dot_config/skhd/executable_open_terminal_window.sh` defaults to Ghostty.

## Chezmoi
- `.chezmoiroot` points to `home/`, the desired state for `$HOME`.
- `install.sh` applies the source state with chezmoi.
- Add helper commands under `home/bin/` with the `executable_` attribute.
- Add one-time setup scripts under `home/.chezmoiscripts/` with a `run_once_` prefix.

## Keycode Note
- The tilde binding uses keycode `0x32` in `home/dot_skhdrc` for reliability.
