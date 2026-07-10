# Agent Notes
## Primary Role
Your job is to maintain my dotfile configurations, this includes keyboard shortcuts, display management, any utils or specific command bins, installed packages, etc. After implementing any feature, make sure that the setup and boootstrap processes reflect the changes.
## Canonical Task Tracking
- This working directory's `./todo.txt` and `./done.txt` are the durable task source of truth. Use the repo-owned `todo` command from the project root for every read or mutation; it pins Tuxedo to the current directory and serializes agent writes. Never use raw redirects or a bare `tuxedo` command.
- At the start of non-trivial change work, inspect `todo ls --json` from the active project root. Reuse an open task that already covers the outcome or add one todo.txt line with priority, creation date, `+project`, `@agent`, `id:<uuid>`, and `owner:<agent>` metadata. Do not add tasks for trivial read-only questions.
- Keep one line per distinct deliverable and do not alter unrelated tasks. Re-resolve the physical task number immediately before any numbered mutation.
- After the requested outcome is validated, run `todo do N`. Do not auto-archive completed tasks. Leave blocked work open with `status:blocked` and a concise `blocked:<reason>` value.
- Built-in planning tools are transient working state; they must stay aligned with, and never replace, the canonical todo.txt entry.
- Any app exposed through tmux must start in the same working directory as the session's existing windows unless the user explicitly asks for another root.
## Keyboard Layers
- Tap `caps lock` for Escape; holding it still emits Hyper (`ctrl + opt + cmd`), but Hyper is intentionally unbound and reserved for a future coherent namespace.
- **Option-centered chords** own sparse global actions: app focus, macOS window/space control, scratchpad-independent HUDs, and service reloads. Shift or Control may refine a global action; Command is not part of this layer.
- **Left Command** remains application-local. In Ghostty, `Cmd+Backtick/1/2/3` cycles terminal/Codex/Neovim/Tuxedo tmux windows and `Cmd+B` / `Cmd+Shift+B` opens Yazi views.
- **Right Command** is a small Ghostty-only maintenance layer: `Right Cmd+D` duplicates the current typed tmux window, `Right Cmd+R` renames it, `Right Cmd+S` opens sesh, and `Right Cmd+Space` opens the tmux command center. These chords pass through normally in every other app; sided Option remains reserved.
- **Control** owns terminal-native behavior. `Ctrl+0/1/2/3` cycles typed tmux windows, `Ctrl+Shift+0/1/2/3` creates them, and `Ctrl-a` opens tmux's prefix namespace.
- **Fn** is the transient scratchpad layer: `Fn+Comma` for `~/dotfiles` and `Fn+1` for `~/projects`. Native macOS screenshot chords remain on Command+Shift.
- **Shift** means a related variant such as reverse, move, resize, or create; it is not an independent layer.
- **`Alt+/`** — non-activating shortcut guide sourced from the live `~/.skhdrc`; a bare key such as `K` finds every shortcut ending in that key. Its own controls use unbound Option chords (`Option+Up/Down` results, `Option+Left/Right` categories, `Option+F/P` text/key search, `Option+C` clear).
- ProjectDeck and system-wide project contexts are dormant. The CLI and manual `make build-projectdeck` target remain available; only the shortcut guide builds automatically on `make install`.

