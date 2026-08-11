# Agent Notes
## Primary Role
Your job is to maintain my dotfile configurations, this includes keyboard shortcuts, display management, any utils or specific command bins, installed packages, etc. After implementing any feature, make sure that the setup and boootstrap processes reflect the changes.
## Canonical Task Tracking
- The machine-wide `~/.agents/tasks/todo.txt`, `done.txt`, and `handoffs/` directory are the durable task source of truth for every repository. Use the managed `todo` command from any working directory for every read or mutation; it pins Tuxedo to that shared store. Persistent Tuxedo views and reads are lock-free, while short mutations are serialized. Never use raw redirects or a bare `tuxedo` command.
- At the start of non-trivial change work, resolve `repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"` and inspect only its open tasks with `todo ls "repo:$repo_root" --json | jq '[.[] | select(.done == false)]'`. Do not load the unfiltered machine-wide queue into a project context unless the user explicitly asks for a cross-repository view. Reuse an open task that already covers the same outcome and repository or add one todo.txt line with priority, creation date, `+project`, `@agent`, stable `id:<uuid>`, `owner:<agent>`, and absolute `repo:<path>` metadata. Do not add tasks for trivial read-only questions.
- Keep one line per distinct deliverable and do not alter unrelated tasks. Re-resolve the physical task number immediately before any numbered mutation.
- Prefer the stable-ID commands: `todo task-status ID STATUS`, `todo handoff get ID`, and, after validation, `todo task-done ID`. Do not auto-archive completed tasks. Leave blocked work open with `status:blocked` and a concise failure handoff.
- Treat a user request beginning with `@todo` as an invocation of the global `$todo` skill. That workflow creates repo-targeted tasks with a shared `flow:`, infers a dependency DAG, runs ready agents when the harness supports delegation, and copies each dependency's durable handoff into downstream work.
- Built-in planning tools are transient working state; they must stay aligned with, and never replace, the canonical todo.txt entry.
- Any app exposed through tmux must start in the same working directory as the session's existing windows unless the user explicitly asks for another root.
## Keyboard Layers
- Tap `caps lock` for Escape; holding it still emits Hyper (`ctrl + opt + cmd`), but Hyper is intentionally unbound and reserved for a future coherent namespace.
- **Option-centered chords** own sparse global actions: app focus, macOS window/space control, scratchpad-independent HUDs, and service reloads. Shift or Control may refine a global action; Command is not part of this layer.
- **Left Command** remains application-local. In Ghostty, `Cmd+Backtick/1/2/3` cycles terminal/Codex/Neovim/Tuxedo tmux windows and `Cmd+B` / `Cmd+Shift+B` opens Yazi views.
- **Right Command** is a small Ghostty-only maintenance layer: `Right Cmd+D` duplicates the current typed tmux window, `Right Cmd+R` renames it, `Right Cmd+S` opens sesh, `Right Cmd+Space` searches tmux commands, and `Right Cmd+H` opens the centralized tmux hub. These chords pass through normally in every other app; sided Option remains reserved.
- **Control** owns terminal-native behavior. `Ctrl+0/1/2/3` cycles typed tmux windows, `Ctrl+Shift+0/1/2/3` creates them, and `Ctrl-a` opens tmux's prefix namespace.
- Tapping **Right Control** opens a transient Vim motion leader for the active text input outside Ghostty; in Ghostty it still emits `Ctrl-a` as the one-key tmux leader. Holding it remains a normal Control modifier everywhere, and Left Control is unchanged.
- In Ghostty/tmux, `Shift+Enter` is explicitly forwarded to Codex for multiline input; broad tmux extended-key rewriting stays disabled to protect paste and terminal-protocol applications.
- **Fn** owns transient window access: `Fn+Comma` opens the `~/dotfiles` scratchpad, `Fn+P` opens the session-manager scratchpad, `Fn+1..9` focuses open normal tmux Ghostty windows in creation order, and `Fn+Tab` cycles through them. `Fn+Shift+1/2/3/4` forwards the four native macOS save/copy full-screen/selection capture commands.
- **Shift** means a related variant such as reverse, move, resize, or create; it is not an independent layer.
- **`Alt+/`** — non-activating shortcut guide sourced from the live `~/.skhdrc`; a bare key such as `K` finds every shortcut ending in that key. Its own controls use unbound Option chords (`Option+Up/Down` results, `Option+Left/Right` categories, `Option+F/P` text/key search, `Option+C` clear).
- ProjectDeck and system-wide project contexts are disabled modules. The source CLI at `modules/projects/bin/projects` and manual `make build-projectdeck` target remain available; only the shortcut guide builds automatically on `make install`.

