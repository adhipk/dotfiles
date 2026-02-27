# Agent Notes

## Key Bindings (skhd)
- `alt + n` creates a new space and focuses it.
- `alt + shift + ~` opens a new Ghostty window in the current space.
- `alt + backtick` focuses Ghostty (app focus shortcut).

## Terminal Defaults
- `config/skhd/open_terminal_window.sh` defaults to Ghostty.

## Symlinks
- `install.sh` creates symlinks for helper scripts under `~/.config/skhd/`.
- If a new helper script is added in `config/skhd/`, rerun `./install.sh` (or `./bootstrap.sh`) to refresh symlinks.

## Keycode Note
- The tilde binding uses keycode `0x32` in `skhdrc` for reliability.
