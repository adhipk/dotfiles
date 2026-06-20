# Agent Notes
## Primary Role
Your job is to maintain my dotfile configurations, this includes keyboard shortcuts, display management, any utils or specific command bins, installed packages, etc. After implementing any feature, make sure that the setup and boootstrap processes reflect the changes.
## Projects (primary UX)
- Hold `caps lock` for Hyper (`ctrl + opt + cmd`).
- **`Hyper+p`** or **`Hyper+e`** — **ProjectDeck** floating picker (blurred HUD panel, search, keyboard nav; spaces submenu supports detach and delete).
- **`Hyper+n`** — quick create via ProjectDeck name form.
- **`Hyper+1..5`** — fast switch to a project (last-used space).
- **`Hyper+a`** — adopt current space into project context.
- **`Hyper+Shift+Backspace`** — detach current space from project (no confirm).
- **`Alt+Shift+1..9`** / **`Alt+Shift+h/k`** — jump or cycle spaces in project context.
- Built automatically on `make install` (not chezmoi-managed).

## Key Bindings (skhd)
- `alt + n` creates a new space and focuses it.
- `alt + backtick` and `alt + ~` focus Ghostty.

## Projects CLI
- `projects pick` — ProjectDeck UI (macOS dialog fallback if not built)
- `projects new [id]` — create on next Hyper slot and adopt current space
- `projects status` — one-line active/context summary
- `projects list` — terminal listing
- `projects adopt` — add current space to project context

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
