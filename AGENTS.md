# Agent Notes
## Primary Role
Your job is to maintain my dotfile configurations, this includes keyboard shortcuts, display management, any utils or specific command bins, installed packages, etc. After implementing any feature, make sure that the setup and boootstrap processes reflect the changes.
## Projects (primary UX)
- Tap `caps lock` for Escape; hold it for Hyper (`ctrl + opt + cmd`) outside Neovim.
- In Neovim, hold `caps lock` for Control.
- **`Hyper+p`** or **`Hyper+e`** — **ProjectDeck** floating picker (blurred HUD panel, search, keyboard nav; spaces submenu supports detach and delete).
- **`Hyper+n`** — quick create via ProjectDeck name form.
- **`Hyper+1..5`** — fast switch to a project (last-used space).
- **`Hyper+a`** — adopt current space into project context.
- **`Hyper+Shift+Backspace`** — detach current space from project (no confirm).
- **`Alt+Shift+1..9`** / **`Alt+Shift+h/k`** — jump or cycle spaces in project context.
- **`Alt+/`** — non-activating shortcut guide sourced from the live `~/.skhdrc`; a bare key such as `K` finds every shortcut ending in that key. Its own controls use unbound Option chords (`Option+Up/Down` results, `Option+Left/Right` categories, `Option+F/P` text/key search, `Option+C` clear).
- ProjectDeck and the shortcut guide are built automatically on `make install` (not chezmoi-managed binaries).

## Key Bindings (skhd)
- `alt + n` creates a new space and focuses it; when the current space has more than one non-scratchpad window, it moves the focused non-scratchpad window there.
- `alt + backtick` focuses normal Ghostty windows; scratchpads are excluded from the app MRU list.
- `alt + 1..5` focuses browser, Codex, editor, Teams, or Slack.
- normal Ghostty windows are transparent; scratchpad Ghostty windows force opaque black.
- `fn + comma` opens the black terminal scratchpad and switches to a `~/dotfiles` tmux session containing `terminal`, `codex`, and `nvim` windows.
- `fn + 1` opens the same black terminal scratchpad and switches to a separate `~/projects` tmux session containing `terminal`, `codex`, and `nvim` windows.
- In Ghostty, `cmd + backtick` switches to tmux window `0` (`terminal`), `cmd + 1` switches to window `1` (`codex`), and `cmd + 2` switches to window `2` (`nvim`).
- In Ghostty, `cmd + b` opens Yazi in a 40%-wide full-height right tmux pane, while `cmd + shift + b` opens or selects a dedicated Yazi tmux window; new Yazi views inherit the active pane's directory.
- `alt + shift + backtick` creates a new terminal window on the focused space.

## Projects CLI
- `projects pick` — ProjectDeck UI (macOS dialog fallback if not built)
- `projects new [id]` — create on next Hyper slot and adopt current space
- `projects status` — one-line active/context summary
- `projects list` — terminal listing
- `projects adopt` — add current space to project context

## Terminal Defaults
- `home/dot_config/skhd/executable_open_terminal_window.sh` defaults to Ghostty.
- Ordinary new tmux sessions use the shared `terminal` `0`, `codex` `1`, `nvim` `2` template. Sessions created with an explicit command, `hs-*` sessions, and sessions with `DOTFILES_TMUX_TEMPLATE=skip` are left alone.
- In tmux, `Ctrl+0/1/2` cycles windows by `terminal`/`codex`/`nvim` type; `Ctrl+Shift+0/1/2` creates that type in the current pane's directory and switches to it. `Ctrl+3..9` still selects a window by index.
- The minimal tmux bar stays at the bottom, shows the active folder at left, and centers `~`, `codex`, and `nvim`; each session colors its active-tab capsule and focused Ghostty border, and `Ctrl-a ,` renames a tab and seeds Codex renames from the pane title.

## Chezmoi
- `.chezmoiroot` points to `home/`, the desired state for `$HOME`.
- `install.sh` applies the source state with chezmoi.
- `bootstrap.sh` installs the Brewfile (including Codex, Yazi, and JankyBorders), provisions TPM plugins, creates `~/projects`, builds the native HUDs, and starts yabai/skhd for a clean client.
- Fresh clients still require macOS approvals plus `setup-yabai-sa` after completing yabai's SIP setup.
- Add helper commands under `home/bin/` with the `executable_` attribute.
- Add one-time setup scripts under `home/.chezmoiscripts/` with a `run_once_` prefix.
- Add personal agent defaults under `home/dot_agents/`; chezmoi applies this to `~/.agents/`.

## Keycode Note
- The tilde binding uses keycode `0x32` in `home/dot_skhdrc` for reliability.