## Key Bindings (skhd)
- `alt + n` creates a new space and focuses it; when the current space has more than one non-scratchpad window, it moves the focused non-scratchpad window there.
- `cmd + alt + n` first runs the active app's normal `cmd + n`, then moves the new window to a newly created space.
- `alt + backtick` focuses normal Ghostty windows; scratchpads are excluded from the app MRU list.
- `alt + 1..4` focuses browser, editor, Teams, or Slack. Entering an app restores
  its most-recent window; repeating the shortcut selects and promotes the
  least-recently-used eligible window, with scratchpads excluded.
- normal Ghostty windows are transparent and keep the tmux-colored JankyBorder; scratchpads are borderless, opaque black panels with balanced terminal padding, rounded corners, and a native shadow.
- `fn + comma` opens the black terminal scratchpad and switches to a `~/dotfiles` tmux session containing `terminal`, `codex`, `nvim`, and `tuxedo` windows.
- `fn + p` opens a separate black session-manager scratchpad. Its dedicated `session-manager` tmux session contains a compact project/agent/todo overview plus a terminal window; `a`/`t`/`s` search the full inventories, `x` closes one selected session, and `X` opens confirmed multi-session cleanup.
- `fn + 1..9` focuses open normal tmux Ghostty windows in creation order; detached sessions, scratchpads, and non-tmux terminal windows do not consume a slot.
- `fn + tab` cycles forward through those same open tmux windows and wraps after the last.
- `fn + shift + 1/2/3/4` saves full screen, copies full screen, saves a selection, or copies a selection through the native macOS screenshot shortcuts.
- In Ghostty, `Cmd+Backtick`, `Cmd+1`, `Cmd+2`, and `Cmd+3` cycle `terminal`, `codex`, `nvim`, and `tuxedo` windows by type, including renamed duplicates.
- `Cmd+B` toggles Yazi in a 40%-wide full-height right tmux pane, while `Cmd+Shift+B` opens or selects a dedicated Yazi tmux window; new views inherit the active pane's directory.
- `Right Cmd+D` duplicates the active typed window in the same directory and names successive copies `terminal-2`, `codex-2`, `nvim-2`, or `tuxedo-2`; `Right Cmd+R/S/Space/H` rename, choose a session, search tmux commands, or open the centralized hub.
- Broader tmux session/window/pane actions stay under `Ctrl-a` and `Ctrl-a Space`, not Hyper or a flat Command chord set.
- Outside Ghostty, tap `Right Control`, then use `h/j/k/l` for characters/lines, `b/w/e` for words, `0/$` for line bounds, `g/G` for document bounds, or `{`/`}` for paragraphs. Supported Shift-modified motions extend the selection; `Escape`, an unrelated key, or inactivity exits the transient layer.
- Tapping `Right Control` in Ghostty opens the same tmux prefix namespace as `Ctrl-a`; follow it with `s` for Sesh or `Space` for Telescope command search.
- `alt + shift + backtick` creates a new terminal window on the focused space.

## Dormant Projects CLI
- `modules/projects/bin/projects pick` — ProjectDeck UI (macOS dialog fallback if not built)
- `modules/projects/bin/projects new [id]` — create a project context manually
- `modules/projects/bin/projects status` — one-line active/context summary
- `modules/projects/bin/projects list` — terminal listing
- `modules/projects/bin/projects adopt` — add current space to project context

