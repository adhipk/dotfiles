# Dotfiles

Personal macOS setup managed with [chezmoi](https://www.chezmoi.io/).

## Layout

`.chezmoiroot` points chezmoi at `home/`, which declares the desired state of
`$HOME`. The repository-level `nvim/` directory is linked into
`~/.config/nvim` so edits remain live in the checkout.

```text
home/
├── .chezmoidata.toml                 # VSCodium, Chrome, and external project inventory
├── .chezmoiexternal.toml.tmpl        # External git repositories
├── .chezmoiscripts/                  # Apply hooks and one-time setup scripts
├── bin/                              # Helper commands installed into ~/bin
├── Library/Application Support/VSCodium/User/  # VSCodium settings
├── dot_agents/                       # Shared personal agent instructions, skills, and docs
├── dot_claude/                       # Claude Code bridge to shared agent instructions
├── dot_codex/                        # Codex bridge to shared agent instructions
├── dot_config/
│   ├── opencode/                     # OpenCode bridge to shared agent instructions
│   ├── symlink_nvim.tmpl              # ~/.config/nvim -> repository nvim/
│   ├── karabiner/                     # Caps Lock Hyper/Escape remap configuration
│   ├── sesh/                          # Session picker configuration
│   ├── skhd/                         # skhd helper scripts
│   ├── yabai/                        # stable bridges to modular yabai helpers
│   ├── yazi/                         # Yazi configuration
│   ├── tmux/                         # tmux configuration
│   └── zsh/                          # zsh support files
├── dot_skhdrc
├── dot_yabairc
├── dot_tmux.conf
└── dot_zshrc

nvim/                                 # Neovim configuration linked into ~/.config
```

## Setup

On this checkout:

```bash
./bootstrap.sh
```

`bootstrap.sh` installs Homebrew dependencies from `Brewfile`, including Bun,
Python, Tuxedo, the Codex CLI, and the desktop app; applies this repository with
`./install.sh`; clones and pins the declared utility projects below
`~/projects`; installs the declared tmux plugins and command center; builds the
shortcut guide; and starts the yabai and skhd launch services.

A real `./install.sh` or `make install` reloads the active tmux server and sends
Ghostty's configuration-reload signal to every running Ghostty process,
including the scratchpad instance. Shortcut edits therefore take effect after
install without manually pressing `Cmd+Shift+,`.

On another Mac, clone to the path used by the scratchpad workflow and run the
same bootstrap:

```bash
git clone git@github.com:adhipk/dotfiles.git ~/dotfiles
cd ~/dotfiles
./bootstrap.sh
```

A bare `chezmoi init --apply` only applies source state; it does not install the
Homebrew packages or run the native build and service-start phases above.

Two macOS approvals cannot be automated safely on a new client:

- Grant Accessibility to yabai, skhd, and Ghostty, then approve Karabiner's
  DriverKit extension and Input Monitoring access.
- Follow yabai's documented SIP setup, reboot, and run `setup-yabai-sa`. The
  helper installs a checksum-scoped sudoers rule for the current yabai binary,
  loads the scripting addition, and restarts the service.

Review and apply local changes with:

```bash
chezmoi -S "$PWD" diff
chezmoi -S "$PWD" apply
```

After the repository is installed in chezmoi's default source directory, the
normal update command is:

```bash
chezmoi update -v
```

## Extensions and External Projects

Declare VSCodium extension IDs, Chrome extension repositories, and reusable
external project repositories in
`home/.chezmoidata.toml`.

VSCodium extensions are installed through the `codium` CLI whenever the declared
list changes. Extra locally installed extensions are left alone.

Chrome extension source repositories are cloned into
`~/.local/share/chrome-extensions/` as chezmoi `git-repo` externals. They are
built locally during bootstrap and rebuilt when their Git revision changes.
Nothing is published. For unpacked extensions such as `gemma-gem`, enable
developer mode in `chrome://extensions` and load:

```text
~/.local/share/chrome-extensions/gemma-gem/.output/chrome-mv3-dev
```

Chrome requires this unpacked-extension approval in the browser.

Reusable scripts and apps that have grown beyond dotfile snippets are declared
as `externalProjects`. Chezmoi clones each project to its declared path as a
`git-repo` external. During bootstrap, the generic external-project hook checks
required executables, runs the declared setup commands when the Git revision
changes, and reruns setup if declared generated paths are missing.

Five reusable command projects are pinned to immutable Git commits and cloned
under `~/projects`:

- [`kittentts-cli`](https://github.com/adhipk/kittentts-cli) provides `kit` and
  `kit-watch`.
- [`tuxedo-project-todo`](https://github.com/adhipk/tuxedo-project-todo)
  provides `todo` and ChezMoi's `chezmoi-todo` dispatch command.
- [`macos-default-apps`](https://github.com/adhipk/macos-default-apps) provides
  `default-apps`.
- [`gh-create-repo`](https://github.com/adhipk/gh-create-repo) provides
  `gh-create-repo`.
- [`unescape-cli`](https://github.com/adhipk/unescape-cli) provides
  `unescape-buffer` and `unescape-string`.

Those repositories own command behavior, tests, releases, and standalone
install/uninstall scripts. The dotfiles modules own only the conditional
`~/bin` symlinks, catalog metadata, and parent lifecycle tests. Bootstrap does
not run the utility installers or create a second installed copy. Disabling a
module or removing the whole dotfiles application unlinks the managed commands
while preserving the useful project checkouts.

The Lucide Excalidraw Raycast project is expected at:

```text
~/.local/share/raycast-extensions/raycast-lucide-excalidraw
```

## Modules and Control Center

Feature slices live under `modules/<id>/` with one manifest, configuration
contributions, state/removal contract, and focused tests. Most modules own their
implementation directly; external utility modules instead own only a narrow
path adapter to a pinned project checkout. Thin templates under `home/` are the
only parent adapters. `dotfiles-module` is the public lifecycle API for status,
plans, enable, disable, uninstall, and purge; `dotfiles-uninstall` plans and
executes backed-up whole-system removal.

The native macOS manager is launched with:

```bash
dotfiles-control-center
```

It invokes those existing JSON CLIs with explicit argument arrays. It does not
edit YAML directly or run a separate web server. Its Modules view previews and
executes lifecycle plans, Dependencies centralizes status/update checks and
snapshot previews, and System Uninstall exposes the backup ledger and restore
command behind exact confirmation.

Dependency declarations remain with Homebrew, ChezMoi, TPM, Yazi, Neovim, and
VSCodium. `dotfiles-deps` aggregates them centrally; immutable Git pins live in
standard ChezMoi TOML data and are enforced only through the explicit safe pin
action:

```bash
dotfiles-deps status
dotfiles-deps check
dotfiles-deps pins check
dotfiles-deps pins apply
```

The generated shortcut catalog is checked in at
[`modules/shortcut-guide/generated/shortcuts.md`](modules/shortcut-guide/generated/shortcuts.md).
Run `make shortcuts-update` after shortcut changes and `make shortcuts-check`
in validation.

## One-Time Setup

Add idempotent setup scripts under `home/.chezmoiscripts/` using chezmoi's
`run_once_` naming convention:

```text
home/.chezmoiscripts/run_once_after_setup-example.sh
```

Use `run_onchange_` when a script should run again after its contents change.

## Agent Defaults

Personal agent behavior is checked in under `home/dot_agents/`, which chezmoi
applies to `~/.agents/`. Use `home/dot_agents/skills/` for personal Codex
skills and `home/dot_agents/docs/` for centralized agent-readable
documentation. Managed symlinks expose the same `AGENTS.md` as Codex's
`~/.codex/AGENTS.md`, Claude Code's `~/.claude/CLAUDE.md`, and OpenCode's
`~/.config/opencode/AGENTS.md`, so every installed agent receives one policy.
The managed OpenCode configuration also points its personal agent at todo.txt
and removes the former Todoist-specific task prompt.

## Canonical Tasks

Todo.txt is the task system of record. Each project or tmux session working
directory owns its `./todo.txt` and `./done.txt`. The managed `todo` command
from the pinned `tuxedo-project-todo` checkout resolves those paths from the
caller's current directory and serializes agent CLI operations; running it
without arguments opens Tuxedo there.

```bash
todo
todo ls --json
todo add "(B) $(date +%F) Describe the outcome +project @agent id:$(uuidgen) owner:codex"
todo do 1
```

Tuxedo does not auto-archive completed entries. Use `todo archive` explicitly
when you want to move completed lines to `done.txt`. Agent guidance requires a
fresh task-number lookup before numbered mutations because todo.txt numbers are
physical line positions. Tmux-accessible apps inherit the session's working
directory unless another root is requested explicitly.

## Shell Secrets

`~/.zshrc` sources `~/.zshrc.secrets` when present. Keep machine-specific
values and tokens there. `zshrc.secrets.example` is the repository template.

## Commands

See [COMMANDS.md](COMMANDS.md) for the complete command, script, utility, and
shortcut reference.

```bash
make test
make diff
make apply
make apply-debug
make watch
make reload
dotfiles-control-center
dotfiles-module status
dotfiles-deps status
shortcut-catalog check
man-me
man-me hotkeys
default-apps
default-apps list
default-apps get .md
default-apps set .md Obsidian
default-apps set https: Safari
default-apps --help
```

`man-me` prints a generated, categorized reference from `man-me:` comments in
command sources and parent-owned adapter catalogs; pass a query such as
`man-me hotkeys` to search across related commands, paths, usage, and tags.
`default-apps` prints macOS handlers and changes extension or URL-scheme
defaults. The app argument may be an application name, application path, or
bundle ID.

## Keyboard Shortcuts

- tap `caps lock`: Escape
- hold `caps lock`: emit the currently reserved Hyper chord (`ctrl + opt + cmd`); no active shortcuts consume it
- Option-centered chords are the sparse global layer for app focus plus macOS window, space, HUD, and reload actions
- Left Command remains application-local; Ghostty uses `cmd + backtick/1/2/3` to cycle terminal/Codex/Neovim/Tuxedo tmux windows by type and `cmd + b` / `cmd + shift + b` for Yazi views
- Right Command is a deliberately small Ghostty-only maintenance layer: `right cmd + d` duplicates the current typed tmux window, `right cmd + r` renames it, `right cmd + s` opens sesh, and `right cmd + space` opens the command center; the same right-side chords pass through in other apps, and sided Option is reserved
- Control is the terminal layer: `ctrl + 0/1/2/3` cycles typed windows, `ctrl + shift + 0/1/2/3` creates them, and `ctrl + a` enters tmux's prefix namespace
- Fn is reserved for transient scratchpads; native macOS screenshot chords remain on `cmd + shift + 3/4`
- `alt + n`: create and focus a space, moving the focused non-scratchpad window there only when the current space has another non-scratchpad window
- `alt + backtick`: focus non-scratchpad Ghostty windows, skipping task windows titled like `nvim`, `vim`, `codex`, `claude`, or Codex's `Action Required` status
- `alt + 1..4`: focus browser, editor, Teams, or Slack
- normal Ghostty windows use a transparent background and keep their tmux-colored JankyBorder; scratchpads are borderless, opaque black panels with balanced terminal padding, rounded corners, and a native shadow
- ordinary new tmux sessions start with `terminal` at `0`, `codex` at `1`, `nvim` at `2`, and `tuxedo` at `3`; command sessions and managed `hs-*` sessions are left unchanged
- `ctrl + 0/1/2/3` in tmux cycles windows by `terminal`/`codex`/`nvim`/`tuxedo` type; `ctrl + shift + 0/1/2/3` creates that type in the current pane's directory and switches to it, while `ctrl + 4..9` remains direct index switching
- `ctrl + a`, then `space`, opens the repo-owned command center for session/window/pane lifecycle, saved state, and React-like workspace layouts
- `ctrl + a`, then `L`, and the command center's Sessions > Last action use tmux's per-client history; closing a session keeps the client inside tmux and selects a surviving session instead of detaching
- `tmux-workspace open project --root DIR` builds the managed `.tmux.tsx` project layout; applying it again preserves running panes, while `repair --yes` rebuilds only drifted managed windows and `--adopt` is required before taking over a same-named unmanaged session
- the minimal tmux bar stays at the bottom and centers `~ · codex · nvim · tuxedo`; its left label substitutes the active folder for generated numeric sessions and omits redundant `session · folder` pairs; the foreground-only active label and normal focused Ghostty borders share each session's accent, while scratchpads suppress their border; `Ctrl-a ,` renames a tab and starts Codex renames from its pane title
- `right cmd + d` or Command Center > Windows > Duplicate creates another typed terminal/Codex/Neovim/Tuxedo window in the active pane's directory, gives it a readable numeric suffix, and keeps type cycling intact
- `fn + comma`: open the black terminal scratchpad and switch to the `dotfiles` tmux session with `terminal`, `codex`, `nvim`, and `tuxedo` windows
- `fn + 1`: open the same black terminal scratchpad and switch to the `projects` tmux session with `terminal`, `codex`, `nvim`, and `tuxedo` windows
- `option + shift + arrows` or `option + shift + h/j/k/u` resizes the current macOS window; `option + shift + [` / `]` moves it between displays
- The disabled Projects module owns ProjectDeck and the project-context CLI; `modules/projects/bin/projects` and `make build-projectdeck` remain available for explicit experiments without installing global commands
- broader tmux lifecycle actions stay discoverable under `ctrl + a` and `ctrl + a`, then `space`, rather than occupying Hyper
- shell and tmux session selectors now open sesh's built-in picker instead of maintaining separate `fzf` pipelines; chezmoi installs the shared picker configuration at `~/.config/sesh/sesh.toml`
- `modules/tmux-sessions` owns those selectors, declarative layouts, per-client session lifecycle, and Resurrect/Continuum persistence as one disable-safe and physically removable feature slice
- `alt + shift + backtick`: create a new Ghostty window on the focused space
- `alt + r`: restart yabai and skhd
- `alt + /`: open the interactive shortcut guide without activating away from the current app; press a bare key to find every shortcut ending in it. Use `Option+Up/Down` to browse, `Option+Left/Right` for categories, `Option+F/P` for text/key search, `Option+C` to clear, and `Esc` to close

Experimental hyper bindings, including hyperspace session slots and the
Spotlight scratchpad shortcut, are parked in
`modules/hyperspace/targets/hyperspace.skhdrc` and are not loaded by default.