## Key Bindings (skhd)
- `alt + n` creates a new space and focuses it; when the current space has more than one non-scratchpad window, it moves the focused non-scratchpad window there.
- `alt + backtick` focuses normal Ghostty windows; scratchpads are excluded from the app MRU list.
- `alt + 1..5` focuses browser, Codex, editor, Teams, or Slack.
- normal Ghostty windows are transparent and keep the tmux-colored JankyBorder; scratchpads are borderless, opaque black panels with balanced terminal padding, rounded corners, and a native shadow.
- `fn + comma` opens the black terminal scratchpad and switches to a `~/dotfiles` tmux session containing `terminal`, `codex`, `nvim`, and `tuxedo` windows.
- `fn + 1` opens the same black terminal scratchpad and switches to a separate `~/projects` tmux session containing `terminal`, `codex`, `nvim`, and `tuxedo` windows.
- In Ghostty, `Cmd+Backtick`, `Cmd+1`, `Cmd+2`, and `Cmd+3` cycle `terminal`, `codex`, `nvim`, and `tuxedo` windows by type, including renamed duplicates.
- `Cmd+B` toggles Yazi in a 40%-wide full-height right tmux pane, while `Cmd+Shift+B` opens or selects a dedicated Yazi tmux window; new views inherit the active pane's directory.
- `Right Cmd+D` duplicates the active typed window in the same directory and names successive copies `terminal-2`, `codex-2`, `nvim-2`, or `tuxedo-2`; `Right Cmd+R/S/Space` rename, choose a session, or open the command center.
- Broader tmux session/window/pane actions stay under `Ctrl-a` and `Ctrl-a Space`, not Hyper or a flat Command chord set.
- `alt + shift + backtick` creates a new terminal window on the focused space.

## Dormant Projects CLI
- `projects pick` — ProjectDeck UI (macOS dialog fallback if not built)
- `projects new [id]` — create a project context manually
- `projects status` — one-line active/context summary
- `projects list` — terminal listing
- `projects adopt` — add current space to project context

## Terminal Defaults
- `home/dot_config/skhd/executable_open_terminal_window.sh` defaults to Ghostty.
- Ordinary new tmux sessions use the shared `terminal` `0`, `codex` `1`, `nvim` `2`, `tuxedo` `3` template. Sessions created with an explicit command, `hs-*` sessions, and sessions with `DOTFILES_TMUX_TEMPLATE=skip` are left alone.
- In tmux, `Ctrl+0/1/2/3` cycles windows by `terminal`/`codex`/`nvim`/`tuxedo` type; `Ctrl+Shift+0/1/2/3` creates that type in the current pane's directory and switches to it. `Ctrl+4..9` still selects a window by index.
- `Ctrl-a s` and the shell/tmux session selectors use sesh's built-in picker rather than a hand-rolled `fzf` pipeline; its checked-in configuration is installed at `~/.config/sesh/sesh.toml`.
- `Ctrl-a L` and the command center's Sessions > Last action use tmux's per-client history; closing a session keeps its clients inside tmux and moves them to a surviving session instead of detaching.
- `Ctrl-a Space` opens the repo-owned tmux command center for session, window, pane, persistence, and workspace-layout actions.
- `tmux-workspace open project --root DIR` builds the import-free React-like layout in `~/.config/tmux/layouts/project.tmux.tsx`; repeated apply preserves running panes and explicit repair fixes structural drift.
- The minimal tmux bar stays at the bottom and centers `~ · codex · nvim · tuxedo`; at left it shows a meaningful session name, substitutes the active folder for generated numeric sessions, and omits duplicate folder context. Each session colors the foreground-only active label and normal focused Ghostty border, while scratchpads stay borderless, and `Ctrl-a ,` renames a tab and seeds Codex renames from the pane title.

## Chezmoi
- `.chezmoiroot` points to `home/`, the desired state for `$HOME`.
- `install.sh` applies the source state with chezmoi, reloads a running tmux server, and signals every running Ghostty process to reload its configuration.
- `bootstrap.sh` installs the Brewfile (including Bun, Python, Codex, Tuxedo, Yazi, and JankyBorders), provisions TPM plugins and the repo-owned tmux command center, creates `~/projects`, builds the shortcut guide, and starts yabai/skhd for a clean client. The `todo` wrapper initializes task files in whichever project directory invokes it.
- Fresh clients still require macOS approvals plus `setup-yabai-sa` after completing yabai's SIP setup.
- Add helper commands under `home/bin/` with the `executable_` attribute.
- Add one-time setup scripts under `home/.chezmoiscripts/` with a `run_once_` prefix.
- Add personal agent defaults under `home/dot_agents/`; chezmoi applies this to `~/.agents/`.
- Codex, Claude Code, and OpenCode receive that same shared guidance through managed global instruction symlinks.

## Keycode Note
- The tilde binding uses keycode `0x32` in `home/dot_skhdrc` for reliability.