## Terminal Defaults
- `home/dot_config/skhd/executable_open_terminal_window.sh` defaults to Ghostty.
- Ordinary new tmux sessions use the shared `terminal` `0`, `codex` `1`, `nvim` `2`, `tuxedo` `3` template. Sessions created with an explicit command, `hs-*` sessions, and sessions with `DOTFILES_TMUX_TEMPLATE=skip` are left alone.
- In tmux, `Ctrl+0/1/2/3` cycles windows by `terminal`/`codex`/`nvim`/`tuxedo` type; `Ctrl+Shift+0/1/2/3` creates that type in the current pane's directory and switches to it. `Ctrl+4..9` still selects a window by index.
- `Ctrl-a s` and the shell/tmux session selectors use sesh's built-in picker rather than a hand-rolled `fzf` pipeline; its checked-in configuration is installed at `~/.config/sesh/sesh.toml`.
- `Ctrl-a L` and the searchable `Sessions › Last` action use tmux's per-client history; closing a session keeps its clients inside tmux and moves them to a surviving session instead of detaching.
- `Ctrl-a Space` opens a real Neovim Telescope picker over live tmux bindings and curated session, window, pane, persistence, and workspace-layout actions; it searches descriptions, shortcuts, and the actual tmux command text.
- `Ctrl-a g` and `Right Cmd+H` open the persistent `hub` session on the normal tmux server. `Fn+P` opens the same dashboard workflow in its own floating `session-manager` template. The live Neovim dashboard defaults to a compact project/agent/todo overview, keeps complete inventories in searchable drilldowns, derives `WAIT`/`ERR`/`READY`/`WORK` from visible panes, previews the selected pane, uses `Space` only for an explicit reply to a selected non-working agent, and provides confirmed `x`/`X` session cleanup; it owns no private socket, daemon, database, or automatic input path.
- `tmux-workspace open project --root DIR` builds the import-free React-like layout in `~/.config/tmux/layouts/project.tmux.tsx`; repeated apply preserves running panes and explicit repair fixes structural drift.
- The minimal tmux bar stays at the bottom and centers labels generated from each active pane's foreground program, using `~` for a bare shell and correcting Codex's Node launcher to `codex`. A twelve-color Catppuccin rotation gives each ordinary window index its own foreground color, with bold marking the current window. At left, the bar shows a meaningful session name, substitutes the active folder for generated numeric sessions, and omits duplicate folder context. Session accents still color normal focused Ghostty borders, while scratchpads stay borderless, and `Ctrl-a ,` renames a tab and seeds Codex renames from the pane title.

## Chezmoi
- `.chezmoiroot` points to `home/`, the desired state for `$HOME`.
- User preferences (terminal/GUI editor, coding assistant, alt-1..4 app slots, terminal app, theme) live under `preferences:` in `home/.chezmoidata/20-preferences.yaml` and are cataloged in `modules/settings/registry.yaml`. Change them with `dotfiles-settings` (fzf picker, or `set KEY VALUE`), which atomically edits the data file, re-renders the affected bridges, reloads services, and rolls back on failure — do not hand-edit rendered targets.
- `install.sh` applies the source state with chezmoi, reloads a running tmux server, and signals every running Ghostty process to reload its configuration.
- `bootstrap.sh` installs the Brewfile (including Bun, Python, Codex, Tuxedo, Yazi, and JankyBorders), clones and pins declared utility projects under `~/projects`, provisions TPM plugins and the tmux action catalog consumed by Telescope, builds the shortcut guide, and starts yabai/skhd for a clean client. The managed `todo` wrapper initializes task files in whichever project directory invokes it.
- Reusable utility implementations live in the pinned `kittentts-cli`, `tuxedo-project-todo`, `macos-default-apps`, `gh-create-repo`, and `unescape-cli` GitHub projects. Their modules own only manifests, catalog metadata, conditional `~/bin` links, and parent integration tests; upstream owns behavior, releases, and standalone lifecycle.
- Disabling a utility module or uninstalling the dotfiles removes its ChezMoi-owned links and preserves its checkout under `~/projects`. Do not copy an upstream implementation back into this repository or run its standalone installer from the ChezMoi bootstrap.
- Fresh clients still require macOS approvals plus `setup-yabai-sa` after completing yabai's SIP setup.
- Add dotfiles-owned helper commands under `home/bin/` with the `executable_` attribute; mount externally owned commands with conditional `symlink_` templates.
- Add one-time setup scripts under `home/.chezmoiscripts/` with a `run_once_` prefix.
- Add personal agent defaults under `home/dot_agents/`; chezmoi applies this to `~/.agents/`.
- Codex, Claude Code, and OpenCode receive that same shared guidance through managed global instruction symlinks.

## Keycode Note
- The tilde binding uses keycode `0x32` in `home/dot_skhdrc.tmpl` for reliability.
